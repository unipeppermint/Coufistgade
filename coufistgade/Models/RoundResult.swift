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

    init(
        score: Int,
        roundCombo: Int,
        bestScore: Int,
        bestCombo: Int,
        isNewRecord: Bool,
        unlockedAchievements: [Achievement] = []
    ) {
        self.score = score
        self.roundCombo = roundCombo
        self.bestScore = bestScore
        self.bestCombo = bestCombo
        self.isNewRecord = isNewRecord
        self.unlockedAchievements = unlockedAchievements
    }
}
