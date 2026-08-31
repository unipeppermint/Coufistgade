//
//  QATests.swift
//  coufistgadeTests
//
//  ROADMAP Phase 19, the cases code can reach: fast drags, repeated taps,
//  multi-touch, edge dragging, and screen sizes.
//
//  Driven through BallDragController rather than UITouch, which cannot be
//  constructed — the controller takes an ObjectIdentifier precisely so these
//  paths are testable. Everything asserted here is an invariant a player could
//  break by accident.
//

import XCTest
import SpriteKit
@testable import coufistgade

final class QATests: XCTestCase {

    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        liveTouchObjects.removeAll()
        super.tearDown()
    }

    private func makeScene(
        size: CGSize = CGSize(width: 393, height: 852)
    ) -> (GameScene, BallNode) {
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        let window = UIWindow(frame: view.frame)
        window.addSubview(view)
        window.makeKeyAndVisible()
        self.window = window

        let scene = GameScene(size: size)
        scene.scaleMode = .resizeFill
        view.presentScene(scene)
        scene.startNewRound()
        let ball = scene.children
            .compactMap { $0 as? BallNode }
            .first { $0.kind == .player }!
        return (scene, ball)
    }

    /// Retains the objects it identifies.
    ///
    /// `ObjectIdentifier(NSObject())` alone is a trap: the object deallocates
    /// immediately, so the next allocation can reuse the address and yield an
    /// *equal* identifier — two "different fingers" that compare the same. This
    /// bit the multi-touch tests below before the objects were held.
    ///
    /// Real UITouch objects are retained by UIKit for the whole gesture, so the
    /// app cannot hit this. Same hazard noted in CollisionManager.accept.
    private var liveTouchObjects: [NSObject] = []

    private func touch() -> ObjectIdentifier {
        let object = NSObject()
        liveTouchObjects.append(object)
        return ObjectIdentifier(object)
    }

    private func speed(of ball: BallNode) -> CGFloat {
        let velocity = ball.physicsBody?.velocity ?? .zero
        return hypot(velocity.dx, velocity.dy)
    }

    private func step(_ controller: BallDragController, frames: Int = 1) {
        for _ in 0..<frames {
            controller.update()
            RunLoop.current.run(until: Date().addingTimeInterval(1.0 / 60))
        }
    }

    // MARK: - Fast drags

    func testAViolentFlickIsClampedRatherThanLaunchingTheBallThroughAWall() {
        let (_, ball) = makeScene()
        let controller = BallDragController(ball: ball)
        let start = ball.position
        let id = touch()

        // Far faster than a human flick: 6000 pt/s.
        _ = controller.begin(touch: id, at: start, time: 0)
        let dt = 1.0 / 60
        for i in 1...3 {
            controller.move(
                touch: id,
                to: CGPoint(x: start.x + 6000 * dt * CGFloat(i), y: start.y),
                time: dt * Double(i)
            )
        }
        controller.end(touch: id, at: CGPoint(x: start.x + 6000 * dt * 3, y: start.y), time: dt * 3)

        XCTAssertLessThanOrEqual(
            speed(of: ball),
            GameConfiguration.Input.maximumThrowSpeed + 1,
            "GAMEPLAY §7: unrealistic velocities must be clamped."
        )
    }

    func testAFingerTeleportingAcrossTheScreenDoesNotTunnelTheBall() {
        let (scene, ball) = makeScene()
        let controller = BallDragController(ball: ball)
        let id = touch()
        _ = controller.begin(touch: id, at: ball.position, time: 0)

        // A dropped touch stream can jump the full screen in one frame.
        controller.move(touch: id, to: CGPoint(x: 380, y: 830), time: 0.016)
        step(controller, frames: 4)

        XCTAssertLessThanOrEqual(
            speed(of: ball),
            GameConfiguration.Input.dragMaxFollowSpeed + 1,
            "The chase speed clamp did not hold."
        )
        // Still inside the walls, which is what the clamp exists to protect.
        XCTAssertTrue(
            scene.playableRect.insetBy(dx: -1, dy: -1).contains(ball.position),
            "The ball left the playable area: \(ball.position)"
        )
    }

    // MARK: - Repeated taps

    func testRepeatedTapsWithoutMovementDoNotThrowTheBall() {
        let (_, ball) = makeScene()
        let controller = BallDragController(ball: ball)

        // Twenty taps on the ball, no drag between them.
        for i in 0..<20 {
            let id = touch()
            let time = Double(i) * 0.05
            _ = controller.begin(touch: id, at: ball.position, time: time)
            controller.end(touch: id, at: ball.position, time: time + 0.01)
        }

        // Below the dead zone, so a tap places rather than throws — otherwise
        // tapping would fling the ball and the player could never simply hold it.
        XCTAssertLessThan(speed(of: ball), GameConfiguration.Input.minimumThrowSpeed)
    }

    func testRapidGrabAndReleaseLeavesNoStuckDragState() {
        let (_, ball) = makeScene()
        let controller = BallDragController(ball: ball)

        for i in 0..<10 {
            let id = touch()
            _ = controller.begin(touch: id, at: ball.position, time: Double(i) * 0.1)
            controller.end(touch: id, at: ball.position, time: Double(i) * 0.1 + 0.02)
        }

        // A leaked active touch would make the ball permanently ungrabbable.
        let fresh = touch()
        XCTAssertTrue(
            controller.begin(touch: fresh, at: ball.position, time: 100),
            "The controller is still holding a finished drag."
        )
    }

    // MARK: - Multi-touch

    func testASecondFingerCannotStealTheBallMidDrag() {
        let (_, ball) = makeScene()
        let controller = BallDragController(ball: ball)
        let first = touch()
        _ = controller.begin(touch: first, at: ball.position, time: 0)

        let second = touch()
        XCTAssertFalse(
            controller.begin(touch: second, at: ball.position, time: 0.1),
            "Two fingers can drag the same ball."
        )
    }

    func testABystanderFingerCannotThrowTheBall() {
        let (_, ball) = makeScene()
        let controller = BallDragController(ball: ball)
        let first = touch()
        _ = controller.begin(touch: first, at: ball.position, time: 0)
        controller.move(touch: first, to: CGPoint(x: ball.position.x + 20, y: ball.position.y), time: 0.05)

        // A second finger that was never granted the drag lifts. Acting on it
        // would throw the ball while the real finger is still down.
        let second = touch()
        controller.end(touch: second, at: CGPoint(x: 10, y: 10), time: 0.06)
        step(controller)

        XCTAssertTrue(controller.isDragging, "The bystander's release ended the real drag.")
    }

    func testReleasingTheRealFingerWhileASecondIsDownStillThrows() {
        let (_, ball) = makeScene()
        let controller = BallDragController(ball: ball)
        let first = touch()
        let start = ball.position
        _ = controller.begin(touch: first, at: start, time: 0)

        let second = touch()
        _ = controller.begin(touch: second, at: start, time: 0.01)

        // The owning finger flicks and lifts while the bystander is still down.
        let dt = 1.0 / 60
        for i in 1...3 {
            controller.move(
                touch: first,
                to: CGPoint(x: start.x + 900 * dt * CGFloat(i), y: start.y),
                time: dt * Double(i)
            )
        }
        controller.end(touch: first, at: CGPoint(x: start.x + 900 * dt * 3, y: start.y), time: dt * 3)

        XCTAssertGreaterThan(speed(of: ball), GameConfiguration.Input.minimumThrowSpeed)
        XCTAssertFalse(controller.isDragging)
    }

    func testAnInterruptedGestureDropsTheBallRatherThanThrowingIt() {
        let (_, ball) = makeScene()
        let controller = BallDragController(ball: ball)
        let id = touch()
        let start = ball.position
        _ = controller.begin(touch: id, at: start, time: 0)
        controller.move(touch: id, to: CGPoint(x: start.x + 200, y: start.y), time: 0.05)

        // A call arriving, or a system gesture taking over.
        controller.cancel(touch: id)
        step(controller)

        XCTAssertFalse(controller.isDragging)
        XCTAssertEqual(speed(of: ball), 0, accuracy: 1, "A cancelled gesture threw the ball.")
    }

    // MARK: - Edge dragging

    func testDraggingIntoACornerKeepsTheBallInside() {
        let (scene, ball) = makeScene()
        let controller = BallDragController(ball: ball)
        let id = touch()
        _ = controller.begin(touch: id, at: ball.position, time: 0)

        // Hold well outside the playable area, as a finger at the screen edge does.
        for corner in [CGPoint(x: -200, y: -200), CGPoint(x: 900, y: 1400)] {
            controller.move(touch: id, to: corner, time: 0.1)
            step(controller, frames: 30)

            let limits = scene.playableRect.insetBy(dx: -2, dy: -2)
            XCTAssertTrue(
                limits.contains(ball.position),
                "Dragging to \(corner) put the ball at \(ball.position)"
            )
        }
    }

    func testTheBallCannotBeGrabbedFromAcrossTheScreen() {
        let (_, ball) = makeScene()
        let controller = BallDragController(ball: ball)

        // Far outside the grab radius: a tap in open space must not teleport the
        // ball to the finger.
        let far = CGPoint(x: ball.position.x + 300, y: ball.position.y + 300)
        XCTAssertFalse(controller.begin(touch: touch(), at: far, time: 0))
    }

    // MARK: - Screen sizes

    func testTheGameFitsEveryShippingIPhoneSize() {
        // Smallest and largest in the current lineup, plus the SE-class 4.7".
        let sizes: [(String, CGSize)] = [
            ("SE 4.7\"", CGSize(width: 375, height: 667)),
            ("13 mini", CGSize(width: 375, height: 812)),
            ("16 Pro", CGSize(width: 402, height: 874)),
            ("16 Pro Max", CGSize(width: 440, height: 956)),
        ]

        for (name, size) in sizes {
            let (scene, ball) = makeScene(size: size)

            XCTAssertGreaterThan(scene.playableRect.width, 0, "\(name): no playable width")
            XCTAssertGreaterThan(scene.playableRect.height, 0, "\(name): no playable height")
            // The ball must fit with room to move, not merely exist.
            XCTAssertGreaterThan(
                scene.playableRect.width / ball.physicalRadius, 4,
                "\(name): playable area is too narrow for the ball"
            )
            let normals = scene.children.compactMap { $0 as? BallNode }.filter { $0.kind == .normal }
            XCTAssertTrue(
                GameConfiguration.Ball.initialNormalCountRange.contains(normals.count),
                "\(name): spawned \(normals.count) balls"
            )
            tearDown()
        }
    }

    func testTheHUDNeverEatsMoreThanAQuarterOfTheSmallestScreen() {
        // The playable area is what is left after the HUD. On the smallest phone
        // this is where a cramped layout would show up first.
        let size = CGSize(width: 375, height: 667)
        let controller = GameViewController()
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        self.window = window
        controller.view.layoutIfNeeded()

        let scene = controller.view.subviews
            .compactMap { ($0 as? SKView)?.scene as? GameScene }
            .first
        let playable = try? XCTUnwrap(scene?.playableRect)
        let fraction = (playable?.height ?? 0) / size.height

        XCTAssertGreaterThan(fraction, 0.75, "The HUD is crowding the playfield: \(fraction)")
    }

    // MARK: - Appearance

    func testTheAppIsPinnedToDarkAppearance() {
        // UI_DESIGN §3 names dark as the primary mode and defers light
        // ("eventually", and explicitly not an inversion). Every colour asset has
        // a single variant, so an inherited light appearance would render the app
        // with dark-mode colours against a system-light chrome.
        //
        // This pins the deliberate choice. When light mode is designed, this test
        // is the reminder that the assets need light variants first.
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let window = scene?.windows.first

        if let window {
            XCTAssertEqual(window.overrideUserInterfaceStyle, .dark)
        }
    }
}
