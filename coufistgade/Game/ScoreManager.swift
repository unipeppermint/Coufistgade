//
//  ScoreManager.swift
//  coufistgade
//
//  Owns the score and nothing else (ARCHITECTURE §14).
//
//  Pure logic: no SpriteKit, no UIKit, no clock. That is what lets the whole
//  scoring rule be tested directly, and it is the reason this is a separate
//  type rather than a couple of properties on GameScene.
//
//  It does not decide *when* a score happens (CollisionManager) and it does not
//  display one (GameViewController's HUD).
//

import Foundation

final class ScoreManager {

    /// Supplies the combo multiplier at the moment of scoring.
    ///
    /// A closure rather than a stored Int so the value is always read fresh at
    /// award time. Phase 9 hands in ComboManager's multiplier here; until then
    /// it is GAMEPLAY §15's first rung, 1x. Injecting it this way means Phase 9
    /// changes one line in GameScene and nothing in this file.
    private let multiplierProvider: () -> Int

    private(set) var total = 0

    /// Number of scoring collisions this round. Not shown anywhere yet — Phase
    /// 12's result screen is the first consumer.
    private(set) var scoringCollisionCount = 0

    init(multiplierProvider: @escaping () -> Int = { GameConfiguration.Score.defaultMultiplier }) {
        self.multiplierProvider = multiplierProvider
    }

    /// Scores one valid collision and returns what it was worth.
    ///
    /// GAMEPLAY §13: `score = baseScore × comboMultiplier`. Intensity is
    /// deliberately absent — see `GameConfiguration.Score`.
    @discardableResult
    func award() -> ScoreEvent {
        // A negative or zero multiplier would silently make hits worthless or
        // subtract points; clamp rather than trust a future combo bug.
        let multiplier = max(1, multiplierProvider())
        let points = GameConfiguration.Score.base * multiplier

        total += points
        scoringCollisionCount += 1

        return ScoreEvent(points: points, total: total, multiplier: multiplier)
    }

    /// Returns the score to zero for a new round (ARCHITECTURE §14).
    func reset() {
        total = 0
        scoringCollisionCount = 0
    }
}

/// What one scoring collision produced.
///
/// Carries the multiplier so the HUD can react to *how* a score was earned,
/// which is what Phase 9's combo feedback will need, without the HUD having to
/// reach into the combo system itself.
struct ScoreEvent: Equatable {
    let points: Int
    let total: Int
    let multiplier: Int
}
