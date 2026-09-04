//
//  Strings.swift
//  coufistgade
//
//  Every user-facing string, resolved through Localizable.xcstrings.
//
//  A typed accessor rather than `NSLocalizedString` at each call site: the keys
//  live in one place, the interpolated ones carry their arguments in the
//  signature so a caller cannot pass the wrong count, and a test can walk this
//  list against the catalog to prove nothing has drifted.
//
//  The key *is* the English source text, which is the String Catalog convention:
//  a language with no entry falls back to something readable rather than to a
//  dotted identifier.
//
//  Not localised on purpose: "BOUNCE RALLY" is the product's name (UI_DESIGN §4),
//  and a wordmark is not translated.
//

import Foundation

enum Strings {

    // MARK: - Home

    static var bestCaption: String { localized("BEST") }
    static var play: String { localized("PLAY") }
    static var startGameLabel: String { localized("Start Game") }
    static var openSettingsLabel: String { localized("Open Settings") }

    static func bestScoreLabel(_ score: Int) -> String {
        localized("Best score %lld", score)
    }

    // MARK: - Game HUD

    static var scoreCaption: String { localized("SCORE") }
    static var pauseGameLabel: String { localized("Pause Game") }
    static var playfieldLabel: String { localized("Playfield") }
    static var playfieldHint: String {
        localized("Drag the ball and release to throw it at the other balls.")
    }

    static func scoreLabel(_ score: Int) -> String {
        localized("Score %lld", score)
    }

    static func comboCaption(_ count: Int) -> String {
        localized("COMBO %lld", count)
    }

    static func comboLabel(count: Int, multiplier: Int) -> String {
        localized("Combo %1$lld, %2$lld times multiplier", count, multiplier)
    }

    static func secondsRemainingLabel(_ seconds: Int) -> String {
        localized("%lld seconds remaining", seconds)
    }

    // MARK: - Announcements

    static func comboAnnouncement(count: Int, multiplier: Int) -> String {
        localized("Combo %1$lld, %2$lld times", count, multiplier)
    }

    static func roundEndAnnouncement(score: Int) -> String {
        localized("Time's up. Score %lld.", score)
    }

    // MARK: - Pause

    static var paused: String { localized("Paused") }
    static var resume: String { localized("Resume") }
    static var quit: String { localized("Quit") }

    // MARK: - Result

    static var newRecord: String { localized("NEW RECORD") }
    static var comboCaptionPlain: String { localized("COMBO") }
    static var bestComboCaption: String { localized("BEST COMBO") }
    static var playAgain: String { localized("Play Again") }
    static var home: String { localized("Home") }

    // MARK: - Settings

    static var settings: String { localized("Settings") }
    static var closeSettingsLabel: String { localized("Close Settings") }
    static var sound: String { localized("Sound") }
    static var haptics: String { localized("Haptics") }
    static var reduceMotion: String { localized("Reduce Motion") }
    static var hapticsFooter: String {
        localized("Vibration on impact. Unavailable on some devices.")
    }
    static var reduceMotionFooter: String {
        localized("Also follows the system setting in Accessibility.")
    }

    // MARK: - Reset progress

    static var resetProgress: String { localized("Reset Progress") }
    static var resetProgressFooter: String {
        localized("Clears your best score, combo, rounds played, and achievements. Your settings are kept.")
    }
    /// 刻意不叫 "Reset progress?" —— 那个 key 会和行标题 "Reset Progress" 生成
    /// 同一个 Swift 符号（大小写与标点会被规范化掉），String Catalog 会直接报错。
    static var resetProgressConfirmTitle: String { localized("Reset your progress?") }
    static var resetProgressConfirmMessage: String {
        localized("This cannot be undone.")
    }
    /// 确认弹窗上那个破坏性按钮。和行标题分开：行是入口，这个是「就是现在，动手」。
    static var resetProgressConfirmAction: String { localized("Reset") }
    static var cancel: String { localized("Cancel") }
    /// 重置完成后播报给 VoiceOver——弹窗关掉后屏幕上没有可见变化能说明它生效了。
    static var resetProgressDoneAnnouncement: String { localized("Progress reset.") }

    // MARK: - Launch

    /// 启动页整屏读这一句。字标本身不进目录（见文件头），所以这里不是它的译名，
    /// 而是「现在屏幕上是什么」的一句描述。
    static var launchLabel: String { localized("Bounce Rally is starting") }

    // MARK: - Web page

    /// 关闭按钮只有一个图标，标签是 VoiceOver 唯一能读到的东西。
    static var closeWebPageLabel: String { localized("Close Web Page") }
    static var webPageUnavailable: String { localized("The page could not be loaded.") }
    static var retry: String { localized("Retry") }
    /// 页面里 alert() 的确认按钮。
    static var ok: String { localized("OK") }

    // MARK: - Lookup

    private static func localized(_ key: String) -> String {
        // `bundle:` explicitly, so the catalog is found when the code is exercised
        // from the test bundle rather than the app.
        NSLocalizedString(key, bundle: .main, comment: "")
    }

    private static func localized(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: localized(key), locale: .current, arguments: arguments)
    }

    #if DEBUG
    /// Every key this type resolves. Used by a test to prove each one exists in
    /// the catalog — a typo would otherwise ship as the key rendered verbatim.
    static let allKeys: [String] = [
        "BEST", "PLAY", "Start Game", "Open Settings", "Best score %lld",
        "SCORE", "Score %lld", "COMBO %lld", "Combo %1$lld, %2$lld times multiplier",
        "%lld seconds remaining", "Pause Game", "Playfield",
        "Drag the ball and release to throw it at the other balls.",
        "Combo %1$lld, %2$lld times", "Paused", "Time's up. Score %lld.",
        "Resume", "Quit",
        "NEW RECORD", "COMBO", "BEST COMBO", "Play Again", "Home",
        "Settings", "Close Settings", "Sound", "Haptics", "Reduce Motion",
        "Vibration on impact. Unavailable on some devices.",
        "Also follows the system setting in Accessibility.",
        "Reset Progress",
        "Clears your best score, combo, rounds played, and achievements. Your settings are kept.",
        "Reset your progress?", "This cannot be undone.", "Reset", "Cancel",
        "Progress reset.",
        "Close Web Page", "The page could not be loaded.", "Retry", "OK",
        "Bounce Rally is starting",
    ]
    #endif
}
