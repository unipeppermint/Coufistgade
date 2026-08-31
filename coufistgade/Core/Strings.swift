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
//  Not localised on purpose: "BOUNCY" is the product's name (UI_DESIGN §4), and
//  a wordmark is not translated.
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
    static var music: String { localized("Music") }
    static var haptics: String { localized("Haptics") }
    static var reduceMotion: String { localized("Reduce Motion") }
    static var musicFooter: String { localized("No music in this build.") }
    static var hapticsFooter: String {
        localized("Vibration on impact. Unavailable on some devices.")
    }
    static var reduceMotionFooter: String {
        localized("Also follows the system setting in Accessibility.")
    }

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
        "Settings", "Close Settings", "Sound", "Music", "Haptics", "Reduce Motion",
        "No music in this build.",
        "Vibration on impact. Unavailable on some devices.",
        "Also follows the system setting in Accessibility.",
    ]
    #endif
}
