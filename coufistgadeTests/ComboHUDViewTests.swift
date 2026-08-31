//
//  ComboHUDViewTests.swift
//  coufistgadeTests
//

import XCTest
@testable import coufistgade

final class ComboHUDViewTests: XCTestCase {

    private func event(
        count: Int,
        multiplier: Int,
        emphasis: ComboEmphasis = .normal,
        visible: Bool = true
    ) -> ComboEvent {
        ComboEvent(count: count, multiplier: multiplier, emphasis: emphasis, isVisible: visible)
    }

    // MARK: - Visibility

    func testStartsHidden() {
        let sut = ComboHUDView()

        // UI_DESIGN §10: appear only when relevant.
        XCTAssertFalse(sut.isReadoutVisible)
    }

    func testStaysHiddenForAOneTimesCombo() {
        let sut = ComboHUDView(prefersReducedMotion: { true })

        sut.apply(event(count: 1, multiplier: 1, visible: false))

        XCTAssertFalse(sut.isReadoutVisible)
    }

    func testAppearsOnceTheComboMatters() {
        let sut = ComboHUDView(prefersReducedMotion: { true })

        sut.apply(event(count: 2, multiplier: 2))

        XCTAssertTrue(sut.isReadoutVisible)
        XCTAssertEqual(sut.displayedMultiplierText, "×2")
    }

    func testHidesAgainWhenTheComboLapses() {
        let sut = ComboHUDView(prefersReducedMotion: { true })
        sut.apply(event(count: 4, multiplier: 3))

        sut.apply(event(count: 0, multiplier: 1, visible: false))

        XCTAssertFalse(sut.isReadoutVisible)
    }

    func testKeepsItsFrameWhileHiddenSoTheHUDHeightIsStable() {
        let sut = ComboHUDView(prefersReducedMotion: { true })
        sut.apply(event(count: 3, multiplier: 2))
        sut.frame = CGRect(x: 0, y: 0, width: 200, height: 30)
        let visibleSize = sut.frame.size

        sut.apply(event(count: 0, multiplier: 1, visible: false))

        // isHidden would collapse it out of the stack, moving the physics
        // ceiling mid-round. Alpha keeps the layout still.
        XCTAssertFalse(sut.isHidden)
        XCTAssertEqual(sut.frame.size, visibleSize)
    }

    // MARK: - Content

    func testShowsTheMultiplierAsTheHeadline() {
        let sut = ComboHUDView(prefersReducedMotion: { true })

        sut.apply(event(count: 8, multiplier: 5))

        // 8 hits pays 5x — the two numbers are not interchangeable.
        XCTAssertEqual(sut.displayedMultiplierText, "×5")
    }

    func testLapseDoesNotBlankTheTextItJustFades() {
        let sut = ComboHUDView(prefersReducedMotion: { true })
        sut.apply(event(count: 4, multiplier: 3))

        sut.apply(event(count: 0, multiplier: 1, visible: false))

        // Rewriting to "×1" underneath a fade would flash the wrong value on
        // the way out.
        XCTAssertEqual(sut.displayedMultiplierText, "×3")
    }

    func testCarriesASpokenLabel() throws {
        let sut = ComboHUDView(prefersReducedMotion: { true })

        sut.apply(event(count: 5, multiplier: 3))

        let label = sut.subviews
            .compactMap { $0 as? UIStackView }
            .flatMap(\.arrangedSubviews)
            .compactMap { $0 as? UILabel }
            .first { $0.accessibilityIdentifier == ComboHUDView.AccessibilityID.value }
        XCTAssertEqual(
            try XCTUnwrap(label).accessibilityLabel,
            Strings.comboLabel(count: 5, multiplier: 3)
        )
    }

    func testDoesNotInterceptTouches() {
        XCTAssertFalse(ComboHUDView().isUserInteractionEnabled)
    }

    // MARK: - Animation

    func testReducedMotionStillShowsTheCorrectMultiplier() {
        let sut = ComboHUDView(prefersReducedMotion: { true })

        sut.apply(event(count: 10, multiplier: 10, emphasis: .major))

        XCTAssertTrue(sut.isReadoutVisible)
        XCTAssertEqual(sut.displayedMultiplierText, "×10")
    }

    func testResetHidesAndClearsAnimation() {
        let sut = ComboHUDView(prefersReducedMotion: { false })
        sut.apply(event(count: 6, multiplier: 3, emphasis: .strong))

        sut.reset()

        XCTAssertFalse(sut.isReadoutVisible)
    }

    func testRapidComboGrowthDoesNotCompoundTheScale() {
        let sut = ComboHUDView(prefersReducedMotion: { false })

        for count in 2...12 {
            sut.apply(event(count: count, multiplier: 3, emphasis: .strong))
        }

        XCTAssertEqual(sut.displayedMultiplierText, "×3")
    }
}
