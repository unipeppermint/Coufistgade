//
//  DebugOptions.swift
//  coufistgade
//
//  Launch-argument switches used to inspect the game without driving the UI by
//  hand. Every one is DEBUG-only and compiles to `false` in release.
//
//  Pass them after the bundle id, e.g.
//      xcrun simctl launch booted com.cclv.coufistgade -startInGame -showPhysics
//

import Foundation

enum DebugOptions {

    /// Speed given to the player ball on spawn, in points per second.
    ///
    /// Scaffolding for Phase 4 only: without input (Phase 5) a ball just sits
    /// still, and "collides with boundaries" cannot be verified. Removed once
    /// drag-and-release exists.
    static let launchBallSpeed: CGFloat = 600

    private static func isSet(_ flag: String) -> Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains(flag)
        #else
        false
        #endif
    }

    /// Boot straight into the game screen, skipping Home.
    static var startInGame: Bool { isSet("-startInGame") }

    /// Draw physics bodies so hitboxes can be checked against intent.
    static var showPhysics: Bool { isSet("-showPhysics") }

    /// Give the player ball a starting velocity so bouncing is observable.
    static var launchBall: Bool { isSet("-launchBall") }

    /// Overlay the ball's current speed, and log a sample each second, to
    /// measure how fast damping bleeds off energy (the GAMEPLAY §8 open issue).
    static var trackBallSpeed: Bool { isSet("-trackBallSpeed") }

    /// Log every accepted collision with its graded intensity, to check the
    /// GAMEPLAY §11 thresholds against real impact speeds.
    static var logCollisions: Bool { isSet("-logCollisions") }

    /// Seconds after the round starts to pause it automatically.
    ///
    /// Touch cannot be automated in the simulator, so the pause panel is
    /// otherwise unreachable from a script.
    static let autoPauseDelay: TimeInterval = 3

    static var autoPause: Bool { isSet("-autoPause") }

    /// Shorten the round, so the end-of-round path can be checked without
    /// waiting a full 60 seconds.
    static let shortRoundDuration: TimeInterval = 8

    static var shortRound: Bool { isSet("-shortRound") }

    /// Fill the field to the maximum ball count, for performance checks.
    static var maxBalls: Bool { isSet("-maxBalls") }

    /// Boot straight into Settings. Touch cannot be automated, so this is the
    /// only way to reach the screen from a script.
    static var startInSettings: Bool { isSet("-startInSettings") }

    /// 直接进成就页。首页入口目前挂在最高分区块上，脚本点不到。
    static var startInAchievements: Bool { isSet("-startInAchievements") }
}
