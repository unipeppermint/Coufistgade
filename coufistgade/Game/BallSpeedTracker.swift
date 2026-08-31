//
//  BallSpeedTracker.swift
//  coufistgade
//
//  Debug instrument for the GAMEPLAY §8 open issue: with zero gravity plus
//  linearDamping and restitution below 1, how quickly does a ball bleed off
//  energy, and how much does a wall bounce cost?
//
//  Deliberately an SKLabelNode inside the scene rather than a UIKit label:
//  speed changes every frame, and ARCHITECTURE §23 forbids refreshing UIKit
//  per frame. It is the same rule that keeps the HUD out of GameScene.
//

import SpriteKit
import os

final class BallSpeedTracker: SKLabelNode {

    private static let logger = Logger(subsystem: "com.cclv.coufistgade", category: "BallSpeed")
    private static let logInterval: TimeInterval = 1.0
    /// Below this a ball reads as stationary to the player.
    private static let stillThreshold: CGFloat = 5

    private var startTime: TimeInterval?
    private var lastLogTime: TimeInterval?
    private var lastVelocity: CGVector?
    private var hasReportedStop = false

    override init() {
        super.init()
        fontName = "Menlo"
        fontSize = 12
        fontColor = UIColor(resource: .textSecondary)
        horizontalAlignmentMode = .left
        verticalAlignmentMode = .bottom
        position = CGPoint(x: 12, y: 60)
        zPosition = 1000
        text = "speed —"
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("BallSpeedTracker is code-only.")
    }

    func sample(body: SKPhysicsBody?, at time: TimeInterval) {
        guard let body else { return }

        let velocity = body.velocity
        let speed = hypot(velocity.dx, velocity.dy)
        let start = startTime ?? time
        if startTime == nil { startTime = time }
        let elapsed = time - start

        text = String(format: "speed %.0f pt/s   t %.1fs", speed, elapsed)

        detectBounce(previous: lastVelocity, current: velocity, speed: speed, elapsed: elapsed)
        lastVelocity = velocity

        logPeriodically(speed: speed, elapsed: elapsed, at: time)
        reportStopIfNeeded(speed: speed, elapsed: elapsed)
    }

    /// A wall bounce shows up as a sign flip on one axis; the speed ratio
    /// across it is the energy the collision cost.
    private func detectBounce(
        previous: CGVector?,
        current: CGVector,
        speed: CGFloat,
        elapsed: TimeInterval
    ) {
        guard let previous else { return }
        let flippedX = previous.dx * current.dx < 0
        let flippedY = previous.dy * current.dy < 0
        guard flippedX || flippedY else { return }

        let previousSpeed = hypot(previous.dx, previous.dy)
        guard previousSpeed > Self.stillThreshold else { return }

        let retained = speed / previousSpeed
        Self.logger.info(
            """
            BOUNCE t=\(elapsed, format: .fixed(precision: 2))s \
            axis=\(flippedX ? "x" : "y", privacy: .public) \
            before=\(previousSpeed, format: .fixed(precision: 1)) \
            after=\(speed, format: .fixed(precision: 1)) \
            retained=\(retained, format: .fixed(precision: 3))
            """
        )
    }

    private func logPeriodically(speed: CGFloat, elapsed: TimeInterval, at time: TimeInterval) {
        guard time - (lastLogTime ?? -.infinity) >= Self.logInterval else { return }
        lastLogTime = time
        Self.logger.info(
            "SAMPLE t=\(elapsed, format: .fixed(precision: 1))s speed=\(speed, format: .fixed(precision: 1))"
        )
    }

    private func reportStopIfNeeded(speed: CGFloat, elapsed: TimeInterval) {
        guard !hasReportedStop, speed < Self.stillThreshold, elapsed > 0.5 else { return }
        hasReportedStop = true
        Self.logger.info(
            "STOPPED t=\(elapsed, format: .fixed(precision: 2))s (below \(Self.stillThreshold) pt/s)"
        )
    }
}
