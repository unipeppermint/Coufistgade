//
//  BallDragController.swift
//  coufistgade
//
//  Drag-and-release for the player ball (GAMEPLAY §6, §7).
//
//  Drives the ball through its physics body's velocity rather than by assigning
//  `position` directly. Setting position teleports the body past the solver:
//  contacts are missed and the ball walks through walls at speed. Steering by
//  velocity keeps every collision honest and produces the "slight physical lag"
//  GAMEPLAY §6 asks for as a natural consequence rather than a fudge.
//
//  Split out of GameScene so the scene stays an assembler (ARCHITECTURE §27).
//

import SpriteKit

final class BallDragController {

    private let ball: BallNode
    private var estimator = ThrowVelocityEstimator()

    /// The one touch allowed to steer the ball. A second finger is ignored
    /// rather than allowed to fight the first or steal the ball mid-throw.
    ///
    /// Identified by `ObjectIdentifier` rather than held as a `UITouch`: the
    /// controller only ever needs to know "same finger or not", and dropping the
    /// UIKit type makes the whole gesture state machine unit-testable.
    private var activeTouch: ObjectIdentifier?
    private var target: CGPoint = .zero

    var isDragging: Bool { activeTouch != nil }

    init(ball: BallNode) {
        self.ball = ball
    }

    // MARK: - Gesture lifecycle

    /// Returns true if the touch landed on the ball and the drag began.
    @discardableResult
    func begin(touch: ObjectIdentifier, at point: CGPoint, time: TimeInterval) -> Bool {
        guard activeTouch == nil, canGrab(at: point) else { return false }

        activeTouch = touch
        target = point
        estimator.reset()
        estimator.record(point: point, time: time)
        return true
    }

    func move(touch: ObjectIdentifier, to point: CGPoint, time: TimeInterval) {
        guard touch == activeTouch else { return }
        target = point
        estimator.record(point: point, time: time)
    }

    func end(touch: ObjectIdentifier, at point: CGPoint, time: TimeInterval) {
        guard touch == activeTouch else { return }
        activeTouch = nil

        let raw = estimator.velocity(releasePoint: point, releaseTime: time)
        ball.physicsBody?.velocity = ThrowVelocityEstimator.clamped(raw)
        estimator.reset()
    }

    /// A cancelled touch must not throw — the gesture never completed.
    func cancel(touch: ObjectIdentifier) {
        guard touch == activeTouch else { return }
        activeTouch = nil
        ball.physicsBody?.velocity = .zero
        estimator.reset()
    }

    // MARK: - Per-frame steering

    func update() {
        guard isDragging, let body = ball.physicsBody else { return }

        // Proportional controller: velocity proportional to the gap closes it
        // exponentially, so the ball trails the finger by a constant time rather
        // than snapping to it.
        let gap = CGVector(
            dx: target.x - ball.position.x,
            dy: target.y - ball.position.y
        )
        var desired = CGVector(
            dx: gap.dx * GameConfiguration.Input.dragFollowGain,
            dy: gap.dy * GameConfiguration.Input.dragFollowGain
        )

        // A finger that jumps far in one frame would otherwise command a speed
        // high enough to tunnel through the wall.
        let speed = hypot(desired.dx, desired.dy)
        if speed > GameConfiguration.Input.dragMaxFollowSpeed {
            let scale = GameConfiguration.Input.dragMaxFollowSpeed / speed
            desired = CGVector(dx: desired.dx * scale, dy: desired.dy * scale)
        }

        body.velocity = desired
    }

    // MARK: - Hit testing

    private func canGrab(at point: CGPoint) -> Bool {
        let reach = ball.physicalRadius + GameConfiguration.Input.grabPadding
        return hypot(point.x - ball.position.x, point.y - ball.position.y) <= reach
    }
}
