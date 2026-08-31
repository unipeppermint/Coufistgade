//
//  BallDragControllerTests.swift
//  coufistgadeTests
//

import XCTest
import SpriteKit
@testable import coufistgade

final class BallDragControllerTests: XCTestCase {

    private var ball: BallNode!
    private var sut: BallDragController!
    /// Stand-ins for UITouch, which cannot be constructed in a test.
    private var fingerA: NSObject!
    private var fingerB: NSObject!

    override func setUp() {
        super.setUp()
        ball = BallNode(kind: .player)
        ball.position = CGPoint(x: 200, y: 400)
        sut = BallDragController(ball: ball)
        fingerA = NSObject()
        fingerB = NSObject()
    }

    override func tearDown() {
        ball = nil; sut = nil; fingerA = nil; fingerB = nil
        super.tearDown()
    }

    private var touchA: ObjectIdentifier { ObjectIdentifier(fingerA) }
    private var touchB: ObjectIdentifier { ObjectIdentifier(fingerB) }

    private var ballSpeed: CGFloat {
        let v = ball.physicsBody!.velocity
        return hypot(v.dx, v.dy)
    }

    // MARK: - Grabbing

    func testTouchOnTheBallStartsADrag() {
        let began = sut.begin(touch: touchA, at: ball.position, time: 0)

        XCTAssertTrue(began)
        XCTAssertTrue(sut.isDragging)
    }

    func testTouchWithinGrabPaddingStartsADrag() {
        let justInside = ball.physicalRadius + GameConfiguration.Input.grabPadding - 1
        let point = CGPoint(x: ball.position.x + justInside, y: ball.position.y)

        XCTAssertTrue(sut.begin(touch: touchA, at: point, time: 0))
    }

    func testTouchBeyondGrabPaddingIsIgnored() {
        let justOutside = ball.physicalRadius + GameConfiguration.Input.grabPadding + 2
        let point = CGPoint(x: ball.position.x + justOutside, y: ball.position.y)

        XCTAssertFalse(sut.begin(touch: touchA, at: point, time: 0))
        XCTAssertFalse(sut.isDragging)
    }

    func testTouchFarAwayIsIgnored() {
        XCTAssertFalse(sut.begin(touch: touchA, at: CGPoint(x: 10, y: 10), time: 0))
    }

    // MARK: - Multi-touch

    func testSecondFingerCannotStealAnActiveDrag() {
        sut.begin(touch: touchA, at: ball.position, time: 0)

        let stolen = sut.begin(touch: touchB, at: ball.position, time: 0.1)

        XCTAssertFalse(stolen, "A second finger must not take over the ball.")
    }

    func testMovesFromOtherFingersAreIgnored() {
        sut.begin(touch: touchA, at: ball.position, time: 0)
        let originalTarget = ball.position

        sut.move(touch: touchB, to: CGPoint(x: 50, y: 50), time: 0.1)
        sut.update()

        // Steering toward the intruder's point would send it far off.
        let v = ball.physicsBody!.velocity
        let gapToOriginal = hypot(
            originalTarget.x - ball.position.x,
            originalTarget.y - ball.position.y
        )
        XCTAssertLessThan(gapToOriginal, 1)
        XCTAssertEqual(hypot(v.dx, v.dy), 0, accuracy: 1)
    }

    func testReleaseFromAnotherFingerDoesNotThrow() {
        sut.begin(touch: touchA, at: ball.position, time: 0)
        sut.move(touch: touchA, to: CGPoint(x: 260, y: 400), time: 0.016)

        sut.end(touch: touchB, at: CGPoint(x: 400, y: 400), time: 0.032)

        XCTAssertTrue(sut.isDragging, "The real finger is still down.")
        XCTAssertEqual(ballSpeed, 0, accuracy: 1)
    }

    // MARK: - Steering

    func testBallIsSteeredTowardTheFinger() {
        sut.begin(touch: touchA, at: ball.position, time: 0)
        sut.move(touch: touchA, to: CGPoint(x: ball.position.x + 50, y: ball.position.y), time: 0.02)

        sut.update()

        let v = ball.physicsBody!.velocity
        XCTAssertGreaterThan(v.dx, 0, "Should chase the finger to the right.")
        XCTAssertEqual(v.dy, 0, accuracy: 1)
    }

    func testSteeringSpeedIsCappedSoTheBallCannotTunnel() {
        sut.begin(touch: touchA, at: ball.position, time: 0)
        // A finger that teleports across the screen.
        sut.move(touch: touchA, to: CGPoint(x: ball.position.x + 5000, y: ball.position.y), time: 0.016)

        sut.update()

        XCTAssertLessThanOrEqual(
            ballSpeed,
            GameConfiguration.Input.dragMaxFollowSpeed + 1
        )
    }

    func testNoSteeringWhenNotDragging() {
        ball.physicsBody?.velocity = CGVector(dx: 123, dy: 456)

        sut.update()

        // An idle controller must leave a free-flying ball alone.
        XCTAssertEqual(ball.physicsBody!.velocity.dx, 123, accuracy: 0.5)
        XCTAssertEqual(ball.physicsBody!.velocity.dy, 456, accuracy: 0.5)
    }

    // MARK: - Release

    func testFlickReleaseThrowsTheBall() {
        sut.begin(touch: touchA, at: ball.position, time: 0)
        var t = 0.0
        for i in 1...4 {
            t = Double(i) / 60.0
            sut.move(touch: touchA, to: CGPoint(x: ball.position.x + Double(i) * 25, y: 400), time: t)
        }

        sut.end(touch: touchA, at: CGPoint(x: ball.position.x + 125, y: 400), time: t + 1 / 60.0)

        XCTAssertFalse(sut.isDragging)
        XCTAssertGreaterThan(ballSpeed, GameConfiguration.Input.minimumThrowSpeed)
    }

    func testGentleReleaseDropsTheBallInsteadOfThrowingIt() {
        sut.begin(touch: touchA, at: ball.position, time: 0)
        // Barely moving: 2pt over 100ms.
        sut.move(touch: touchA, to: CGPoint(x: ball.position.x + 2, y: 400), time: 0.1)

        sut.end(touch: touchA, at: CGPoint(x: ball.position.x + 2, y: 400), time: 0.11)

        XCTAssertEqual(ballSpeed, 0, accuracy: 0.5, "Placing the ball must not launch it.")
    }

    func testThrowSpeedIsCapped() {
        sut.begin(touch: touchA, at: ball.position, time: 0)
        // An absurdly fast swipe.
        sut.move(touch: touchA, to: CGPoint(x: 5000, y: 400), time: 0.008)

        sut.end(touch: touchA, at: CGPoint(x: 9000, y: 400), time: 0.016)

        XCTAssertLessThanOrEqual(ballSpeed, GameConfiguration.Input.maximumThrowSpeed + 1)
    }

    func testReleaseEndsTheDragSoANewOneCanStart() {
        sut.begin(touch: touchA, at: ball.position, time: 0)
        sut.end(touch: touchA, at: ball.position, time: 0.1)

        XCTAssertTrue(sut.begin(touch: touchB, at: ball.position, time: 0.2))
    }

    // MARK: - Cancellation

    func testCancelStopsTheBallWithoutThrowing() {
        sut.begin(touch: touchA, at: ball.position, time: 0)
        for i in 1...4 {
            sut.move(touch: touchA, to: CGPoint(x: ball.position.x + Double(i) * 30, y: 400),
                     time: Double(i) / 60.0)
        }

        sut.cancel(touch: touchA)

        XCTAssertFalse(sut.isDragging)
        // An interrupted gesture never completed, so it must not throw.
        XCTAssertEqual(ballSpeed, 0, accuracy: 0.5)
    }

    func testCancelFromAnotherFingerIsIgnored() {
        sut.begin(touch: touchA, at: ball.position, time: 0)

        sut.cancel(touch: touchB)

        XCTAssertTrue(sut.isDragging)
    }

    // MARK: - Cross-gesture isolation

    func testPreviousGestureSamplesDoNotLeakIntoTheNextThrow() {
        // A fast drag, cancelled.
        sut.begin(touch: touchA, at: ball.position, time: 0)
        for i in 1...4 {
            sut.move(touch: touchA, to: CGPoint(x: ball.position.x + Double(i) * 40, y: 400),
                     time: Double(i) / 60.0)
        }
        sut.cancel(touch: touchA)

        // Then a deliberate, gentle placement.
        sut.begin(touch: touchB, at: ball.position, time: 1.0)
        sut.end(touch: touchB, at: ball.position, time: 1.1)

        XCTAssertEqual(ballSpeed, 0, accuracy: 0.5, "Stale samples leaked into a new gesture.")
    }
}
