//
//  HapticServiceTests.swift
//  coufistgadeTests
//
//  The clock is injected, so the rate limit is testable without waiting.
//

import XCTest
@testable import coufistgade

final class HapticServiceTests: XCTestCase {

    private let interval = GameConfiguration.Feedback.Haptics.minimumInterval

    // MARK: - Tier mapping

    func testLowImpactHasNoHapticAtAll() {
        // GAMEPLAY §12 gives Low a particle burst and a light sound, no haptic.
        // Buzzing on every gentle tap would desensitise the player.
        XCTAssertNil(GameConfiguration.Feedback.Haptics.style(for: .low))
    }

    func testMediumAndHighHaveDistinctStrengths() throws {
        let medium = try XCTUnwrap(GameConfiguration.Feedback.Haptics.style(for: .medium))
        let high = try XCTUnwrap(GameConfiguration.Feedback.Haptics.style(for: .high))

        XCTAssertNotEqual(medium, high, "Feedback must scale with intensity (§11).")
        XCTAssertEqual(medium, .light)
        XCTAssertEqual(high, .heavy)
    }

    // MARK: - Rate limiting

    func testRapidImpactsAreThrottled() {
        var time: TimeInterval = 0
        let sut = HapticService(now: { time })

        // The collision cooldown alone permits ~7/s; without a limiter that is
        // a buzz rather than distinct taps.
        var played = 0
        for _ in 0..<10 {
            let before = sut.debugPlayCount
            sut.playImpact(.high)
            if sut.debugPlayCount > before { played += 1 }
            time += 0.02
        }

        XCTAssertLessThan(played, 10)
        XCTAssertGreaterThanOrEqual(played, 1, "Everything was suppressed.")
    }

    func testAHapticPlaysOnceTheIntervalHasElapsed() {
        var time: TimeInterval = 0
        let sut = HapticService(now: { time })

        sut.playImpact(.high)
        let afterFirst = sut.debugPlayCount

        time += interval
        sut.playImpact(.high)

        XCTAssertEqual(sut.debugPlayCount, afterFirst + 1)
    }

    func testTheLimitIsSharedBetweenImpactsAndMilestones() {
        var time: TimeInterval = 0
        let sut = HapticService(now: { time })

        // A milestone landing on the same frame as its impact would otherwise
        // double-fire, which feels like a stutter rather than an event.
        sut.playImpact(.high)
        let afterImpact = sut.debugPlayCount
        sut.playComboMilestone()

        XCTAssertEqual(sut.debugPlayCount, afterImpact, "Milestone bypassed the limiter.")
    }

    func testLowImpactsDoNotConsumeTheRateLimit() {
        var time: TimeInterval = 0
        let sut = HapticService(now: { time })

        // Low plays nothing, so it must not spend the budget a real hit needs.
        sut.playImpact(.low)
        sut.playImpact(.high)

        XCTAssertEqual(sut.debugPlayCount, 1)
    }

    // MARK: - Enablement

    func testDisablingSilencesEverything() {
        var time: TimeInterval = 0
        let sut = HapticService(now: { time })
        sut.isEnabled = false

        sut.playImpact(.high)
        time += 10
        sut.playComboMilestone()

        XCTAssertEqual(sut.debugPlayCount, 0)
    }

    func testDisabledCallsDoNotConsumeTheRateLimit() {
        var time: TimeInterval = 0
        let sut = HapticService(now: { time })

        // Phase 14 toggles this at runtime; a disabled call must not leave the
        // limiter armed against the next enabled one.
        sut.isEnabled = false
        sut.playImpact(.high)
        sut.isEnabled = true
        sut.playImpact(.high)

        XCTAssertEqual(sut.debugPlayCount, 1)
    }
}
