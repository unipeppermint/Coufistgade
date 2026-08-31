//
//  GameClockTests.swift
//  coufistgadeTests
//

import XCTest
@testable import coufistgade

final class GameClockTests: XCTestCase {

    private let maxDelta = GameConfiguration.Round.maximumFrameDelta

    /// Feeds a run of frames at a fixed interval, returning the final time.
    private func advance(
        _ sut: GameClock,
        from start: TimeInterval,
        frames: Int,
        interval: TimeInterval = 1.0 / 60
    ) -> TimeInterval {
        var time = start
        for _ in 0..<frames {
            time += interval
            sut.advance(to: time)
        }
        return time
    }

    // MARK: - Basic accumulation

    func testStartsStoppedAtZero() {
        let sut = GameClock()

        XCTAssertEqual(sut.elapsed, 0)
        XCTAssertFalse(sut.isRunning)
    }

    func testAStoppedClockIgnoresFrames() {
        let sut = GameClock()

        advance(sut, from: 1000, frames: 60)

        XCTAssertEqual(sut.elapsed, 0)
    }

    func testTheFirstFrameEstablishesABaselineWithoutAdvancing() {
        let sut = GameClock()
        sut.start()

        // Absolute time carries no information about how long the frame took.
        XCTAssertEqual(sut.advance(to: 5_000), 0)
        XCTAssertEqual(sut.elapsed, 0)
    }

    func testElapsedTracksTheSumOfFrameDeltas() {
        let sut = GameClock()
        sut.start()
        sut.advance(to: 1_000)

        advance(sut, from: 1_000, frames: 60)

        XCTAssertEqual(sut.elapsed, 1.0, accuracy: 0.001)
    }

    func testTheClockIsIndependentOfTheAbsoluteTimeItIsGiven() {
        let early = GameClock()
        let late = GameClock()
        early.start(); late.start()
        early.advance(to: 0); late.advance(to: 9_999_999)

        advance(early, from: 0, frames: 30)
        advance(late, from: 9_999_999, frames: 30)

        XCTAssertEqual(early.elapsed, late.elapsed, accuracy: 0.001)
    }

    // MARK: - Pause

    func testTimeSpentPausedDoesNotCount() {
        let sut = GameClock()
        sut.start()
        sut.advance(to: 100)
        var time = advance(sut, from: 100, frames: 60)
        let beforePause = sut.elapsed

        sut.pause()
        // Ten seconds of wall time pass while paused.
        time += 10
        sut.advance(to: time)
        XCTAssertEqual(sut.elapsed, beforePause, accuracy: 0.001)

        sut.resume()
        advance(sut, from: time, frames: 60)

        // Exactly one more second of game time, not eleven.
        XCTAssertEqual(sut.elapsed, beforePause + 1.0, accuracy: 0.05)
    }

    func testResumeDoesNotBillThePauseToTheFirstFrame() {
        let sut = GameClock()
        sut.start()
        sut.advance(to: 100)
        sut.pause()
        sut.resume()

        // The frame right after resume carries the whole pause in absolute time.
        // Dropping lastFrameTime on pause is what stops it counting.
        XCTAssertEqual(sut.advance(to: 130), 0)
        XCTAssertEqual(sut.elapsed, 0, accuracy: 0.001)
    }

    func testPausingAnAlreadyPausedClockIsHarmless() {
        let sut = GameClock()
        sut.start()
        sut.advance(to: 10)
        advance(sut, from: 10, frames: 30)
        let elapsed = sut.elapsed

        sut.pause()
        sut.pause()

        XCTAssertEqual(sut.elapsed, elapsed, accuracy: 0.001)
        XCTAssertFalse(sut.isRunning)
    }

    func testResumingARunningClockChangesNothing() {
        let sut = GameClock()
        sut.start()
        sut.advance(to: 10)
        advance(sut, from: 10, frames: 10)
        let elapsed = sut.elapsed

        sut.resume()

        XCTAssertTrue(sut.isRunning)
        XCTAssertEqual(sut.elapsed, elapsed, accuracy: 0.001)
    }

    // MARK: - Implausible deltas

    func testALongBackgroundIsDiscardedRatherThanConsumingTheRound() {
        let sut = GameClock()
        sut.start()
        sut.advance(to: 100)

        // Two minutes away with no pause call — a crash-to-background, say.
        // Unguarded this would end a 60s round in a single frame.
        let applied = sut.advance(to: 220)

        XCTAssertEqual(applied, 0)
        XCTAssertEqual(sut.elapsed, 0)
        XCTAssertEqual(sut.discardedFrameCount, 1)
    }

    func testAnOrdinaryHitchStillCounts() {
        let sut = GameClock()
        sut.start()
        sut.advance(to: 100)

        // A dropped frame or two is real time the player experienced.
        let applied = sut.advance(to: 100 + maxDelta * 0.9)

        XCTAssertEqual(applied, maxDelta * 0.9, accuracy: 0.001)
        XCTAssertEqual(sut.discardedFrameCount, 0)
    }

    func testTheThresholdItselfIsAccepted() {
        let sut = GameClock()
        sut.start()
        sut.advance(to: 100)

        XCTAssertEqual(sut.advance(to: 100 + maxDelta), maxDelta, accuracy: 0.001)
    }

    func testABackwardsClockIsIgnored() {
        let sut = GameClock()
        sut.start()
        sut.advance(to: 100)
        advance(sut, from: 100, frames: 10)
        let elapsed = sut.elapsed

        // A re-presented scene can restart its clock near zero.
        XCTAssertEqual(sut.advance(to: 5), 0)
        XCTAssertEqual(sut.elapsed, elapsed, accuracy: 0.001)
    }

    func testADiscardedFrameStillRebaselinesSoTheNextOneIsNormal() {
        let sut = GameClock()
        sut.start()
        sut.advance(to: 100)
        sut.advance(to: 220)

        // Without rebaselining, every subsequent frame would measure from 100
        // and be discarded too — the clock would be dead for the rest of the run.
        let applied = sut.advance(to: 220 + 1.0 / 60)

        XCTAssertEqual(applied, 1.0 / 60, accuracy: 0.001)
    }

    // MARK: - Restart

    func testStartClearsAnyPreviousRun() {
        let sut = GameClock()
        sut.start()
        sut.advance(to: 100)
        advance(sut, from: 100, frames: 120)
        XCTAssertGreaterThan(sut.elapsed, 1)

        sut.start()

        XCTAssertEqual(sut.elapsed, 0)
        XCTAssertTrue(sut.isRunning)
    }

    func testResetStopsAndClears() {
        let sut = GameClock()
        sut.start()
        sut.advance(to: 100)
        advance(sut, from: 100, frames: 60)

        sut.reset()

        XCTAssertEqual(sut.elapsed, 0)
        XCTAssertFalse(sut.isRunning)
        XCTAssertEqual(sut.discardedFrameCount, 0)
    }
}
