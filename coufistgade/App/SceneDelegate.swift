//
//  SceneDelegate.swift
//  coufistgade
//
//  Owns window setup and the root navigation container.
//  No storyboard is involved: the whole boot chain is programmatic.
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

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

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = navigationController
        // Dark is the primary visual mode for this app, not a user preference.
        window.overrideUserInterfaceStyle = .dark
        window.makeKeyAndVisible()

        self.window = window
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
