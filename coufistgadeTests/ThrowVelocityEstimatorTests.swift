//
//  ThrowVelocityEstimatorTests.swift
//  coufistgadeTests
//

import XCTest
@testable import coufistgade

final class ThrowVelocityEstimatorTests: XCTestCase {

    private let window = GameConfiguration.Input.throwSampleWindow

    // MARK: - Basic estimation

    func testSteadyDragProducesMatchingVelocity() {
        var sut = ThrowVelocityEstimator()
        // 1000 pt/s rightward, sampled at 60Hz.
        let step = 1.0 / 60.0
        for i in 0...12 {
            sut.record(point: CGPoint(x: Double(i) * 1000 * step, y: 0), time: Double(i) * step)
        }

        let velocity = sut.velocity(
            releasePoint: CGPoint(x: 13 * 1000 * step, y: 0),
            releaseTime: 13 * step
        )

        XCTAssertEqual(velocity.dx, 1000, accuracy: 60)
        XCTAssertEqual(velocity.dy, 0, accuracy: 1)
    }

    func testDiagonalDragPreservesDirection() {
        var sut = ThrowVelocityEstimator()
        for i in 0...10 {
            let t = Double(i) / 60.0
            sut.record(point: CGPoint(x: Double(i) * 10, y: Double(i) * 10), time: t)
        }

        let velocity = sut.velocity(releasePoint: CGPoint(x: 110, y: 110), releaseTime: 11 / 60.0)

        // Equal components in, equal components out.
        XCTAssertEqual(velocity.dx, velocity.dy, accuracy: 1)
        XCTAssertGreaterThan(velocity.dx, 0)
    }

    // MARK: - The flick case (GAMEPLAY §7 / review item 7.2)

    func testSlowDragThenFlickReportsTheFlickNotTheAverage() {
        var sut = ThrowVelocityEstimator()

        // A slow crawl: 20pt over 0.5s. Sampled at 60Hz like a real finger —
        // touchesMoved fires per frame however slowly the finger moves, just
        // with smaller deltas.
        let frame = 1.0 / 60.0
        var time = 0.0
        let crawlFrames = 30
        for i in 0..<crawlFrames {
            time = Double(i) * frame
            sut.record(point: CGPoint(x: Double(i) * (20.0 / Double(crawlFrames)), y: 0), time: time)
        }

        // Then a flick: 60pt over 2 frames ≈ 1800 pt/s.
        time += frame
        sut.record(point: CGPoint(x: 50, y: 0), time: time)
        time += frame
        let releaseTime = time

        let velocity = sut.velocity(releasePoint: CGPoint(x: 80, y: 0), releaseTime: releaseTime)

        // Averaging the whole gesture would give ~150 pt/s. The flick is what
        // the player intended, and it must dominate.
        XCTAssertGreaterThan(
            velocity.dx,
            1000,
            "Averaging over the whole drag swallowed the flick."
        )
    }

    func testRestingBeforeReleaseThrowsNothing() {
        var sut = ThrowVelocityEstimator()

        // Move fast...
        for i in 0...5 {
            sut.record(point: CGPoint(x: Double(i) * 40, y: 0), time: Double(i) / 60.0)
        }
        // ...then hold still for half a second. touchesMoved stops firing, so no
        // further samples arrive.
        let releaseTime = 5 / 60.0 + 0.5

        let velocity = sut.velocity(releasePoint: CGPoint(x: 200, y: 0), releaseTime: releaseTime)

        // Anchoring the window to the newest sample instead of the release time
        // would fling a ball the player had parked.
        XCTAssertEqual(hypot(velocity.dx, velocity.dy), 0, accuracy: 1)
    }

    // MARK: - Degenerate input

    func testNoSamplesProducesZero() {
        let sut = ThrowVelocityEstimator()

        let velocity = sut.velocity(releasePoint: CGPoint(x: 10, y: 10), releaseTime: 1)

        XCTAssertEqual(velocity.dx, 0)
        XCTAssertEqual(velocity.dy, 0)
    }

    func testSingleSampleAtTheReleaseInstantProducesZero() {
        var sut = ThrowVelocityEstimator()
        sut.record(point: CGPoint(x: 5, y: 5), time: 2.0)

        // Zero elapsed time must not divide by zero.
        let velocity = sut.velocity(releasePoint: CGPoint(x: 5, y: 5), releaseTime: 2.0)

        XCTAssertFalse(velocity.dx.isNaN)
        XCTAssertFalse(velocity.dy.isNaN)
        XCTAssertEqual(velocity.dx, 0)
    }

    func testTapWithoutMovementProducesZero() {
        var sut = ThrowVelocityEstimator()
        sut.record(point: CGPoint(x: 100, y: 100), time: 0)

        let velocity = sut.velocity(releasePoint: CGPoint(x: 100, y: 100), releaseTime: 0.05)

        XCTAssertEqual(hypot(velocity.dx, velocity.dy), 0, accuracy: .ulpOfOne)
    }

    func testResetDiscardsHistory() {
        var sut = ThrowVelocityEstimator()
        for i in 0...5 {
            sut.record(point: CGPoint(x: Double(i) * 50, y: 0), time: Double(i) / 60.0)
        }

        sut.reset()

        let velocity = sut.velocity(releasePoint: CGPoint(x: 500, y: 0), releaseTime: 1)
        XCTAssertEqual(velocity.dx, 0)
    }

    func testLongDragDoesNotGrowUnbounded() {
        var sut = ThrowVelocityEstimator()
        // 10 seconds at 60Hz would be 600 samples if unbounded.
        for i in 0...600 {
            sut.record(point: CGPoint(x: Double(i), y: 0), time: Double(i) / 60.0)
        }

        // Still produces a sane answer rather than degrading.
        let velocity = sut.velocity(releasePoint: CGPoint(x: 601, y: 0), releaseTime: 601 / 60.0)
        XCTAssertEqual(velocity.dx, 60, accuracy: 15)
    }

    // MARK: - Clamping (GAMEPLAY §7)

    func testSpeedBelowTheDeadZoneBecomesZero() {
        let slow = CGVector(dx: GameConfiguration.Input.minimumThrowSpeed - 10, dy: 0)

        let result = ThrowVelocityEstimator.clamped(slow)

        // A gentle release places the ball; it does not nudge it.
        XCTAssertEqual(result.dx, 0)
        XCTAssertEqual(result.dy, 0)
    }

    func testSpeedAtTheDeadZoneIsKept() {
        let atEdge = CGVector(dx: GameConfiguration.Input.minimumThrowSpeed, dy: 0)

        let result = ThrowVelocityEstimator.clamped(atEdge)

        XCTAssertEqual(result.dx, GameConfiguration.Input.minimumThrowSpeed, accuracy: 0.01)
    }

    func testExcessiveSpeedIsCappedButKeepsDirection() {
        let wild = CGVector(dx: 9000, dy: 12000)

        let result = ThrowVelocityEstimator.clamped(wild)

        let speed = hypot(result.dx, result.dy)
        XCTAssertEqual(speed, GameConfiguration.Input.maximumThrowSpeed, accuracy: 0.5)
        // 3:4 ratio in, 3:4 ratio out.
        XCTAssertEqual(result.dy / result.dx, 12000.0 / 9000.0, accuracy: 0.01)
    }

    func testOrdinarySpeedPassesThroughUnchanged() {
        let normal = CGVector(dx: 400, dy: -300)

        let result = ThrowVelocityEstimator.clamped(normal)

        XCTAssertEqual(result.dx, 400, accuracy: 0.01)
        XCTAssertEqual(result.dy, -300, accuracy: 0.01)
    }
}
