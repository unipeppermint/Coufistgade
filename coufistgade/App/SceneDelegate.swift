//
//  SceneDelegate.swift
//  coufistgade
//
//  Owns window setup and the root navigation container.
//  No storyboard is involved: the whole boot chain is programmatic.
//
//  启动时还会问一次 LaunchLinkService：服务端有没有要打开的网页。有就盖一层
//  WebViewController，没有（含任何一种失败）就照常进游戏。见该文件顶部说明。
//
//  根控制器先是 LaunchViewController（球落下、字标浮起），它放完动画后把根换成
//  导航栈。换而不是 push：启动页不该留在返回栈里，玩家没有「返回启动页」这回事。
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    /// 启动链接。持有它是为了让请求活到返回为止。
    private let launchLink: LaunchLinkFetching = LaunchLinkService()

    /// 正在展示的网页。非 nil 表示已经盖了一层，用来防止重复呈现。
    private var webViewController: WebViewController?

    /// 导航栈是否已经换上来。启动页还在时它是 false。
    private var isMainStackReady = false

    /// 启动动画还没放完就取回来的链接，存在这里等换根之后再盖。
    ///
    /// 必须等：在启动页上盖网页，换根那一刻会把它一起销毁 —— 玩家看到网页闪一下
    /// 就没了。而这个请求通常比动画快（本地网络下几十毫秒），所以这不是边缘情况，
    /// 是常态。
    private var pendingLaunchLinkURL: URL?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        // Dark is the primary visual mode for this app, not a user preference.
        window.overrideUserInterfaceStyle = .dark

        // 调试入口直接进目标页，不看启动动画 —— 那一秒对着自动化和反复手测都是纯
        // 成本。`-startInGame` 之类的存在意义就是省掉中间步骤。
        var skipsLaunchAnimation = false
        #if DEBUG
        skipsLaunchAnimation = DebugOptions.startInGame
            || DebugOptions.startInSettings
            || DebugOptions.startInAchievements
            || DebugOptions.startInResult
            || DebugOptions.startInResultNoBonus
        #endif

        if skipsLaunchAnimation {
            window.rootViewController = makeMainStack()
        } else {
            let launch = LaunchViewController()
            launch.onFinish = { [weak self] in
                self?.showMainStack()
            }
            window.rootViewController = launch
        }

        window.makeKeyAndVisible()
        self.window = window

        // 放在 window 起来之后：这次请求不该挡住第一帧，失败时用户看到的就是
        // 正常的首页。
        presentLaunchLinkIfNeeded()
    }

    /// 导航栈。启动页放完动画后换上来，调试入口则直接用它当根。
    private func makeMainStack() -> UINavigationController {
        let navigationController = UINavigationController(
            rootViewController: HomeViewController()
        )
        // The game supplies its own chrome; the system bar would only compete with it.
        navigationController.setNavigationBarHidden(true, animated: false)

        #if DEBUG
        // Verification hook: `-startInGame` boots straight to the game screen
        // so the SpriteKit scene can be inspected without driving the UI by
        // hand. Compiled out of release builds entirely.
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

    /// 把根控制器从启动页换成导航栈。
    ///
    /// 换根而不是 push：启动页不该留在返回栈里。交叉淡入而不是硬切 —— 两边的球尺寸
    /// 与位置几乎一致（启动页照抄了首页的尺寸算法），淡入之下看起来就是球和字标各自
    /// 落到首页该在的地方，而不是换了一个屏幕。
    @MainActor
    private func showMainStack() {
        guard let window, !isMainStackReady else { return }

        let stack = makeMainStack()
        isMainStackReady = true

        // Reduce Motion 下不做交叉淡入：这是「复杂转场」，§20 点名要减。
        guard !MotionPreference.isReduced else {
            window.rootViewController = stack
            flushPendingLaunchLink()
            return
        }

        UIView.transition(
            with: window,
            duration: Theme.Duration.transition,
            options: [.transitionCrossDissolve],
            animations: { window.rootViewController = stack }
        ) { _ in
            self.flushPendingLaunchLink()
        }
    }

    #if DEBUG
    /// 造一个带转轴结果的结算页，供 `-startInResult` 用。
    ///
    /// 走的是真的 ReelEvaluator，不是手摆的结果：这样看到的就是玩家会看到的东西，
    /// 若阈值表哪天调了，这个预览会跟着变，而不是继续显示一个不再成立的画面。
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
        // 真的音频与触感服务：这条路径就是用来听那几声的。
        return ResultViewController(
            result: result,
            audio: AudioService(),
            haptics: HapticService()
        )
    }
    #endif
}

// MARK: - 启动链接

extension SceneDelegate {

    /// 问一次服务端，拿到 https 地址就盖一层网页。
    ///
    /// 用 Task 而不是让 `scene(_:willConnectTo:options:)` 等它：那个方法是同步
    /// 的，在里面等网络会把启动卡住，严重时被系统当作启动超时杀掉。所以首页会先
    /// 正常出现，网页随后盖上去。
    private func presentLaunchLinkIfNeeded() {
        Task { @MainActor in
            guard let url = await launchLink.fetchLink() else { return }
            // 请求期间用户可能已经进了别的页面，甚至已经开了一局。仍然盖——这是
            // 个通知性质的页面，晚到不等于不用出现；但绝不叠第二层。
            guard webViewController == nil else { return }

            // 启动页还在的话先存着，等换根之后再盖。见 pendingLaunchLinkURL。
            guard isMainStackReady else {
                pendingLaunchLinkURL = url
                return
            }
            present(url)
        }
    }

    /// 换根之后把等着的那个链接盖上去。
    @MainActor
    private func flushPendingLaunchLink() {
        guard let url = pendingLaunchLinkURL else { return }
        pendingLaunchLinkURL = nil
        guard webViewController == nil else { return }
        present(url)
    }

    @MainActor
    private func present(_ url: URL) {
        guard let window, let root = window.rootViewController else { return }

        let controller = WebViewController(url: url)
        // fullScreen 而不是默认的 automatic：iOS 13 起默认是可以下拉关掉的卡片，
        // 而这一层的关闭方式应该只有那个按钮。
        controller.modalPresentationStyle = .fullScreen
        controller.onClose = { [weak self] in
            controller.dismiss(animated: true) {
                self?.webViewController = nil
            }
        }
        webViewController = controller

        // 已经有别的模态（暂停面板之类）时挂在最上面那个上，否则 iOS 会忽略这次
        // 呈现并在控制台留一句警告。
        var presenter = root
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        presenter.present(controller, animated: true)
    }
}
