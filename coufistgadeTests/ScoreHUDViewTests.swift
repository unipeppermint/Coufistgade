//
//  ScoreHUDViewTests.swift
//  coufistgadeTests
//

import XCTest
@testable import coufistgade

final class ScoreHUDViewTests: XCTestCase {

    private func valueLabel(in view: ScoreHUDView) -> UILabel? {
        view.subviews
            .compactMap { $0 as? UIStackView }
            .flatMap(\.arrangedSubviews)
            .compactMap { $0 as? UILabel }
            .first { $0.accessibilityIdentifier == ScoreHUDView.AccessibilityID.value }
    }

    // MARK: - Display

    func testStartsAtZero() throws {
        let sut = ScoreHUDView()

        XCTAssertEqual(try XCTUnwrap(valueLabel(in: sut)).text, "0")
    }

    func testShowsTheTotalFromAScoreEvent() throws {
        let sut = ScoreHUDView()

        sut.apply(ScoreEvent(points: 10, total: 120, multiplier: 1))

        // The running total, not the points just earned.
        XCTAssertEqual(try XCTUnwrap(valueLabel(in: sut)).text, "120")
    }

    func testResetReturnsToZero() throws {
        let sut = ScoreHUDView()
        sut.apply(ScoreEvent(points: 10, total: 340, multiplier: 2))

        sut.reset()

        XCTAssertEqual(try XCTUnwrap(valueLabel(in: sut)).text, "0")
    }

    func testEveryDigitIsTheSameWidthSoTheNumberDoesNotJitter() throws {
        let sut = ScoreHUDView()
        let font = try XCTUnwrap(valueLabel(in: sut)).font

        // Measures the property that matters rather than the font's traits:
        // monospacedDigitSystemFont monospaces the digits only, so it does not
        // advertise traitMonoSpace even though the digits do align.
        let widths = (0...9).map {
            ("\($0)" as NSString).size(withAttributes: [.font: font as Any]).width
        }

        // A proportional font shifts the readout sideways as digits change,
        // which reads as instability right next to a bouncing ball.
        XCTAssertEqual(Set(widths).count, 1, "Digit widths differ: \(widths)")
    }

    // MARK: - Accessibility

    func testValueCarriesASpokenLabel() throws {
        let sut = ScoreHUDView()

        sut.apply(ScoreEvent(points: 10, total: 50, multiplier: 1))

        // VoiceOver should say "Score 50", not read "SCORE" and "50" as two
        // unrelated fragments.
        XCTAssertEqual(try XCTUnwrap(valueLabel(in: sut)).accessibilityLabel, Strings.scoreLabel(50))
    }

    func testSupportsDynamicType() throws {
        let sut = ScoreHUDView()

        XCTAssertTrue(try XCTUnwrap(valueLabel(in: sut)).adjustsFontForContentSizeCategory)
    }

    func testHUDDoesNotInterceptTouchesMeantForTheBall() {
        let sut = ScoreHUDView()

        // The HUD sits over the playable area; swallowing touches there would
        // create a dead zone the player cannot see.
        XCTAssertFalse(sut.isUserInteractionEnabled)
    }

    // MARK: - Animation

    func testScoreIsCorrectEvenWhenMotionIsReduced() throws {
        let sut = ScoreHUDView(prefersReducedMotion: { true })

        sut.apply(ScoreEvent(points: 10, total: 90, multiplier: 1))

        // Reduce Motion may skip the pop; it must never skip the number.
        XCTAssertEqual(try XCTUnwrap(valueLabel(in: sut)).text, "90")
    }

    func testReducedMotionLeavesTheLabelUnscaled() throws {
        let sut = ScoreHUDView(prefersReducedMotion: { true })

        sut.apply(ScoreEvent(points: 10, total: 10, multiplier: 1))

        XCTAssertEqual(try XCTUnwrap(valueLabel(in: sut)).transform, .identity)
    }

    func testRapidHitsDoNotCompoundTheScale() throws {
        let sut = ScoreHUDView(prefersReducedMotion: { false })
        let label = try XCTUnwrap(valueLabel(in: sut))

        // Each pop restarts from identity, so ploughing through a cluster must
        // not leave the label permanently enlarged.
        for total in stride(from: 10, through: 100, by: 10) {
            sut.apply(ScoreEvent(points: 10, total: total, multiplier: 1))
        }

        XCTAssertLessThanOrEqual(label.transform.a, 1.2001)
        XCTAssertEqual(label.text, "100")
    }

    func testResetClearsAnyRunningAnimation() throws {
        let sut = ScoreHUDView(prefersReducedMotion: { false })
        sut.apply(ScoreEvent(points: 10, total: 10, multiplier: 1))

        sut.reset()

        XCTAssertEqual(try XCTUnwrap(valueLabel(in: sut)).transform, .identity)
    }
}
