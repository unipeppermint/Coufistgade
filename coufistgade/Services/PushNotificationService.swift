//
//  PushNotificationService.swift
//  coufistgade
//
//  远程推送（FCM）。这是项目里唯一碰 Firebase 的地方 —— AppDelegate 只转发系统
//  回调，其余代码完全不知道 Firebase 存在。这样将来换服务商、或按 Firebase 的
//  CocoaPods 弃用公告迁到 SPM，改动都收在这一个文件里。
//
//  两件事刻意做成显式的：
//
//  1. Info.plist 里 FirebaseAppDelegateProxyEnabled = false，所以 APNs token
//     由 AppDelegate 手动交过来（见 `setAPNSToken`）。少了那一步就永远拿不到
//     FCM token，而且不会报错 —— 只是静默地一直没有。
//  2. `configure()` 在缺 GoogleService-Info.plist 时直接返回，不崩。
//     FirebaseApp.configure() 缺文件时是 fatalError，会让整个 app 起不来；
//     推送是附加功能，不该阻断游戏。
//

import FirebaseCore
import FirebaseMessaging
import UIKit
import UserNotifications

final class PushNotificationService: NSObject {

    /// 最近一次拿到的 FCM 注册 token，还没拿到时为 nil。
    ///
    /// token 会变（重装、恢复备份、Firebase 主动轮换），所以不要存下来当常量用；
    /// 要发给自己后端的话，用 `onTokenChange` 而不是读这个属性一次。
    private(set) var fcmToken: String?

    /// token 首次到达与其后每次变化时调用，主线程。
    ///
    /// 目前没有后端要收，所以默认没人订阅；DEBUG 下 `configure()` 会把 token
    /// 打到控制台，够用来在 Firebase 控制台对着这台设备发测试推送。
    var onTokenChange: ((String) -> Void)?

    /// 启动 Firebase 与推送。没有配置文件时安静退出。
    ///
    /// 返回值表示 Firebase 是否真的起来了，方便调用处在 DEBUG 里判断。
    @discardableResult
    func configure() -> Bool {
        guard Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil else {
            #if DEBUG
            print("""
                [Push] 未找到 GoogleService-Info.plist，推送已跳过。
                去 Firebase 控制台建一个 bundle id 为 \
                \(Bundle.main.bundleIdentifier ?? "com.cclv.coufistgade") 的 iOS App，
                下载该文件放进 coufistgade/ 目录即可。
                """)
            #endif
            return false
        }

        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        return true
    }
}

// MARK: - 授权与注册

extension PushNotificationService {

    /// 向用户请求通知权限，获准后再向 APNs 注册。
    ///
    /// 这个弹窗一个 app 只能出一次 —— 用户点了拒绝，之后只能去系统设置里改，
    /// 代码再调也不会重新弹。所以调用时机是个产品决定，不是技术细节，
    /// 见 AppDelegate 里那段说明。
    ///
    /// 注册必须在主线程：UIApplication 的 API 不是线程安全的。
    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            #if DEBUG
            print("[Push] 通知权限：\(granted ? "已获准" : "被拒绝")")
            #endif
            // 被拒绝就不要注册 APNs：拿到 token 也没有任何东西能显示出来。
            guard granted else { return }
        } catch {
            #if DEBUG
            print("[Push] 请求通知权限失败：\(error.localizedDescription)")
            #endif
            return
        }

        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    /// 把系统给的 APNs device token 交给 Firebase。
    ///
    /// 因为关掉了 AppDelegate proxy，这一步没有人代做。漏掉它的症状是
    /// `messaging(_:didReceiveRegistrationToken:)` 永远不触发。
    func setAPNSToken(_ deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    /// APNs 注册失败。真机没网、模拟器不支持、或描述文件没开 Push 都会走到这里。
    func handleRegistrationFailure(_ error: Error) {
        #if DEBUG
        print("[Push] APNs 注册失败：\(error.localizedDescription)")
        #endif
    }
}

// MARK: - MessagingDelegate

extension PushNotificationService: MessagingDelegate {

    /// FCM token 首次到达或发生变化。发推送给这台设备时用的就是它。
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        self.fcmToken = fcmToken
        #if DEBUG
        print("[Push] FCM token：\(fcmToken)")
        #endif
        onTokenChange?(fcmToken)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationService: UNUserNotificationCenterDelegate {

    /// app 正在前台时收到推送。
    ///
    /// 默认 iOS 会把前台推送直接吞掉，什么都不显示。这里返回 `.banner` 让它照常
    /// 出横幅 —— 否则测试时会以为推送没送到。
    ///
    /// 注意这会在对局中盖住画面顶部。真要发游戏中不该打断的推送时，可以在这里
    /// 判断当前是否在对局里再决定返不返 `.banner`。
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    /// 用户点了通知。
    ///
    /// 目前只是让系统收工 —— 点开就是进 app，没有要跳的页面。将来要做定向跳转
    /// （比如点推送直接开一局），入口在这里：读 `response.notification.request
    /// .content.userInfo` 里自定义的字段，再让导航栈去响应。
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        #if DEBUG
        print("[Push] 用户点开通知：\(response.notification.request.content.userInfo)")
        #endif
    }
}
