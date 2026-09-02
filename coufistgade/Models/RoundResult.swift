//
//  RoundResult.swift
//  coufistgade
//
//  What a finished round produced (GAMEPLAY §22).
//
//  A value passed to the result screen rather than the screen reaching back into
//  the scene: the scene is gone by the time the result is read, and this keeps
//  ResultViewController testable without a physics world.
//

import Foundation

struct RoundResult: Equatable {
    /// 本局总分，**已含转轴奖励**（GAMEPLAY §27）。
    ///
    /// 这是记录、成就判定与结算页显示共用的那个数。转轴的奖励分不是装饰，它计入
    /// 总分，所以也计入最高分与成就——玩家确实挣到了它。
    let score: Int
    /// This round's best combo, not the all-time one. The doc review flagged
    /// "Highest Combo" as ambiguous between the two; the screen shows both, so
    /// each needs its own name.
    let roundCombo: Int
    let bestScore: Int
    let bestCombo: Int
    /// Decided by PersistenceManager at save time rather than re-derived here,
    /// so the screen cannot disagree with what was stored.
    let isNewRecord: Bool
    /// 本局新解锁的成就，按 Achievement.all 的顺序。
    ///
    /// 只放新解锁的：结算页要回答"你刚达成了什么"，不是"你一共有多少"。空数组
    /// 是常态，所以这一段 UI 必须能整块隐藏而不留空隙。
    let unlockedAchievements: [Achievement]

    /// 加转轴奖励**之前**的分数，即对局本身打出来的分。
    ///
    /// 单独留一份而不是让结算页去做 `score - bonus`：那个减法会在两处各写一遍，
    /// 而这里存下来只是把已经算过的数留住。结算页用它做滚动计分的起点。
    let baseScore: Int

    /// 本局的转轴结果（GAMEPLAY §27）。
    ///
    /// 可空：转轴是 Phase 22 才有的东西，而 RoundResult 在大量既有测试里被直接
    /// 构造。默认 nil 让那些调用点一行都不用改，结算页则整段不显示面板。
    let reelOutcome: ReelOutcome?

    init(
        score: Int,
        roundCombo: Int,
        bestScore: Int,
        bestCombo: Int,
        isNewRecord: Bool,
        unlockedAchievements: [Achievement] = [],
        baseScore: Int? = nil,
        reelOutcome: ReelOutcome? = nil
    ) {
        self.score = score
        self.roundCombo = roundCombo
        self.bestScore = bestScore
        self.bestCombo = bestCombo
        self.isNewRecord = isNewRecord
        self.unlockedAchievements = unlockedAchievements
        // 没有转轴时基础分就是总分——省得每个既有调用点都传一遍同一个数。
        self.baseScore = baseScore ?? score
        self.reelOutcome = reelOutcome
    }
}
