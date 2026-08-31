//
//  GameManagerTests.swift
//  coufistgadeTests
//

import XCTest
@testable import coufistgade

final class GameManagerTests: XCTestCase {

    private final class Spy: GameManagerDelegate {
        var states: [GameState] = []
        var remainingTimes: [Int] = []
        var finishCount = 0

        func gameManager(_ manager: GameManager, didChangeState state: GameState) {
            states.append(state)
        }
        func gameManager(_ manager: GameManager, didUpdateRemainingTime seconds: Int) {
            remainingTimes.append(seconds)
        }
        func gameManagerDidFinishRound(_ manager: GameManager) {
            finishCount += 1
        }
    }

    private let duration = GameConfiguration.Round.duration

    private func makeSUT() -> (GameManager, Spy) {
        let sut = GameManager()
        let spy = Spy()
        sut.delegate = spy
        return (sut, spy)
    }

    /// Runs the round forward by `seconds` of game time in 60Hz frames.
    private func run(
        _ sut: GameManager,
        seconds: TimeInterval,
        from start: TimeInterval = 1_000
    ) -> TimeInterval {
        var time = start
        sut.tick(to: time)
        let step = 1.0 / 60
        for _ in 0..<Int(seconds / step) {
            time += step
            sut.tick(to: time)
        }
        return time
    }

    // MARK: - State machine

    func testStartsIdle() {
        let (sut, _) = makeSUT()

        XCTAssertEqual(sut.state, .idle)
        XCTAssertFalse(sut.isPlaying)
    }

    func testStartBeginsPlaying() {
        let (sut, spy) = makeSUT()

        sut.start()

        XCTAssertEqual(sut.state, .playing)
        XCTAssertEqual(spy.states, [.playing])
    }

    func testPauseAndResumeRoundTrip() {
        let (sut, spy) = makeSUT()
        sut.start()

        sut.pause()
        XCTAssertEqual(sut.state, .paused)
        sut.resume()

        XCTAssertEqual(sut.state, .playing)
        XCTAssertEqual(spy.states, [.playing, .paused, .playing])
    }

    func testPausingAnIdleGameIsANoOp() {
        let (sut, spy) = makeSUT()

        // The app-lifecycle hook fires regardless of what the player was doing.
        sut.pause()

        XCTAssertEqual(sut.state, .idle)
        XCTAssertTrue(spy.states.isEmpty)
    }

    func testResumingAGameThatWasNeverPausedIsANoOp() {
        let (sut, _) = makeSUT()
        sut.start()

        sut.resume()

        XCTAssertEqual(sut.state, .playing)
    }

    func testPausingAFinishedRoundIsANoOp() {
        let (sut, _) = makeSUT()
        sut.start()
        sut.finish()

        // Otherwise backgrounding after the round would swap the result panel
        // for a pause panel.
        sut.pause()

        XCTAssertEqual(sut.state, .finished)
    }

    func testStateChangesAreReportedOnceEach() {
        let (sut, spy) = makeSUT()

        sut.start()
        sut.start()

        // A repeat transition to the same state is not a change.
        XCTAssertEqual(spy.states, [.playing])
    }

    func testAPausedRoundCanBeFinishedDirectly() {
        let (sut, spy) = makeSUT()
        sut.start()
        sut.pause()

        sut.finish()

        // Quitting from the pause panel has to be able to end the round.
        XCTAssertEqual(sut.state, .finished)
        XCTAssertEqual(spy.finishCount, 1)
    }

    func testFinishingAnIdleGameIsANoOp() {
        let (sut, spy) = makeSUT()

        sut.finish()

        XCTAssertEqual(sut.state, .idle)
        XCTAssertEqual(spy.finishCount, 0)
    }

    // MARK: - Round duration

    func testTheRoundLastsTheConfiguredDuration() {
        // GAMEPLAY §20.
        XCTAssertEqual(duration, 60)
    }

    func testTheRoundIsStillLiveJustBeforeTimeExpires() {
        let (sut, spy) = makeSUT()
        sut.start()

        run(sut, seconds: duration - 0.5)

        XCTAssertEqual(sut.state, .playing)
        XCTAssertEqual(spy.finishCount, 0)
    }

    func testTheRoundFinishesWhenTimeExpires() {
        let (sut, spy) = makeSUT()
        sut.start()

        run(sut, seconds: duration + 0.5)

        XCTAssertEqual(sut.state, .finished)
        XCTAssertEqual(spy.finishCount, 1)
    }

    func testFinishIsReportedExactlyOnceEvenIfFramesKeepArriving() {
        let (sut, spy) = makeSUT()
        sut.start()
        let end = run(sut, seconds: duration + 0.5)

        // The scene may deliver a few more frames before it pauses itself.
        var time = end
        for _ in 0..<30 {
            time += 1.0 / 60
            sut.tick(to: time)
        }

        XCTAssertEqual(spy.finishCount, 1)
    }

    func testPausedTimeDoesNotShortenTheRound() {
        let (sut, spy) = makeSUT()
        sut.start()
        var time = run(sut, seconds: 10)

        sut.pause()
        time += 300
        sut.tick(to: time)
        sut.resume()
        run(sut, seconds: 10, from: time)

        // Twenty seconds played across a five-minute pause: still mid-round.
        XCTAssertEqual(sut.state, .playing)
        XCTAssertEqual(spy.finishCount, 0)
        XCTAssertEqual(sut.elapsedTime, 20, accuracy: 0.5)
    }

    // MARK: - Remaining time

    func testRemainingTimeStartsAtTheFullDuration() {
        let (sut, _) = makeSUT()
        sut.start()

        XCTAssertEqual(sut.remainingTime, duration, accuracy: 0.001)
        XCTAssertEqual(sut.remainingSeconds, Int(duration))
    }

    func testRemainingTimeCountsDown() {
        let (sut, _) = makeSUT()
        sut.start()

        run(sut, seconds: 15)

        XCTAssertEqual(sut.remainingTime, duration - 15, accuracy: 0.5)
    }

    func testRemainingTimeNeverGoesNegative() {
        let (sut, _) = makeSUT()
        sut.start()

        run(sut, seconds: duration + 5)

        XCTAssertEqual(sut.remainingTime, 0)
        XCTAssertEqual(sut.remainingSeconds, 0)
    }

    func testRemainingSecondsRoundsUpSoTheLastSecondIsVisible() {
        let (sut, _) = makeSUT()
        sut.start()

        run(sut, seconds: duration - 0.4)

        // A truncating conversion would show 0 while the round was still live.
        XCTAssertEqual(sut.remainingSeconds, 1)
    }

    func testTimeIsReportedOncePerSecondNotOncePerFrame() {
        let (sut, spy) = makeSUT()
        sut.start()

        run(sut, seconds: 5)

        // 5s at 60Hz is ~300 frames. ARCHITECTURE §23 forbids per-frame UIKid
        // updates, so the HUD must be pushed on the whole-second change only.
        XCTAssertLessThanOrEqual(spy.remainingTimes.count, 8)
        XCTAssertGreaterThanOrEqual(spy.remainingTimes.count, 5)
    }

    func testReportedSecondsDescendWithoutRepeats() {
        let (sut, spy) = makeSUT()
        sut.start()

        run(sut, seconds: 5)

        XCTAssertEqual(spy.remainingTimes, spy.remainingTimes.sorted(by: >))
        XCTAssertEqual(Set(spy.remainingTimes).count, spy.remainingTimes.count)
    }

    func testNoTimeIsReportedWhilePaused() {
        let (sut, spy) = makeSUT()
        sut.start()
        var time = run(sut, seconds: 3)
        let reportedBefore = spy.remainingTimes.count

        sut.pause()
        for _ in 0..<120 {
            time += 1.0 / 60
            sut.tick(to: time)
        }

        XCTAssertEqual(spy.remainingTimes.count, reportedBefore)
    }

    // MARK: - Restart

    func testStartingAgainGivesAFullRound() {
        let (sut, _) = makeSUT()
        sut.start()
        run(sut, seconds: 30)

        sut.start()

        // Play Again is the same call (GAMEPLAY §23).
        XCTAssertEqual(sut.remainingTime, duration, accuracy: 0.001)
        XCTAssertEqual(sut.state, .playing)
    }

    func testAFinishedRoundCanBeRestarted() {
        let (sut, spy) = makeSUT()
        sut.start()
        run(sut, seconds: duration + 1)
        XCTAssertEqual(sut.state, .finished)

        sut.start()

        XCTAssertEqual(sut.state, .playing)
        XCTAssertEqual(sut.remainingSeconds, Int(duration))
        XCTAssertEqual(spy.states, [.playing, .finished, .playing])
    }

    func testResetReturnsToIdle() {
        let (sut, _) = makeSUT()
        sut.start()
        run(sut, seconds: 10)

        sut.reset()

        XCTAssertEqual(sut.state, .idle)
        XCTAssertEqual(sut.elapsedTime, 0)
    }

    // MARK: - Long interruption

    func testALongBackgroundWithoutPauseDoesNotEndTheRound() {
        let (sut, spy) = makeSUT()
        sut.start()
        var time = run(sut, seconds: 5)

        // No pause call — the clock's own delta guard is the only protection.
        time += 600
        sut.tick(to: time)

        XCTAssertEqual(sut.state, .playing, "Ten minutes away consumed the round.")
        XCTAssertEqual(spy.finishCount, 0)
        XCTAssertEqual(sut.discardedFrameCount, 1)
    }
}
