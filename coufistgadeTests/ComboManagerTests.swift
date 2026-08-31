//
//  ComboManagerTests.swift
//  coufistgadeTests
//
//  The clock is a parameter, so the whole 2-second window is testable without
//  waiting 2 seconds.
//

import XCTest
@testable import coufistgade

final class ComboManagerTests: XCTestCase {

    private let window = GameConfiguration.Combo.window

    // MARK: - Counting

    func testStartsWithNoCombo() {
        let sut = ComboManager()

        XCTAssertEqual(sut.count, 0)
        XCTAssertEqual(sut.multiplier, 1)
        XCTAssertFalse(sut.isVisible)
    }

    func testEachHitInsideTheWindowExtendsTheCombo() {
        let sut = ComboManager()

        for hit in 1...6 {
            let event = sut.registerHit(at: Double(hit) * 0.3)
            XCTAssertEqual(event.count, hit)
        }
    }

    func testAHitAfterTheWindowStartsANewComboAtOne() {
        let sut = ComboManager()
        sut.registerHit(at: 0)
        sut.registerHit(at: 0.5)
        XCTAssertEqual(sut.count, 2)

        // Long gap: the old combo is gone, this is a fresh one.
        let event = sut.registerHit(at: 0.5 + window + 0.01)

        XCTAssertEqual(event.count, 1)
    }

    func testTheWindowIsMeasuredFromTheLastHitNotTheFirst() {
        let sut = ComboManager()

        // Each hit is inside the window relative to the previous one, so a long
        // rally must keep counting even though it spans far more than 2s.
        var time: TimeInterval = 0
        for _ in 1...10 {
            time += window * 0.9
            sut.registerHit(at: time)
        }

        XCTAssertEqual(sut.count, 10)
        XCTAssertGreaterThan(time, window * 5)
    }

    // MARK: - Expiry

    func testComboSurvivesRightUpToTheWindow() {
        let sut = ComboManager()
        sut.registerHit(at: 0)

        XCTAssertFalse(sut.expireIfNeeded(at: window - 0.01))
        XCTAssertEqual(sut.count, 1)
    }

    func testComboLapsesAtTheWindow() {
        let sut = ComboManager()
        sut.registerHit(at: 0)

        XCTAssertTrue(sut.expireIfNeeded(at: window))
        XCTAssertEqual(sut.count, 0)
        XCTAssertEqual(sut.multiplier, 1)
    }

    func testExpiryReportsTheTransitionOnlyOnce() {
        let sut = ComboManager()
        sut.registerHit(at: 0)

        XCTAssertTrue(sut.expireIfNeeded(at: window))
        // Per-frame calls afterwards must stay silent, or the HUD would be
        // pushed 60 times a second (ARCHITECTURE §23).
        for frame in 1...30 {
            XCTAssertFalse(sut.expireIfNeeded(at: window + Double(frame) / 60))
        }
    }

    func testExpiryDoesNothingWithoutACombo() {
        let sut = ComboManager()

        XCTAssertFalse(sut.expireIfNeeded(at: 99))
    }

    func testABackwardClockDoesNotFreezeTheComboOpen() {
        let sut = ComboManager()
        sut.registerHit(at: 100)

        // A re-presented scene restarts its clock near zero. Without handling
        // this the combo would never expire again for the rest of the round.
        XCTAssertTrue(sut.expireIfNeeded(at: 0))
        XCTAssertEqual(sut.count, 0)
    }

    func testRegisteringAHitExpiresAStaleComboWithoutTheFrameLoop() {
        let sut = ComboManager()
        sut.registerHit(at: 0)
        sut.registerHit(at: 0.2)

        // expireIfNeeded never ran — registerHit must still not extend a dead
        // combo, or a paused game would resume with a stale multiplier.
        XCTAssertEqual(sut.registerHit(at: 10).count, 1)
    }

    // MARK: - Multiplier ladder

    func testLadderMatchesTheDesignDocument() {
        // GAMEPLAY §15: 0–1 → 1x, 2–3 → 2x, 4–6 → 3x, 7–9 → 5x, 10+ → 10x.
        let expected: [Int: Int] = [
            0: 1, 1: 1,
            2: 2, 3: 2,
            4: 3, 5: 3, 6: 3,
            7: 5, 8: 5, 9: 5,
            10: 10, 11: 10, 25: 10,
        ]

        for (count, multiplier) in expected.sorted(by: { $0.key < $1.key }) {
            let sut = ComboManager()
            for hit in 0..<count {
                sut.registerHit(at: Double(hit) * 0.1)
            }
            XCTAssertEqual(sut.multiplier, multiplier, "combo \(count)")
        }
    }

    func testLadderIsOrderedHighestFirstSoLookupIsCorrect() {
        // The lookup takes the first rung the count reaches, so an out-of-order
        // table would silently return the wrong multiplier.
        let thresholds = GameConfiguration.Combo.multiplierLadder.map(\.minimumCount)

        XCTAssertEqual(thresholds, thresholds.sorted(by: >))
    }

    func testMultiplierNeverDecreasesAsTheComboGrows() {
        var previous = 1
        let sut = ComboManager()

        for hit in 1...20 {
            sut.registerHit(at: Double(hit) * 0.1)
            XCTAssertGreaterThanOrEqual(sut.multiplier, previous, "combo \(hit)")
            previous = sut.multiplier
        }
    }

    func testMultiplierReturnsToOneAfterALapse() {
        let sut = ComboManager()
        (1...5).forEach { sut.registerHit(at: Double($0) * 0.1) }
        XCTAssertEqual(sut.multiplier, 3)

        sut.expireIfNeeded(at: 100)

        XCTAssertEqual(sut.multiplier, 1)
    }

    // MARK: - Visibility and emphasis

    func testReadoutAppearsOnlyOnceTheComboPaysMoreThanOnce() {
        // UI_DESIGN §10: appear only when relevant.
        let sut = ComboManager()

        sut.registerHit(at: 0)
        XCTAssertFalse(sut.isVisible, "1x combo should stay hidden.")
        XCTAssertEqual(sut.multiplier, 1)

        sut.registerHit(at: 0.1)
        XCTAssertTrue(sut.isVisible)
        XCTAssertGreaterThan(sut.multiplier, 1)
    }

    func testEmphasisEscalatesAtTheDocumentedCombos() {
        // GAMEPLAY §16: stronger at 4, major at 10.
        let sut = ComboManager()

        sut.registerHit(at: 0)
        XCTAssertEqual(sut.emphasis, .normal)

        while sut.count < 4 { sut.registerHit(at: Double(sut.count) * 0.1) }
        XCTAssertEqual(sut.emphasis, .strong)

        while sut.count < 10 { sut.registerHit(at: Double(sut.count) * 0.1) }
        XCTAssertEqual(sut.emphasis, .major)
    }

    func testEmphasisResetsWithTheCombo() {
        let sut = ComboManager()
        (1...12).forEach { sut.registerHit(at: Double($0) * 0.1) }
        XCTAssertEqual(sut.emphasis, .major)

        sut.expireIfNeeded(at: 100)

        XCTAssertEqual(sut.emphasis, .normal)
    }

    // MARK: - Highest combo

    func testHighestComboSurvivesALapse() {
        let sut = ComboManager()
        (1...7).forEach { sut.registerHit(at: Double($0) * 0.1) }

        sut.expireIfNeeded(at: 100)

        // GAMEPLAY §22 shows this after the round, so a lapse must not erase it.
        XCTAssertEqual(sut.count, 0)
        XCTAssertEqual(sut.highestCount, 7)
    }

    func testHighestComboKeepsTheBestOfSeveralRallies() {
        let sut = ComboManager()
        (1...3).forEach { sut.registerHit(at: Double($0) * 0.1) }
        sut.expireIfNeeded(at: 50)
        (1...9).forEach { sut.registerHit(at: 50 + Double($0) * 0.1) }
        sut.expireIfNeeded(at: 100)
        (1...2).forEach { sut.registerHit(at: 100 + Double($0) * 0.1) }

        XCTAssertEqual(sut.highestCount, 9)
    }

    // MARK: - Reset

    func testResetClearsEverythingIncludingTheRoundBest() {
        let sut = ComboManager()
        (1...8).forEach { sut.registerHit(at: Double($0) * 0.1) }

        sut.reset()

        XCTAssertEqual(sut.count, 0)
        XCTAssertEqual(sut.highestCount, 0)
        XCTAssertEqual(sut.multiplier, 1)
        XCTAssertFalse(sut.isVisible)
    }

    // MARK: - Interaction with the collision cooldown

    func testTheWindowIsLongerThanTheRepeatContactCooldown() {
        // If the cooldown were the longer of the two, a player could never
        // chain hits on one ball and the ladder above 1x would be unreachable
        // in that situation.
        XCTAssertLessThan(GameConfiguration.Collision.repeatContactCooldown, window)
    }

    func testAPlayerCanReachTheTopRungWithinOneWindowPerHit() {
        let sut = ComboManager()
        let cooldown = GameConfiguration.Collision.repeatContactCooldown

        // Hits at the fastest rate the collision system permits.
        for hit in 1...10 {
            sut.registerHit(at: Double(hit) * cooldown)
        }

        XCTAssertEqual(sut.count, 10)
        XCTAssertEqual(sut.multiplier, 10)
    }
}
