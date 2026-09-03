//
//  AppDelegate.swift
//  coufistgade
//

import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    /// 远程推送。持有在这里，因为 APNs 的回调只到 AppDelegate。
    private let push = PushNotificationService()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // 缺 GoogleService-Info.plist 时这里安静返回 false，游戏照常启动。
        guard push.configure() else { return true }

        // 冷启动就弹权限请求。
        //
        // 这是当前实现里唯一一处「产品决定」，也是最该被重新考虑的一处：用户第一
        // 次打开还没玩过一局，就被问要不要接收通知，同意率通常很低，而这个弹窗
        // 一辈子只有一次机会 —— 被拒之后代码再调也不会再弹，只能去系统设置改。
        //
        // 更好的时机通常是玩过一两局之后，或者放到设置页做成一个开关由用户主动
        // 触发。要改的话只需把这一行搬走，requestAuthorization() 在哪调都成立。
        Task { await push.requestAuthorization() }

        return true
    }

    // MARK: - 远程推送回调

    /// APNs 发下来的 device token。
    ///
    /// 必须手动转交给 Firebase：Info.plist 里关掉了 FirebaseAppDelegateProxyEnabled，
    /// 所以没有人替我们做这一步。漏掉它不会报错，只是永远拿不到 FCM token。
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        push.setAPNSToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        push.handleRegistrationFailure(error)
    }

    // MARK: - UISceneSession Lifecycle

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
    }
}
