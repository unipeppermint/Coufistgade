//
//  RoundStateTests.swift
//  coufistgadeTests
//

import XCTest
@testable import coufistgade

final class RoundStateTests: XCTestCase {

    func testStartsEmpty() {
        let sut = RoundState()

        XCTAssertEqual(sut.total, 0)
        XCTAssertEqual(sut.comboCount, 0)
        XCTAssertEqual(sut.highestCombo, 0)
    }

    func testAHitAdvancesTheComboBeforeScoring() {
        let sut = RoundState()

        let (combo, score) = sut.registerHit(at: 0)

        // The combo is already at 1 when the score is computed, so the
        // multiplier the score used is the post-hit one.
        XCTAssertEqual(combo.count, 1)
        XCTAssertEqual(score.multiplier, combo.multiplier)
    }

    func testTheMultiplierAppliedIsTheOneTheComboHadReached() {
        let sut = RoundState()

        // Fourth hit: GAMEPLAY §15 puts combo 4 on the 3x rung, and the award
        // must use 3x, not the 2x that was current a moment earlier.
        var last: (combo: ComboEvent, score: ScoreEvent)?
        for hit in 0..<4 {
            last = sut.registerHit(at: Double(hit) * 0.2)
        }

        XCTAssertEqual(last?.combo.count, 4)
        XCTAssertEqual(last?.score.multiplier, 3)
        XCTAssertEqual(last?.score.points, GameConfiguration.Score.base * 3)
    }

    func testTotalIsTheSumOfMultipliedAwards() {
        let sut = RoundState()
        var expected = 0

        for hit in 0..<6 {
            expected += sut.registerHit(at: Double(hit) * 0.2).score.points
        }

        XCTAssertEqual(sut.total, expected)
    }

    func testALapseIsReportedOnceAndClearsTheCombo() {
        let sut = RoundState()
        sut.registerHit(at: 0)

        let lapsed = sut.expireCombo(at: GameConfiguration.Combo.window)

        XCTAssertEqual(lapsed?.count, 0)
        XCTAssertEqual(sut.comboCount, 0)
        // Silent afterwards, so the caller does not push state every frame.
        XCTAssertNil(sut.expireCombo(at: GameConfiguration.Combo.window + 1))
    }

    func testScoreSurvivesALapseButTheMultiplierDoesNot() {
        let sut = RoundState()
        (0..<5).forEach { sut.registerHit(at: Double($0) * 0.2) }
        let banked = sut.total

        sut.expireCombo(at: 100)
        let afterLapse = sut.registerHit(at: 100)

        XCTAssertGreaterThan(banked, 0)
        XCTAssertEqual(sut.total, banked + GameConfiguration.Score.base)
        XCTAssertEqual(afterLapse.score.multiplier, 1)
    }

    func testHighestComboOutlivesALapse() {
        let sut = RoundState()
        (0..<8).forEach { sut.registerHit(at: Double($0) * 0.2) }

        sut.expireCombo(at: 100)

        XCTAssertEqual(sut.comboCount, 0)
        XCTAssertEqual(sut.highestCombo, 8)
    }

    func testResetClearsEverything() {
        let sut = RoundState()
        (0..<4).forEach { sut.registerHit(at: Double($0) * 0.2) }

        sut.reset()

        XCTAssertEqual(sut.total, 0)
        XCTAssertEqual(sut.comboCount, 0)
        XCTAssertEqual(sut.highestCombo, 0)
        XCTAssertEqual(sut.scoringCollisionCount, 0)
    }
}
