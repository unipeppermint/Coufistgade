//
//  GameHUDViewTests.swift
//  coufistgadeTests
//

import XCTest
@testable import coufistgade

final class GameHUDViewTests: XCTestCase {

    func testShowsScoreAndComboTogether() {
        let sut = GameHUDView(
            scoreHUD: ScoreHUDView(prefersReducedMotion: { true }),
            comboHUD: ComboHUDView(prefersReducedMotion: { true })
        )

        sut.apply(combo: ComboEvent(count: 3, multiplier: 2, emphasis: .normal, isVisible: true))
        sut.apply(score: ScoreEvent(points: 20, total: 60, multiplier: 2))

        XCTAssertEqual(sut.displayedScoreText, "60")
        XCTAssertEqual(sut.displayedMultiplierText, "×2")
        XCTAssertTrue(sut.isComboVisible)
    }

    func testResetClearsBothReadouts() {
        let sut = GameHUDView(
            scoreHUD: ScoreHUDView(prefersReducedMotion: { true }),
            comboHUD: ComboHUDView(prefersReducedMotion: { true })
        )
        sut.apply(combo: ComboEvent(count: 5, multiplier: 3, emphasis: .strong, isVisible: true))
        sut.apply(score: ScoreEvent(points: 30, total: 300, multiplier: 3))

        sut.reset()

        XCTAssertEqual(sut.displayedScoreText, "0")
        XCTAssertFalse(sut.isComboVisible)
    }

    func testHUDReservesTheComboRowSoItsHeightDoesNotChange() {
        let sut = GameHUDView(
            scoreHUD: ScoreHUDView(prefersReducedMotion: { true }),
            comboHUD: ComboHUDView(prefersReducedMotion: { true })
        )
        sut.frame = CGRect(x: 0, y: 0, width: 300, height: 0)
        sut.layoutIfNeeded()
        let hiddenHeight = sut.systemLayoutSizeFitting(
            UIView.layoutFittingCompressedSize
        ).height

        sut.apply(combo: ComboEvent(count: 4, multiplier: 3, emphasis: .strong, isVisible: true))
        sut.layoutIfNeeded()
        let visibleHeight = sut.systemLayoutSizeFitting(
            UIView.layoutFittingCompressedSize
        ).height

        // The physics ceiling is derived from this height. If it changed when a
        // combo started, balls would be shoved around mid-round.
        XCTAssertEqual(hiddenHeight, visibleHeight, accuracy: 0.5)
    }

    func testDoesNotInterceptTouches() {
        XCTAssertFalse(GameHUDView().isUserInteractionEnabled)
    }
}
