//
//  ScoreManagerTests.swift
//  coufistgadeTests
//
//  ScoreManager takes no SpriteKit and no clock, so the whole scoring rule is
//  testable directly.
//

import XCTest
@testable import coufistgade

final class ScoreManagerTests: XCTestCase {

    // MARK: - Base scoring

    func testStartsAtZero() {
        let sut = ScoreManager()

        XCTAssertEqual(sut.total, 0)
        XCTAssertEqual(sut.scoringCollisionCount, 0)
    }

    func testOneCollisionAwardsTheBaseScore() {
        let sut = ScoreManager()

        let event = sut.award()

        XCTAssertEqual(event.points, GameConfiguration.Score.base)
        XCTAssertEqual(event.total, GameConfiguration.Score.base)
        XCTAssertEqual(sut.total, GameConfiguration.Score.base)
    }

    func testScoreAccumulatesAcrossCollisions() {
        let sut = ScoreManager()
        let base = GameConfiguration.Score.base

        for hit in 1...5 {
            let event = sut.award()
            XCTAssertEqual(event.total, base * hit)
        }
        XCTAssertEqual(sut.total, base * 5)
        XCTAssertEqual(sut.scoringCollisionCount, 5)
    }

    func testBaseScoreMatchesTheDesignDocument() {
        // GAMEPLAY §13 states 10 points. Worth pinning: it is the one number
        // every score in the game is built from.
        XCTAssertEqual(GameConfiguration.Score.base, 10)
    }

    // MARK: - Multiplier

    func testDefaultMultiplierIsTheFirstRungOfTheComboLadder() {
        // GAMEPLAY §15: combo 0–1 is 1x. Not a placeholder.
        XCTAssertEqual(GameConfiguration.Score.defaultMultiplier, 1)
    }

    func testMultiplierScalesTheAward() {
        // Stands in for Phase 9's ComboManager.
        var multiplier = 1
        let sut = ScoreManager(multiplierProvider: { multiplier })
        let base = GameConfiguration.Score.base

        XCTAssertEqual(sut.award().points, base)
        multiplier = 3
        XCTAssertEqual(sut.award().points, base * 3)
        multiplier = 10
        XCTAssertEqual(sut.award().points, base * 10)

        XCTAssertEqual(sut.total, base * 14)
    }

    func testMultiplierIsReadAtAwardTimeNotAtInit() {
        // A stored Int would freeze the multiplier at construction, silently
        // disabling combo scoring for the whole round.
        var multiplier = 1
        let sut = ScoreManager(multiplierProvider: { multiplier })
        multiplier = 5

        XCTAssertEqual(sut.award().points, GameConfiguration.Score.base * 5)
    }

    func testEventReportsTheMultiplierThatWasApplied() {
        let sut = ScoreManager(multiplierProvider: { 5 })

        XCTAssertEqual(sut.award().multiplier, 5)
    }

    func testAllDocumentedMultipliersProduceWholeScores() {
        // GAMEPLAY §15's ladder. No rung may produce a fractional or negative
        // award once it is wired up in Phase 9.
        for multiplier in [1, 2, 3, 5, 10] {
            let sut = ScoreManager(multiplierProvider: { multiplier })
            let event = sut.award()

            XCTAssertEqual(event.points, GameConfiguration.Score.base * multiplier)
            XCTAssertGreaterThan(event.points, 0)
        }
    }

    func testABrokenMultiplierCannotDrainTheScore() {
        // Defensive: a combo bug returning 0 or a negative must not make hits
        // worthless or subtract points.
        for broken in [0, -1, -100] {
            let sut = ScoreManager(multiplierProvider: { broken })
            let event = sut.award()

            XCTAssertEqual(event.points, GameConfiguration.Score.base)
            XCTAssertGreaterThan(sut.total, 0)
        }
    }

    // MARK: - Intensity independence

    func testScoreDoesNotScaleWithImpactIntensity() {
        // GAMEPLAY §13 is base × combo. Intensity drives feedback (§12), not
        // score: paying more for hard hits would punish the gentle taps that
        // set up a chain.
        XCTAssertFalse(GameConfiguration.Score.scalesWithImpactIntensity)

        let sut = ScoreManager()
        let first = sut.award()
        let second = sut.award()

        // Same award regardless of how the collision was graded — award() takes
        // no intensity argument, which is the structural guarantee.
        XCTAssertEqual(first.points, second.points)
    }

    // MARK: - Reset

    func testResetClearsScoreAndCount() {
        let sut = ScoreManager()
        (0..<7).forEach { _ in sut.award() }

        sut.reset()

        XCTAssertEqual(sut.total, 0)
        XCTAssertEqual(sut.scoringCollisionCount, 0)
    }

    func testScoringAfterResetStartsFromTheBaseAgain() {
        let sut = ScoreManager()
        (0..<3).forEach { _ in sut.award() }
        sut.reset()

        XCTAssertEqual(sut.award().total, GameConfiguration.Score.base)
    }
}
