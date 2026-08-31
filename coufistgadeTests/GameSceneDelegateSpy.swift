//
//  GameSceneDelegateSpy.swift
//  coufistgadeTests
//
//  Shared because three test files need it and the protocol grows every phase.
//

import Foundation
@testable import coufistgade

final class GameSceneDelegateSpy: GameSceneDelegate {

    var scores: [ScoreEvent] = []
    var combos: [ComboEvent] = []
    var states: [GameState] = []
    var remainingTimes: [Int] = []
    var finishedRoundCount = 0

    /// Interleaved record of every callback, so ordering can be asserted.
    var calls: [String] = []

    func gameScene(_ scene: GameScene, didScore event: ScoreEvent) {
        scores.append(event)
        calls.append("score")
    }

    func gameScene(_ scene: GameScene, didUpdateCombo event: ComboEvent) {
        combos.append(event)
        calls.append("combo")
    }

    func gameScene(_ scene: GameScene, didChangeState state: GameState) {
        states.append(state)
        calls.append("state.\(state)")
    }

    func gameScene(_ scene: GameScene, didUpdateRemainingTime seconds: Int) {
        remainingTimes.append(seconds)
        calls.append("time")
    }

    func gameSceneDidFinishRound(_ scene: GameScene) {
        finishedRoundCount += 1
        calls.append("finish")
    }
}
