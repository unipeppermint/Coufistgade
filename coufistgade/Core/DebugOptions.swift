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

    /// 直接进结算页，带一个造好的转轴结果（GAMEPLAY §27）。
    ///
    /// `-startInGame -shortRound` 其实也能到结算页，但模拟器里无法自动化触摸，
    /// 那条路只能得到一局 0/0/0——三轮全樱桃。那是需要看的情形之一（它是教学用
    /// 的那一局），但成线、两连、全不中都看不到。
    ///
    /// 这个开关用的成绩是命中 12、连击 4、得分 900：三轮全 star，成线，奖励 150，
    /// 总分爬到 1050。挑它是因为它同时能看到成线描边、奖励分弹出与爬分三件事。
    static var startInResult: Bool { isSet("-startInResult") }

    /// `-startInResult` 用的那一局。写成常量而不是散在 SceneDelegate 里，
    /// 是为了让「挑了哪一局、为什么」和上面那段说明待在一起。
    static let resultPreviewSummary = RoundSummary(score: 900, highestCombo: 4, hits: 12)

    /// 直接进结算页，但用一局**没有奖励**的成绩。
    ///
    /// 单独一个开关而不是给 `-startInResult` 加参数：其余每个开关都是布尔，
    /// 为一处预览引入参数解析不值得。
    ///
    /// 这一局要单独看，因为它是唯一显示规则说明的情形——那行字是这套机制的全部
    /// 说明书，排版与措辞只能在屏幕上判断。
    static var startInResultNoBonus: Bool { isSet("-startInResultNoBonus") }

    /// 命中 3（cherry）、连击 7（seven）、得分 500（star）。
    ///
    /// 最低档是 cherry，而 cherry 赔 0，所以这一局没有奖励（GAMEPLAY §27）。
    ///
    /// 命中刻意压到 3 而不是 5：改成按最低档赔付之后，5 次命中会落在 bell 档，
    /// 于是最低档变成 bell、赔 60——那一局不再是「没有奖励」的样子了。要让奖励为 0，
    /// 必须真有一个轮子落在 cherry 上。
    static let resultNoBonusPreviewSummary = RoundSummary(score: 500, highestCombo: 7, hits: 3)
}
