import UIKit
import WebKit

final class CoufistgadeWebViewController: UIViewController {
    private enum ScriptBridge {
        static let openSafari = "openSafari"
        static let open = "open"
        static let all = [openSafari, open]
    }

    private let url: URL
    private let progressView = UIProgressView(progressViewStyle: .bar)
    private let errorView = UIStackView()
    private let errorLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private var progressObservation: NSKeyValueObservation?
    private var configuredUserContentController: WKUserContentController?
    private var hasFinishedLoading = false
    var dismissalRequested = false

    var onDismissRequested: (() -> Void)?

    private lazy var userContentController: WKUserContentController = {
        let controller = WKUserContentController()
        let handler = WeakWebScriptMessageHandler(target: self)
        ScriptBridge.all.forEach { controller.add(handler, name: $0) }
        configuredUserContentController = controller
        return controller
    }()

    private lazy var webView: WKWebView = {
        let webpagePreferences = WKWebpagePreferences()
        webpagePreferences.allowsContentJavaScript = true

        let preferences = WKPreferences()
        preferences.javaScriptCanOpenWindowsAutomatically = true

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences = webpagePreferences
        configuration.preferences = preferences
        configuration.userContentController = userContentController

        return WKWebView(frame: .zero, configuration: configuration)
    }()

    init(url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.07, green: 0.06, blue: 0.16, alpha: 1)
        configureWebView()
        loadPage()
    }

    private func configureWebView() {
        webView.navigationDelegate = self
        webView.backgroundColor = view.backgroundColor
        webView.isOpaque = false
        webView.allowsBackForwardNavigationGestures = true

        progressView.progressTintColor = UIColor(red: 0.47, green: 0.31, blue: 0.98, alpha: 1)
        progressView.trackTintColor = .clear

        errorLabel.text = Strings.webPageUnavailable
        errorLabel.textColor = .white
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0

        var retryConfiguration = UIButton.Configuration.borderedTinted()
        retryConfiguration.title = Strings.retry
        retryButton.configuration = retryConfiguration
        retryButton.addTarget(self, action: #selector(retry), for: .touchUpInside)

        errorView.axis = .vertical
        errorView.alignment = .center
        errorView.spacing = 16
        errorView.addArrangedSubview(errorLabel)
        errorView.addArrangedSubview(retryButton)
        errorView.isHidden = true

        [webView, progressView, errorView].forEach {
            view.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            errorView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            view.trailingAnchor.constraint(greaterThanOrEqualTo: errorView.trailingAnchor, constant: 24)
        ])

        progressObservation = webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] webView, _ in
            DispatchQueue.main.async {
                self?.progressView.setProgress(Float(webView.estimatedProgress), animated: true)
            }
        }
    }

    private func loadPage() {
        errorView.isHidden = true
        webView.isHidden = false
        progressView.alpha = 1
        hasFinishedLoading = false
        webView.load(URLRequest(url: url))
    }

    @objc private func retry() {
        loadPage()
    }

    private func showLoadFailure(_ error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        guard !hasFinishedLoading else { return }
        progressView.alpha = 0
        webView.isHidden = true
        errorView.isHidden = true
        requestDismissal()
    }

    private func requestDismissal() {
        dismissalRequested = true
        onDismissRequested?()
    }

    deinit {
        progressObservation?.invalidate()
        guard let configuredUserContentController else { return }
        ScriptBridge.all.forEach {
            configuredUserContentController.removeScriptMessageHandler(forName: $0)
        }
    }

    private func openExternalBrowser(with body: Any) {
        guard let url = externalWebURL(from: body) else {
            #if DEBUG
            print("[CoufistgadeWebViewController] Invalid external URL: \(body)")
            #endif
            return
        }
        UIApplication.shared.open(url)
    }

    private func externalWebURL(from body: Any) -> URL? {
        if let urlString = body as? String {
            return normalizedExternalWebURL(from: urlString)
        }

        if let payload = body as? [String: Any] {
            return ["url", "href", "link", "target"]
                .compactMap { payload[$0] as? String }
                .compactMap { normalizedExternalWebURL(from: $0) }
                .first
        }
        return nil
    }

    private func normalizedExternalWebURL(from rawValue: String) -> URL? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if let url = URL(string: value), isExternalWebURL(url) {
            return url
        }
        if value.hasPrefix("//") {
            return URL(string: "https:\(value)").flatMap { isExternalWebURL($0) ? $0 : nil }
        }
        if value.contains(".") {
            return URL(string: "https://\(value)").flatMap { isExternalWebURL($0) ? $0 : nil }
        }
        return nil
    }

    private func isExternalWebURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), url.host?.isEmpty == false else { return false }
        return scheme == "http" || scheme == "https"
    }

}

extension CoufistgadeWebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        hasFinishedLoading = true
        UIView.animate(withDuration: 0.2, animations: {
            self.progressView.alpha = 0
        }) { _ in
            self.progressView.setProgress(0, animated: false)
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        progressView.alpha = 1
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        showLoadFailure(error)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        showLoadFailure(error)
    }
}

extension CoufistgadeWebViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case ScriptBridge.openSafari, ScriptBridge.open:
            openExternalBrowser(with: message.body)
        default:
            break
        }
    }
}

private final class WeakWebScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?

    init(target: WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
