//
//  RoundState.swift
//  coufistgade
//
//  Everything a round accumulates: score, combo, and the round's best combo.
//
//  Exists because score and combo are not independent — GAMEPLAY §13's award is
//  `base × comboMultiplier`, so the two managers have to be wired to each other
//  and advanced in a fixed order. Holding them separately in GameScene meant the
//  scene owned that ordering rule, which is round logic rather than scene
//  assembly.
//
//  Pure logic with time as a parameter, like the managers it composes. No
//  SpriteKit, no clock of its own.
//

import Foundation

final class RoundState {

    private let combo = ComboManager()
    private lazy var score = ScoreManager(
        multiplierProvider: { [unowned self] in combo.multiplier }
    )

    var total: Int { score.total }
    var comboCount: Int { combo.count }
    /// Best combo this round. Phase 12's result screen is the first consumer.
    var highestCombo: Int { combo.highestCount }
    var scoringCollisionCount: Int { score.scoringCollisionCount }

    /// Records a scoring collision.
    ///
    /// Returns the combo first in the tuple as a reminder of the ordering it
    /// enforces: the combo must advance before the score reads its multiplier,
    /// and the HUD needs the new emphasis before the score pop arrives
    /// (GAMEPLAY §16). Callers cannot get this wrong because they cannot do it
    /// in the other order.
    func registerHit(at time: TimeInterval) -> (combo: ComboEvent, score: ScoreEvent) {
        let comboEvent = combo.registerHit(at: time)
        let scoreEvent = score.award()
        return (comboEvent, scoreEvent)
    }

    /// Expires the combo if its window has closed, returning the new state only
    /// on the transition so callers can report a change without pushing state
    /// every frame.
    func expireCombo(at time: TimeInterval) -> ComboEvent? {
        guard combo.expireIfNeeded(at: time) else { return nil }
        return combo.currentEvent
    }

    /// Clears everything for a new round.
    func reset() {
        score.reset()
        combo.reset()
    }
}
