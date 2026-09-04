//
//  WebViewController.swift
//  coufistgade
//
//  展示 LaunchLinkService 取回的那个网页。见 LaunchLinkService 顶部的说明。
//
//  刻意做得很薄：一个 WKWebView、一个进度条、一个关闭按钮，加上失败时的重试。
//  没有 JS 注入，没有 message handler，没有 native bridge——远程页面拿不到任何
//  进入 app 的通道。要加通道的话那是另一个决定，得单独评估。
//
//  用 WKWebView 而不是 SFSafariViewController，是因为需要自己的关闭按钮和失败
//  态；SFSafariViewController 更安全省事（进程隔离、自带 Reader 与分享），如果
//  将来这个页面只是纯展示、不需要自定义 chrome，换回去是更好的选择。
//

import UIKit
import WebKit

final class WebViewController: UIViewController {

    enum AccessibilityID {
        static let webView = "web.content"
        static let close = "web.close"
        static let retry = "web.retry"
    }

    private let url: URL
    private let webView: WKWebView
    private let progressBar = UIProgressView(progressViewStyle: .bar)
    private let closeButton = UIButton(type: .system)

    /// 加载失败时的那一层。平时藏着。
    private let errorView = UIStackView()
    private let errorLabel = UILabel()
    private let retryButton = UIButton(type: .system)

    private var progressObservation: NSKeyValueObservation?

    /// 关闭时回调。SceneDelegate 用它把这个控制器收走。
    var onClose: (() -> Void)?

    init(url: URL) {
        self.url = url

        let configuration = WKWebViewConfiguration()
        // 不留痕：这是个一次性的展示页，不该往 app 的 cookie 罐里写东西。
        configuration.websiteDataStore = .nonPersistent()
        // 视频不自动全屏，也不允许自动播放带声音的内容打断游戏音频。
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        self.webView = WKWebView(frame: .zero, configuration: configuration)

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("WebViewController is code-only; this app uses no storyboards or nibs.")
    }

    deinit {
        progressObservation?.invalidate()
    }
}

// MARK: - 生命周期

extension WebViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(resource: .appBackground)
        setupUI()
        setupConstraints()
        observeProgress()
        load()
    }

    private func setupUI() {
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.accessibilityIdentifier = AccessibilityID.webView
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        progressBar.progressTintColor = UIColor(resource: .accent)
        progressBar.trackTintColor = .clear
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressBar)

        var closeConfiguration = UIButton.Configuration.plain()
        closeConfiguration.image = UIImage(systemName: "xmark")
        closeConfiguration.baseForegroundColor = UIColor(resource: .textPrimary)
        closeButton.configuration = closeConfiguration
        closeButton.accessibilityLabel = Strings.closeWebPageLabel
        closeButton.accessibilityIdentifier = AccessibilityID.close
        closeButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)

        setupErrorView()
    }

    private func setupErrorView() {
        errorLabel.text = Strings.webPageUnavailable
        errorLabel.font = Theme.Typography.rounded(
            .body,
            weight: .semibold,
            maximumPointSize: Theme.Typography.MaxPointSize.caption
        )
        errorLabel.textColor = UIColor(resource: .textSecondary)
        errorLabel.adjustsFontForContentSizeCategory = true
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0

        var retryConfiguration = UIButton.Configuration.borderedTinted()
        retryConfiguration.title = Strings.retry
        retryConfiguration.baseForegroundColor = UIColor(resource: .accent)
        retryButton.configuration = retryConfiguration
        retryButton.accessibilityIdentifier = AccessibilityID.retry
        retryButton.addTarget(self, action: #selector(handleRetry), for: .touchUpInside)

        errorView.axis = .vertical
        errorView.alignment = .center
        errorView.spacing = Theme.Spacing.s
        errorView.addArrangedSubview(errorLabel)
        errorView.addArrangedSubview(retryButton)
        errorView.isHidden = true
        errorView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(errorView)
    }

    private func setupConstraints() {
        let guide = view.safeAreaLayoutGuide

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: guide.topAnchor, constant: Theme.Spacing.xs),
            closeButton.leadingAnchor.constraint(
                equalTo: guide.leadingAnchor,
                constant: Theme.Spacing.xs
            ),
            closeButton.widthAnchor.constraint(equalToConstant: Theme.Layout.minimumTouchTarget),
            closeButton.heightAnchor.constraint(equalToConstant: Theme.Layout.minimumTouchTarget),

            progressBar.topAnchor.constraint(equalTo: closeButton.bottomAnchor),
            progressBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            webView.topAnchor.constraint(equalTo: progressBar.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            errorView.centerXAnchor.constraint(equalTo: webView.centerXAnchor),
            errorView.centerYAnchor.constraint(equalTo: webView.centerYAnchor),
            errorView.leadingAnchor.constraint(
                greaterThanOrEqualTo: guide.leadingAnchor,
                constant: Theme.Spacing.m
            ),
            guide.trailingAnchor.constraint(
                greaterThanOrEqualTo: errorView.trailingAnchor,
                constant: Theme.Spacing.m
            ),
        ])
    }
}

// MARK: - 加载

extension WebViewController {

    private func load() {
        errorView.isHidden = true
        webView.isHidden = false
        webView.load(URLRequest(url: url))
    }

    /// 进度条跟着 estimatedProgress 走。
    ///
    /// 用 KVO 而不是在 delegate 里手动推进：白屏等待是这个页面最难受的一段，
    /// 而只有 WKWebView 自己知道进度。
    ///
    /// 回调里显式 hop 到主线程，不用 `MainActor.assumeIsolated`：KVO 在**改动
    /// 属性的那个线程**上回调，WebKit 目前是在主线程改，但这不是它承诺过的事。
    /// assumeIsolated 猜错时是崩溃，而这里猜错的代价只值一次 async。
    private func observeProgress() {
        progressObservation = webView.observe(
            \.estimatedProgress,
            options: [.new]
        ) { [weak self] webView, _ in
            let progress = Float(webView.estimatedProgress)
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.progressBar.setProgress(progress, animated: true)
                // 满了就淡出，否则一条满格的进度条会一直留在顶部。
                let finished = progress >= 1
                UIView.animate(withDuration: Theme.Duration.buttonFeedback) {
                    self.progressBar.alpha = finished ? 0 : 1
                }
            }
        }
    }

    @objc private func handleClose() {
        // 先停掉加载：关闭之后还在跑的请求没有任何意义。
        webView.stopLoading()
        onClose?()
    }

    @objc private func handleRetry() {
        progressBar.alpha = 1
        load()
    }

    private func showError() {
        progressBar.alpha = 0
        // 藏起 webView：失败时它是一片白，盖在深色 UI 上很突兀。
        webView.isHidden = true
        errorView.isHidden = false
    }
}

// MARK: - WKNavigationDelegate

extension WebViewController: WKNavigationDelegate {

    /// 逐条放行导航。
    ///
    /// 页面内部的跳转不受 LaunchLinkService 的校验保护——那里只看了最初那个地址。
    /// 所以同一条白名单要在这里再执行一次：一个 https 页面里的 `javascript:` 或
    /// `file:` 链接，点下去仍然会走到这个方法。
    ///
    /// 非 http(s) 的外部协议（tel:、mailto:、微信/支付宝的 scheme）交给系统开，
    /// 而不是在 WKWebView 里加载——WKWebView 打不开它们，直接 cancel 会让用户以为
    /// 按钮坏了。
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url else { return .cancel }
        let scheme = url.scheme?.lowercased()

        if let scheme, LaunchLinkService.Configuration.allowedSchemes.contains(scheme) {
            return .allow
        }

        // http：ATS 会拦，但让系统去处理比在这里静默失败清楚。
        if scheme == "http" {
            await openExternally(url)
            return .cancel
        }

        // 其余 scheme：能开就交给系统，开不了就算了。绝不放进 WKWebView。
        if let scheme, scheme != "about" {
            await openExternally(url)
        }
        return .cancel
    }

    /// target="_blank" 的链接。
    ///
    /// 这类导航 WKWebView 默认什么都不做（因为没有新窗口可开），表现是点了没反应。
    /// 在当前 webView 里加载它，走的仍然是上面那条 decidePolicy 的白名单。
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        errorView.isHidden = true
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        handleFailure(error)
    }

    /// 连不上服务器走这条，而不是上面那条。漏掉它的症状是断网时停在白屏。
    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        handleFailure(error)
    }

    private func handleFailure(_ error: Error) {
        // 取消不是失败：stopLoading() 和快速连点都会报这个。
        if (error as NSError).code == NSURLErrorCancelled { return }
        #if DEBUG
        print("[LaunchLink] 页面加载失败：\(error.localizedDescription)")
        #endif
        showError()
    }

    @MainActor
    private func openExternally(_ url: URL) async {
        guard UIApplication.shared.canOpenURL(url) else { return }
        await UIApplication.shared.open(url)
    }
}

// MARK: - WKUIDelegate

extension WebViewController: WKUIDelegate {

    /// 页面里的 alert()。
    ///
    /// 必须实现，否则 WKWebView 会直接忽略——远程页面若把 alert 当作流程的一步，
    /// 表现就是卡在那里。confirm/prompt 有意不实现：它们的返回值会影响页面逻辑，
    /// 而这个页面不该有需要用户输入才能继续的流程。
    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo
    ) async {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        await withCheckedContinuation { continuation in
            alert.addAction(UIAlertAction(title: Strings.ok, style: .default) { _ in
                continuation.resume()
            })
            present(alert, animated: true)
        }
    }
}
