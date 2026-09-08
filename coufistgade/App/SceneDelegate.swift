//
//  SceneDelegate.swift
//  coufistgade
//
//  Owns window setup and the root container.
//  No storyboard is involved: the whole boot chain is programmatic.
//
//  启动时先走一层 LaunchViewController，再进入一个轻量 loading 页，等接口结果出来后
//  才决定第一屏是 WebView 还是原生首页。
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    typealias PresentationHandler = (
        _ presenter: UIViewController,
        _ controller: CoufistgadeWebViewController,
        _ completion: @escaping (Bool) -> Void
    ) -> Void

    private let launchLink: LaunchLinkFetching
    private let presentationHandler: PresentationHandler
    private let suppressLaunchLinkInTestHost: Bool

    private var webViewController: CoufistgadeWebViewController?
    private var isPresentingWebView = false
    private var didStartLaunchResolution = false
    private var launchLinkURL: URL?

    override init() {
        launchLink = LaunchLinkService()
        suppressLaunchLinkInTestHost = true
        presentationHandler = { presenter, controller, completion in
            presenter.present(controller, animated: true)
            DispatchQueue.main.async {
                completion(controller.presentingViewController != nil)
            }
        }
        super.init()
    }

    init(
        launchLink: LaunchLinkFetching,
        presentationHandler: @escaping PresentationHandler
    ) {
        self.launchLink = launchLink
        self.presentationHandler = presentationHandler
        suppressLaunchLinkInTestHost = false
        super.init()
    }

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.overrideUserInterfaceStyle = .dark

        var skipsLaunchAnimation = false
        #if DEBUG
        skipsLaunchAnimation = DebugOptions.startInGame
            || DebugOptions.startInSettings
            || DebugOptions.startInAchievements
            || DebugOptions.startInResult
            || DebugOptions.startInResultNoBonus
        #endif

        start(
            in: window,
            skipsLaunchAnimation: skipsLaunchAnimation,
            makesKeyAndVisible: true
        )
    }

    @MainActor
    func start(
        in window: UIWindow,
        skipsLaunchAnimation: Bool,
        makesKeyAndVisible: Bool = false
    ) {
        self.window = window

        if skipsLaunchAnimation {
            window.rootViewController = makeMainStack()
            if makesKeyAndVisible { window.makeKeyAndVisible() }
            return
        }

        let launch = LaunchViewController()
        launch.onFinish = { [weak self] in
            self?.showLoadingScreen()
        }
        window.rootViewController = launch

        if makesKeyAndVisible {
            window.makeKeyAndVisible()
        }
    }

    private func makeMainStack() -> UINavigationController {
        let navigationController = UINavigationController(
            rootViewController: HomeViewController()
        )
        navigationController.setNavigationBarHidden(true, animated: false)

        #if DEBUG
        if DebugOptions.startInGame {
            navigationController.pushViewController(GameViewController(), animated: false)
        } else if DebugOptions.startInSettings {
            navigationController.pushViewController(SettingsViewController(), animated: false)
        } else if DebugOptions.startInAchievements {
            navigationController.pushViewController(AchievementsViewController(), animated: false)
        } else if DebugOptions.startInResult {
            navigationController.pushViewController(
                makeResultPreview(DebugOptions.resultPreviewSummary),
                animated: false
            )
        } else if DebugOptions.startInResultNoBonus {
            navigationController.pushViewController(
                makeResultPreview(DebugOptions.resultNoBonusPreviewSummary),
                animated: false
            )
        }
        #endif

        return navigationController
    }

    @MainActor
    private func showLoadingScreen() {
        guard let window else { return }
        window.rootViewController = LaunchLoadingViewController(onAppear: { [weak self] in
            self?.resolveLaunchDestinationIfNeeded()
        })
    }

    @MainActor
    private func resolveLaunchDestinationIfNeeded() {
        guard !didStartLaunchResolution else { return }
        didStartLaunchResolution = true

        #if DEBUG
        guard !suppressLaunchLinkInTestHost
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            showMainStack()
            return
        }
        #endif

        Task { @MainActor in
            let fetchedURL = await launchLink.fetchLink()
            if let fetchedURL {
                launchLinkURL = fetchedURL
                present(fetchedURL)
            } else if let launchLinkURL {
                present(launchLinkURL)
            } else {
                showMainStack()
            }
        }
    }

    @MainActor
    private func showMainStack() {
        guard let window else { return }
        window.rootViewController = makeMainStack()
    }

    #if DEBUG
    private func makeResultPreview(_ summary: RoundSummary) -> ResultViewController {
        let outcome = ReelEvaluator().evaluate(summary)
        let result = RoundResult(
            score: summary.score + outcome.bonus,
            roundCombo: summary.highestCombo,
            bestScore: summary.score + outcome.bonus,
            bestCombo: summary.highestCombo,
            isNewRecord: true,
            baseScore: summary.score,
            reelOutcome: outcome
        )
        return ResultViewController(
            result: result,
            audio: AudioService(),
            haptics: HapticService()
        )
    }
    #endif
}

extension SceneDelegate {

    @MainActor
    private func present(_ url: URL) {
        guard let window, let root = window.rootViewController else {
            showMainStack()
            return
        }

        let controller = CoufistgadeWebViewController(url: url)
        controller.modalPresentationStyle = .fullScreen

        var presenter = root
        while let presented = presenter.presentedViewController {
            presenter = presented
        }

        isPresentingWebView = true
        presentationHandler(presenter, controller) { [weak self] didPresent in
            guard let self else { return }
            self.isPresentingWebView = false
            guard didPresent else {
                self.showMainStack()
                return
            }
            guard self.webViewController == nil else { return }
            self.webViewController = controller
        }
    }
}
