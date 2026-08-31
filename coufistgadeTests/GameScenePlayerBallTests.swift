//
//  GameScenePlayerBallTests.swift
//  coufistgadeTests
//
//  Phase 4 additions to the scene. Phase 3's scene tests live in GameSceneTests.
//

import XCTest
import SpriteKit
@testable import coufistgade

final class GameScenePlayerBallTests: XCTestCase {

    private let sceneSize = CGSize(width: 393, height: 852)
    private let deviceInsets = UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)

    private func makeSUT(
        insets: UIEdgeInsets = .zero
    ) -> (scene: GameScene, view: SKView) {
        let view = SKView(frame: CGRect(origin: .zero, size: sceneSize))
        let scene = GameScene(size: sceneSize)
        scene.scaleMode = .resizeFill
        scene.updatePlayableInsets(insets)
        view.presentScene(scene)
        return (scene, view)
    }

    private func playerBall(in scene: GameScene) -> BallNode? {
        scene.children.compactMap { $0 as? BallNode }.first { $0.kind == .player }
    }

    // MARK: - Existence

    func testSceneHasExactlyOnePlayerBall() {
        let (scene, _) = makeSUT()

        let players = scene.children
            .compactMap { $0 as? BallNode }
            .filter { $0.kind == .player }
        XCTAssertEqual(players.count, 1)
    }

    func testSceneSpawnsTheConfiguredNumberOfNormalBalls() {
        let (scene, _) = makeSUT(insets: deviceInsets)

        let normals = scene.children
            .compactMap { $0 as? BallNode }
            .filter { $0.kind == .normal }
        XCTAssertTrue(
            GameConfiguration.Ball.initialNormalCountRange.contains(normals.count),
            "Spawned \(normals.count), outside the configured range."
        )
    }

    // MARK: - Spawn placement

    func testBallSpawnsAtCentreOfPlayableArea() throws {
        let (scene, _) = makeSUT(insets: deviceInsets)
        let ball = try XCTUnwrap(playerBall(in: scene))
        let rect = scene.playableRect

        XCTAssertEqual(ball.position.x, rect.midX, accuracy: 0.5)
        XCTAssertEqual(ball.position.y, rect.midY, accuracy: 0.5)
    }

    func testBallSpawnsFullyInsideTheWalls() throws {
        let (scene, _) = makeSUT(insets: deviceInsets)
        let ball = try XCTUnwrap(playerBall(in: scene))

        let ballBounds = CGRect(
            x: ball.position.x - ball.physicalRadius,
            y: ball.position.y - ball.physicalRadius,
            width: ball.physicalRadius * 2,
            height: ball.physicalRadius * 2
        )
        XCTAssertTrue(scene.playableRect.contains(ballBounds))
    }

    func testBallSpawnsAtRestWithoutTheDebugFlag() throws {
        let (scene, _) = makeSUT()
        let body = try XCTUnwrap(playerBall(in: scene)?.physicsBody)

        // The launch impulse is opt-in scaffolding; default must be still.
        XCTAssertEqual(hypot(body.velocity.dx, body.velocity.dy), 0, accuracy: .ulpOfOne)
        XCTAssertEqual(body.angularVelocity, 0, accuracy: .ulpOfOne)
    }

    // MARK: - Containment when the playable area changes

    func testBallIsPulledInsideWhenPlayableAreaShrinks() throws {
        let (scene, _) = makeSUT()
        let ball = try XCTUnwrap(playerBall(in: scene))

        // Park the ball near the top edge, then shrink the area under it.
        ball.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height - 10)
        scene.updatePlayableInsets(UIEdgeInsets(top: 200, left: 0, bottom: 0, right: 0))

        let limits = scene.playableRect.insetBy(dx: ball.physicalRadius, dy: ball.physicalRadius)
        XCTAssertLessThanOrEqual(ball.position.y, limits.maxY)
        XCTAssertGreaterThanOrEqual(ball.position.y, limits.minY)
    }

    func testBallStaysPutWhenAlreadyInsideANewArea() throws {
        let (scene, _) = makeSUT()
        let ball = try XCTUnwrap(playerBall(in: scene))
        ball.position = CGPoint(x: 150, y: 400)

        scene.updatePlayableInsets(deviceInsets)

        XCTAssertEqual(ball.position, CGPoint(x: 150, y: 400))
    }

    func testBallSurvivesADegeneratePlayableArea() throws {
        let (scene, _) = makeSUT()
        let ball = try XCTUnwrap(playerBall(in: scene))

        // Insets larger than the scene: must not produce NaN or a stray position.
        scene.updatePlayableInsets(UIEdgeInsets(top: 900, left: 0, bottom: 900, right: 0))

        XCTAssertFalse(ball.position.x.isNaN)
        XCTAssertFalse(ball.position.y.isNaN)
    }

    // MARK: - Reset

    func testResetReturnsTheBallToCentreAndStopsIt() throws {
        let (scene, _) = makeSUT(insets: deviceInsets)
        let ball = try XCTUnwrap(playerBall(in: scene))
        ball.position = CGPoint(x: 20, y: 20)
        ball.physicsBody?.velocity = CGVector(dx: 500, dy: -300)
        ball.physicsBody?.angularVelocity = 4
        ball.zRotation = 1.2

        scene.resetPlayerBall()

        let rect = scene.playableRect
        XCTAssertEqual(ball.position.x, rect.midX, accuracy: 0.5)
        XCTAssertEqual(ball.position.y, rect.midY, accuracy: 0.5)
        XCTAssertEqual(hypot(ball.physicsBody!.velocity.dx, ball.physicsBody!.velocity.dy), 0,
                       accuracy: .ulpOfOne)
        XCTAssertEqual(ball.physicsBody!.angularVelocity, 0, accuracy: .ulpOfOne)
        XCTAssertEqual(ball.zRotation, 0, accuracy: .ulpOfOne)
    }

    // MARK: - Layering

    func testBallDrawsAboveTheBackground() throws {
        let (scene, _) = makeSUT()
        let ball = try XCTUnwrap(playerBall(in: scene))
        let background = try XCTUnwrap(scene.children.compactMap { $0 as? BackgroundNode }.first)

        XCTAssertGreaterThan(ball.zPosition, background.zPosition)
    }
}
