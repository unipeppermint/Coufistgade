//
//  CollisionIntegrationTests.swift
//  coufistgadeTests
//
//  The only way to exercise the contact path end to end: SKPhysicsContact has
//  no public initialiser, so a real physics world has to produce one.
//
//  These drive the run loop rather than stepping the simulation, because
//  SpriteKit exposes no manual step. Timings are therefore approximate and the
//  assertions are deliberately about behaviour and order of magnitude, not
//  exact numbers.
//

import XCTest
import SpriteKit
@testable import coufistgade

final class CollisionIntegrationTests: XCTestCase {

    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    /// A scene with two balls on a collision course along the x axis.
    ///
    /// A bare SKScene, not GameScene: this is about the contact pipeline, and a
    /// hand-placed pair is far easier to reason about than randomised spawns.
    private func makeCollisionCourse(
        playerSpeed: CGFloat,
        offsetY: CGFloat = 0
    ) -> (scene: SKScene, manager: CollisionManager, player: BallNode, normal: BallNode) {
        let size = CGSize(width: 400, height: 400)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        let window = UIWindow(frame: view.frame)
        window.addSubview(view)
        window.isHidden = false
        window.makeKeyAndVisible()
        self.window = window

        let scene = SKScene(size: size)
        scene.scaleMode = .resizeFill
        scene.physicsWorld.gravity = .zero

        let manager = CollisionManager()
        scene.physicsWorld.contactDelegate = manager

        let player = BallNode(kind: .player)
        player.position = CGPoint(x: 80, y: 200)
        let normal = BallNode(kind: .normal)
        normal.position = CGPoint(x: 300, y: 200 + offsetY)

        scene.addChild(player)
        scene.addChild(normal)
        view.presentScene(scene)

        player.physicsBody?.velocity = CGVector(dx: playerSpeed, dy: 0)
        normal.physicsBody?.velocity = .zero

        return (scene, manager, player, normal)
    }

    /// Spins the main run loop so the view's display link can step physics.
    private func run(until isDone: () -> Bool, timeout: TimeInterval = 3) {
        let deadline = Date().addingTimeInterval(timeout)
        while !isDone(), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
    }

    // MARK: - The pipeline

    func testPlayerHittingANormalBallProducesAGradedEvent() throws {
        let course = makeCollisionCourse(playerSpeed: 800)
        var captured: [BallCollision] = []
        course.manager.onBallCollision = { captured.append($0) }

        run(until: { !captured.isEmpty })

        let collision = try XCTUnwrap(captured.first, "No contact was ever reported.")
        XCTAssertIdentical(collision.playerBall, course.player)
        XCTAssertIdentical(collision.normalBall, course.normal)
        XCTAssertGreaterThan(collision.impactSpeed, 0)

        // Recorded so the thresholds can be set from real numbers rather than
        // guesses, and so a change in how SpriteKit reports velocities shows up.
        print("MEASURED launch=800 impactSpeed=\(collision.impactSpeed) tier=\(collision.intensity)")
    }

    func testImpactSpeedTracksHowHardTheBallWasThrown() throws {
        var speeds: [CGFloat] = []

        for launch in [200, 600, 1400] as [CGFloat] {
            let course = makeCollisionCourse(playerSpeed: launch)
            var captured: BallCollision?
            course.manager.onBallCollision = { if captured == nil { captured = $0 } }

            run(until: { captured != nil })

            let collision = try XCTUnwrap(captured, "No contact at launch speed \(launch).")
            speeds.append(collision.impactSpeed)
            print("MEASURED launch=\(launch) impactSpeed=\(collision.impactSpeed) tier=\(collision.intensity)")
            tearDown()
        }

        // The grading is only meaningful if it is monotonic in throw strength.
        XCTAssertEqual(speeds, speeds.sorted(), "Harder throws did not report harder impacts.")
        XCTAssertGreaterThan(speeds.last! / speeds.first!, 2, "Grading barely responds to input.")
    }

    func testOneHitDoesNotFloodTheEventStream() throws {
        let course = makeCollisionCourse(playerSpeed: 500)
        var captured: [BallCollision] = []
        var frames = 0
        course.manager.onBallCollision = { captured.append($0) }

        // Advance the manager's clock the way GameScene does, so the cooldown
        // is exercised rather than frozen.
        let start = Date()
        run(until: {
            frames += 1
            course.manager.currentTime = Date().timeIntervalSince(start)
            return false
        }, timeout: 1.5)

        XCTAssertGreaterThan(frames, 30, "The run loop never advanced; test is vacuous.")
        XCTAssertFalse(captured.isEmpty, "The balls never met.")
        // Without the cooldown a resting pair emits once per frame.
        XCTAssertLessThan(captured.count, 12, "Contact events are firing far too often.")
        print("MEASURED events=\(captured.count) over \(frames) frames")
    }

    func testWallBouncesAreNeverReportedAsCollisions() {
        let size = CGSize(width: 400, height: 400)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        let window = UIWindow(frame: view.frame)
        window.addSubview(view)
        window.makeKeyAndVisible()
        self.window = window

        let scene = SKScene(size: size)
        scene.physicsWorld.gravity = .zero
        let manager = CollisionManager()
        scene.physicsWorld.contactDelegate = manager

        let boundary = BoundaryNode()
        boundary.enclose(CGRect(origin: .zero, size: size))
        scene.addChild(boundary)

        // Player ball alone, fired at a wall. Nothing here is a scoring event.
        let player = BallNode(kind: .player)
        player.position = CGPoint(x: 200, y: 200)
        scene.addChild(player)
        view.presentScene(scene)
        player.physicsBody?.velocity = CGVector(dx: 900, dy: 300)

        var captured: [BallCollision] = []
        manager.onBallCollision = { captured.append($0) }

        run(until: { false }, timeout: 1.5)

        XCTAssertTrue(captured.isEmpty, "A wall bounce reached the scoring path.")
    }

    // MARK: - Scene wiring

    func testGameSceneInstallsAContactDelegate() {
        let size = CGSize(width: 393, height: 852)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        let scene = GameScene(size: size)
        view.presentScene(scene)

        // physicsWorld.contactDelegate is weak, so this also proves the scene
        // holds the manager strongly — a local would already be gone.
        XCTAssertTrue(scene.physicsWorld.contactDelegate is CollisionManager)
    }
}
