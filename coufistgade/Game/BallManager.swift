//
//  BallManager.swift
//  coufistgade
//
//  Spawns and tracks the normal balls (ARCHITECTURE §12).
//
//  Placement uses best-of-N rejection sampling: try several random points,
//  score each by how far it sits from every existing ball, keep the best. That
//  satisfies GAMEPLAY §2 ("without severe overlap") and §18 ("not directly on
//  top of the player") while always producing the requested count — a strict
//  reject-and-fail loop could quietly spawn fewer balls on a crowded field.
//

import SpriteKit

final class BallManager {

    /// The node new balls are added to. Held weakly-by-design as a plain
    /// reference to the scene's container, which outlives this manager.
    private unowned let container: SKNode

    private(set) var normalBalls: [BallNode] = []

    var count: Int { normalBalls.count }

    init(container: SKNode) {
        self.container = container
    }

    // MARK: - Spawning

    /// Fills the field with GAMEPLAY §5's initial 5–8 balls.
    func spawnInitialBalls(in rect: CGRect, avoiding player: BallNode) {
        removeAll()

        let target = Int.random(in: GameConfiguration.Ball.initialNormalCountRange)
        for _ in 0..<target {
            spawnOne(in: rect, avoiding: player)
        }
    }


    @discardableResult
    func spawnOne(in rect: CGRect, avoiding player: BallNode) -> BallNode? {
        guard normalBalls.count < GameConfiguration.Ball.maximumNormalCount else { return nil }

        let ball = BallNode(kind: .normal)
        let field = rect.insetBy(dx: ball.physicalRadius, dy: ball.physicalRadius)
        guard field.width > 0, field.height > 0 else { return nil }

        ball.position = bestSpawnPoint(in: field, radius: ball.physicalRadius, player: player)
        ball.physicsBody?.velocity = Self.randomDrift()

        container.addChild(ball)
        normalBalls.append(ball)
        return ball
    }

    // MARK: - Removal

    func remove(_ ball: BallNode) {
        ball.removeFromParent()
        normalBalls.removeAll { $0 === ball }
    }

    func removeAll() {
        normalBalls.forEach { $0.removeFromParent() }
        normalBalls.removeAll()
    }

    /// Pulls every ball back inside after the playable area changes.
    func containAll(in rect: CGRect) {
        normalBalls.forEach { $0.contain(in: rect) }
    }

    // MARK: - Placement

    /// Best of N random candidates, scored by distance to the nearest obstacle.
    private func bestSpawnPoint(in field: CGRect, radius: CGFloat, player: BallNode) -> CGPoint {
        var best = CGPoint(x: field.midX, y: field.midY)
        var bestClearance = -CGFloat.greatestFiniteMagnitude

        for _ in 0..<GameConfiguration.Ball.spawnAttempts {
            let candidate = CGPoint(
                x: .random(in: field.minX...field.maxX),
                y: .random(in: field.minY...field.maxY)
            )
            let clearance = self.clearance(at: candidate, radius: radius, player: player)

            // Good enough: stop as soon as a candidate clears every obstacle.
            if clearance >= 0 {
                return candidate
            }
            if clearance > bestClearance {
                bestClearance = clearance
                best = candidate
            }
        }
        return best
    }

    /// Slack in points between this candidate and its nearest neighbour.
    /// Negative means it would overlap something.
    private func clearance(at point: CGPoint, radius: CGFloat, player: BallNode) -> CGFloat {
        var worst = CGFloat.greatestFiniteMagnitude

        let playerNeeded = radius + player.physicalRadius
            + GameConfiguration.Ball.spawnClearanceFromPlayer
        worst = min(worst, distance(point, player.position) - playerNeeded)

        for other in normalBalls {
            let needed = radius + other.physicalRadius + GameConfiguration.Ball.spawnSeparation
            worst = min(worst, distance(point, other.position) - needed)
        }
        return worst
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private static func randomDrift() -> CGVector {
        let angle = CGFloat.random(in: 0..<(2 * .pi))
        let speed = CGFloat.random(in: GameConfiguration.Ball.normalDriftSpeedRange)
        return CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
    }
}
