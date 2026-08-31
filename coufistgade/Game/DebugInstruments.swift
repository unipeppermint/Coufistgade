//
//  DebugInstruments.swift
//  coufistgade
//
//  Gathers the DEBUG-only scaffolding that used to sit in GameScene: the speed
//  overlay, the collision log, and the launch shove.
//
//  Extracted because none of it is game logic, and it was crowding out the part
//  of the scene that is. One type also means one place where a new instrument
//  gets added and one call site to leave alone in future phases.
//
//  In release every flag is false, so each attach/handle call is a nil check on
//  an instrument that was never built.
//

import SpriteKit

final class DebugInstruments {

    private lazy var speedTracker: BallSpeedTracker? =
        DebugOptions.trackBallSpeed ? BallSpeedTracker() : nil
    private lazy var collisionReporter: CollisionReporter? =
        DebugOptions.logCollisions ? CollisionReporter() : nil

    /// Adds whichever overlays are switched on to the scene.
    func attach(to scene: SKScene) {
        speedTracker.map { scene.addChild($0) }
        collisionReporter.map { scene.addChild($0) }
    }

    func sample(body: SKPhysicsBody?, at time: TimeInterval) {
        speedTracker?.sample(body: body, at: time)
    }

    func report(_ collision: BallCollision) {
        collisionReporter?.report(collision)
    }

    /// An off-axis shove so the ball reaches several walls without input.
    ///
    /// Still useful after Phase 5: touch cannot be automated in the simulator,
    /// so this is the only way to drive the game from a script.
    func launchIfRequested(_ ball: BallNode) {
        guard DebugOptions.launchBall else { return }
        let speed = DebugOptions.launchBallSpeed
        // 30° above horizontal, so it hits a side wall before the top.
        ball.physicsBody?.velocity = CGVector(
            dx: speed * cos(.pi / 6),
            dy: speed * sin(.pi / 6)
        )
    }
}
