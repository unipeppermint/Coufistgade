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
}
