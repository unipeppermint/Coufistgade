//
//  HeroBallViewTests.swift
//  coufistgadeTests
//

import XCTest
@testable import coufistgade

final class HeroBallViewTests: XCTestCase {

    private func makeSUT(reduceMotion: Bool) -> HeroBallView {
        let sut = HeroBallView(prefersReducedMotion: { reduceMotion })
        sut.frame = CGRect(x: 0, y: 0, width: 160, height: 160)
        sut.layoutIfNeeded()
        return sut
    }

    func testFloatsWhenMotionIsAllowed() {
        let sut = makeSUT(reduceMotion: false)

        sut.startFloating()

        XCTAssertTrue(sut.isFloating)
    }

    func testDoesNotFloatUnderReduceMotion() {
        let sut = makeSUT(reduceMotion: true)

        sut.startFloating()

        XCTAssertFalse(sut.isFloating, "Reduce Motion must suppress the breathe animation.")
    }

    func testStopFloatingRemovesAnimation() {
        let sut = makeSUT(reduceMotion: false)
        sut.startFloating()

        sut.stopFloating()

        XCTAssertFalse(sut.isFloating)
    }

    func testStartFloatingIsIdempotent() {
        let sut = makeSUT(reduceMotion: false)

        sut.startFloating()
        sut.startFloating()

        // Re-arming must replace the animation, never stack a second copy.
        XCTAssertTrue(sut.isFloating)
        XCTAssertEqual(sut.layer.animationKeys()?.count, 1)
    }

    func testDoesNotAnimateWithZeroSize() {
        let sut = HeroBallView(prefersReducedMotion: { false })

        sut.startFloating()

        XCTAssertFalse(sut.isFloating, "A zero-sized ball has nothing to animate.")
    }

    func testIsNotInteractive() {
        // The hero ball is decoration; taps belong to the Play button.
        XCTAssertFalse(makeSUT(reduceMotion: false).isUserInteractionEnabled)
    }
}
