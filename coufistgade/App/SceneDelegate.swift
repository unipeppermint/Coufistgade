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
        }
        #endif

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = navigationController
        // Dark is the primary visual mode for this app, not a user preference.
        window.overrideUserInterfaceStyle = .dark
        window.makeKeyAndVisible()

        self.window = window
    }
}
