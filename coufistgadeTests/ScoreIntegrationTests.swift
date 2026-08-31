//
//  ScoreIntegrationTests.swift
//  coufistgadeTests
//
//  Proves the whole chain: physics contact → CollisionManager → ScoreManager →
//  GameSceneDelegate → HUD. Every link is unit-tested in isolation; this is the
//  only place the wiring between them is checked.
//

import XCTest
import SpriteKit
@testable import coufistgade

final class ScoreIntegrationTests: XCTestCase {


    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    private func run(until isDone: () -> Bool, timeout: TimeInterval = 3) {
        let deadline = Date().addingTimeInterval(timeout)
        while !isDone(), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
    }

    // MARK: - Scene → delegate

    func testAScoringCollisionReachesTheDelegate() throws {
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
        scene.startNewRound()

        // The scene spawns its own randomly-placed field, so rather than aim at
        // a particular ball, throw the player ball hard and let it find one.
        let player = try XCTUnwrap(
            scene.children.compactMap { $0 as? BallNode }.first { $0.kind == .player }
        )
        player.physicsBody?.velocity = CGVector(dx: 1500, dy: 900)

        run(until: { !spy.scores.isEmpty }, timeout: 5)

        let event = try XCTUnwrap(spy.scores.first, "No score reached the delegate.")
        XCTAssertEqual(event.points, GameConfiguration.Score.base)
        XCTAssertEqual(event.total, GameConfiguration.Score.base)
        // Against the running sum, not the first event's total: the poll loop
        // stops at the first score, and further collisions land before this line
        // runs, so comparing to a stale snapshot was a race.
        XCTAssertEqual(scene.score, spy.scores.map(\.points).reduce(0, +))
    }

    func testTheSceneTotalMatchesTheSumOfWhatItReported() throws {
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
        scene.startNewRound()

        let player = try XCTUnwrap(
            scene.children.compactMap { $0 as? BallNode }.first { $0.kind == .player }
        )
        player.physicsBody?.velocity = CGVector(dx: 1600, dy: 1100)

        run(until: { spy.scores.count >= 3 }, timeout: 6)

        XCTAssertGreaterThanOrEqual(spy.scores.count, 1)
        // A dropped or double-counted event would show up as a mismatch here.
        XCTAssertEqual(scene.score, spy.scores.map(\.points).reduce(0, +))
        XCTAssertEqual(scene.score, spy.scores.last?.total)
        print("MEASURED events=\(spy.scores.count) score=\(scene.score)")
    }

    func testResettingTheScoreClearsTheRunningTotal() {
        let size = CGSize(width: 393, height: 852)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        let scene = GameScene(size: size)
        view.presentScene(scene)

        scene.startNewRound()

        XCTAssertEqual(scene.score, 0)
    }

    // MARK: - Controller wiring

    func testGameViewControllerInstallsItselfAsTheSceneDelegate() {
        let sut = GameViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = sut
        window.makeKeyAndVisible()
        self.window = window

        sut.view.layoutIfNeeded()

        let scene = sut.view.subviews.compactMap { ($0 as? SKView)?.scene as? GameScene }.first
        XCTAssertIdentical(scene?.gameDelegate as? GameViewController, sut)
    }

    func testTheHUDShowsAScoreThatArrivesFromTheScene() throws {
        let sut = GameViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = sut
        window.makeKeyAndVisible()
        self.window = window
        sut.view.layoutIfNeeded()

        let scene = try XCTUnwrap(
            sut.view.subviews.compactMap { ($0 as? SKView)?.scene as? GameScene }.first
        )
        // Delivered through the protocol, exactly as a real collision would.
        sut.gameScene(scene, didScore: ScoreEvent(points: 10, total: 70, multiplier: 1))

        let label = sut.view
            .compactMap { $0 as? ScoreHUDView }
            .first
        XCTAssertNotNil(label, "No score HUD in the view hierarchy.")
        XCTAssertEqual(label?.displayedScoreText, "70")
    }
}

private extension UIView {
    /// Depth-first search for a subview of a given type.
    func compactMap<T: UIView>(_ transform: (UIView) -> T?) -> [T] {
        var found: [T] = []
        for subview in subviews {
            if let match = transform(subview) { found.append(match) }
            found.append(contentsOf: subview.compactMap(transform))
        }
        return found
    }
}
