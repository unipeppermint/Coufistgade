//
//  RoundIntegrationTests.swift
//  coufistgadeTests
//
//  Whether pause and round-end actually hold once physics, the clock, the combo
//  window and the scene are all running together.
//

import XCTest
import SpriteKit
@testable import coufistgade

final class RoundIntegrationTests: XCTestCase {

    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    private func makeLiveScene() -> (GameScene, GameSceneDelegateSpy) {
        let size = CGSize(width: 393, height: 852)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        let window = UIWindow(frame: view.frame)
        window.addSubview(view)
        window.makeKeyAndVisible()
        self.window = window

        let scene = GameScene(size: size)
        scene.scaleMode = .resizeFill
        let spy = GameSceneDelegateSpy()
        scene.gameDelegate = spy
        view.presentScene(scene)
        return (scene, spy)
    }

    private func run(for duration: TimeInterval, until isDone: (() -> Bool)? = nil) {
        let deadline = Date().addingTimeInterval(duration)
        while Date() < deadline {
            if isDone?() == true { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
    }

    private func playerBall(in scene: SKScene) -> BallNode? {
        scene.children.compactMap { $0 as? BallNode }.first { $0.kind == .player }
    }

    // MARK: - Idle before the round starts

    func testNothingScoresBeforeTheRoundBegins() throws {
        let (scene, spy) = makeLiveScene()
        let player = try XCTUnwrap(playerBall(in: scene))

        // The world exists and physics runs, but the round has not started.
        player.physicsBody?.velocity = CGVector(dx: 1800, dy: 1300)
        run(for: 1.5)

        XCTAssertEqual(scene.gameManager.state, .idle)
        XCTAssertEqual(scene.score, 0)
        XCTAssertTrue(spy.scores.isEmpty)
    }

    // MARK: - Pause

    func testPauseStopsScoringAndResumeRestoresIt() throws {
        let (scene, spy) = makeLiveScene()
        scene.startNewRound()
        let player = try XCTUnwrap(playerBall(in: scene))
        player.physicsBody?.velocity = CGVector(dx: 1800, dy: 1300)
        run(for: 1.0, until: { !spy.scores.isEmpty })
        XCTAssertFalse(spy.scores.isEmpty, "Nothing scored before the pause.")

        scene.pauseRound()
        let scoresAtPause = spy.scores.count
        run(for: 1.2)

        XCTAssertEqual(scene.gameManager.state, .paused)
        XCTAssertEqual(spy.scores.count, scoresAtPause, "Scoring continued while paused.")

        scene.resumeRound()
        run(for: 1.0)

        XCTAssertEqual(scene.gameManager.state, .playing)
    }

    func testPauseFreezesTheRoundClock() {
        let (scene, _) = makeLiveScene()
        scene.startNewRound()
        run(for: 0.6)
        let elapsedAtPause = scene.gameManager.elapsedTime

        scene.pauseRound()
        run(for: 1.5)

        // GAMEPLAY §24: pause stops the game timer.
        XCTAssertEqual(scene.gameManager.elapsedTime, elapsedAtPause, accuracy: 0.05)
    }

    func testALongPauseDoesNotLapseALiveCombo() throws {
        let (scene, spy) = makeLiveScene()
        scene.startNewRound()
        let player = try XCTUnwrap(playerBall(in: scene))
        player.physicsBody?.velocity = CGVector(dx: 1800, dy: 1300)
        run(for: 2.0, until: { scene.comboCount >= 2 })
        let comboAtPause = scene.comboCount
        XCTAssertGreaterThanOrEqual(comboAtPause, 2, "No combo to protect.")

        scene.pauseRound()
        // Well past the 2s combo window in real time.
        run(for: GameConfiguration.Combo.window + 1.5)

        // This is the whole reason the combo runs on game time. With absolute
        // time the player would lose a 10x rally to a phone call.
        XCTAssertEqual(scene.comboCount, comboAtPause, "The pause cost the player their combo.")
        XCTAssertEqual(scene.gameManager.state, .paused)
        _ = spy
    }

    func testPausingIsIdempotent() {
        let (scene, spy) = makeLiveScene()
        scene.startNewRound()
        run(for: 0.3)

        scene.pauseRound()
        scene.pauseRound()
        scene.pauseRound()

        XCTAssertEqual(spy.states.filter { $0 == .paused }.count, 1)
    }

    // MARK: - Round end

    func testTheRoundEndsAndStopsTheWorld() throws {
        let (scene, spy) = makeLiveScene()
        scene.startNewRound()
        let player = try XCTUnwrap(playerBall(in: scene))
        player.physicsBody?.velocity = CGVector(dx: 1800, dy: 1300)
        run(for: 0.8, until: { !spy.scores.isEmpty })

        // Rather than wait 60s, end the round the way the timer does.
        scene.finishRound()
        let scoreAtEnd = scene.score
        let scoresAtEnd = spy.scores.count
        run(for: 1.2)

        XCTAssertEqual(scene.gameManager.state, .finished)
        XCTAssertEqual(spy.finishedRoundCount, 1)
        // GAMEPLAY §21: stop gameplay, stop scoring, stop combo.
        XCTAssertEqual(scene.score, scoreAtEnd, "Scoring continued after the round ended.")
        XCTAssertEqual(spy.scores.count, scoresAtEnd)
        XCTAssertTrue(scene.isPaused, "The world kept moving behind the result.")
    }

    func testTheFinalScoreSurvivesTheRoundEnding() throws {
        let (scene, spy) = makeLiveScene()
        scene.startNewRound()
        let player = try XCTUnwrap(playerBall(in: scene))
        player.physicsBody?.velocity = CGVector(dx: 1800, dy: 1300)
        run(for: 1.5, until: { spy.scores.count >= 2 })

        scene.finishRound()

        // Phase 12's result screen reads these after the round.
        XCTAssertGreaterThan(scene.score, 0)
        XCTAssertEqual(scene.score, spy.scores.map(\.points).reduce(0, +))
        XCTAssertGreaterThanOrEqual(scene.highestCombo, 1)
    }

    // MARK: - Restart

    func testPlayAgainClearsTheScoreAndTheClock() throws {
        let (scene, spy) = makeLiveScene()
        scene.startNewRound()
        let player = try XCTUnwrap(playerBall(in: scene))
        player.physicsBody?.velocity = CGVector(dx: 1800, dy: 1300)
        run(for: 1.5, until: { !spy.scores.isEmpty })
        scene.finishRound()
        XCTAssertGreaterThan(scene.score, 0)

        scene.startNewRound()

        XCTAssertEqual(scene.score, 0)
        XCTAssertEqual(scene.comboCount, 0)
        XCTAssertEqual(scene.highestCombo, 0)
        XCTAssertEqual(scene.gameManager.state, .playing)
        XCTAssertFalse(scene.isPaused, "The new round started frozen.")
    }

    func testPlayAgainRebuildsTheFieldToItsConfiguredSize() {
        let (scene, _) = makeLiveScene()
        scene.startNewRound()
        run(for: 0.3)

        scene.startNewRound()

        let normals = scene.children.compactMap { $0 as? BallNode }.filter { $0.kind == .normal }
        XCTAssertTrue(
            GameConfiguration.Ball.initialNormalCountRange.contains(normals.count),
            "Play Again left \(normals.count) balls on the field."
        )
    }

    func testPlayAgainRecentresThePlayerBall() throws {
        let (scene, _) = makeLiveScene()
        scene.startNewRound()
        let player = try XCTUnwrap(playerBall(in: scene))
        player.position = CGPoint(x: 20, y: 20)

        scene.startNewRound()

        XCTAssertEqual(player.position.x, scene.playableRect.midX, accuracy: 1)
        XCTAssertEqual(player.position.y, scene.playableRect.midY, accuracy: 1)
    }

    // MARK: - Time reporting

    func testTheHUDIsToldTheTimeOncePerSecond() {
        let (scene, spy) = makeLiveScene()
        scene.startNewRound()

        run(for: 2.5)

        // ~150 frames in 2.5s; the HUD should hear about 3 of them.
        XCTAssertLessThanOrEqual(spy.remainingTimes.count, 6)
        XCTAssertGreaterThanOrEqual(spy.remainingTimes.count, 2)
        XCTAssertEqual(spy.remainingTimes.first, Int(GameConfiguration.Round.duration))
    }
}
