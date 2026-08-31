//
//  CollisionManager.swift
//  coufistgade
//
//  Turns raw SpriteKit contacts into meaningful game events (ARCHITECTURE §13).
//
//  It is the physics-world contact delegate itself rather than a helper the
//  scene forwards to, so contact interpretation lives in exactly one type and
//  GameScene keeps no knowledge of bitmasks or contact normals.
//
//  Two jobs, and only these two:
//    1. decide whether a contact is a scoring event at all
//    2. describe how hard it was
//
//  What an event is *worth* is Phase 8's problem, and what it looks and feels
//  like is Phase 10's. This type must not grow either.
//

import SpriteKit

final class CollisionManager: NSObject, SKPhysicsContactDelegate {

    /// Emitted for each accepted collision, on the physics step.
    var onBallCollision: ((BallCollision) -> Void)?

    /// Scene clock, pushed by GameScene each frame. Used for the repeat-contact
    /// cooldown. The game clock rather than wall time, so it stops when the
    /// scene is paused.
    var currentTime: TimeInterval = 0

    /// Last accepted event per normal ball. Only the normal ball is keyed
    /// because the player ball is on one side of every reported contact.
    private var lastEventTime: [ObjectIdentifier: TimeInterval] = [:]

    // MARK: - SKPhysicsContactDelegate

    func didBegin(_ contact: SKPhysicsContact) {
        guard let pair = Self.balls(in: contact) else { return }

        let speed = Self.approachSpeed(
            fromSeparation: Self.separationSpeed(
                playerVelocity: pair.player.physicsBody?.velocity ?? .zero,
                normalVelocity: pair.normal.physicsBody?.velocity ?? .zero,
                contactNormal: contact.contactNormal
            )
        )
        guard let intensity = ImpactIntensity(impactSpeed: speed) else { return }
        guard accept(ObjectIdentifier(pair.normal)) else { return }

        onBallCollision?(
            BallCollision(
                playerBall: pair.player,
                normalBall: pair.normal,
                point: contact.contactPoint,
                impactSpeed: speed,
                intensity: intensity
            )
        )
    }

    // MARK: - Interpretation
    //
    // Static and value-typed on purpose: SKPhysicsContact cannot be constructed
    // in a test, so the arithmetic is kept where it can be called directly.

    /// Sorts a contact's two bodies into (player, normal), or nil if it is not
    /// that pairing. Belt and braces — the bitmasks should already guarantee it.
    static func balls(in contact: SKPhysicsContact) -> (player: BallNode, normal: BallNode)? {
        let nodes = [contact.bodyA.node, contact.bodyB.node].compactMap { $0 as? BallNode }
        guard nodes.count == 2,
              let player = nodes.first(where: { $0.kind == .player }),
              let normal = nodes.first(where: { $0.kind == .normal })
        else { return nil }
        return (player, normal)
    }

    /// Relative speed along the contact normal, in points/sec.
    ///
    /// The normal component, not the full relative speed: two balls skimming
    /// past each other share a large relative velocity but barely touch, and
    /// grading that as a hard hit is exactly the mismatch GAMEPLAY §11 warns
    /// about. Magnitude only, because `contactNormal`'s direction depends on
    /// which body SpriteKit happened to call bodyA.
    ///
    /// Called with the velocities seen in `didBegin`, this is the *separation*
    /// speed — see `approachSpeed(fromSeparation:)`.
    static func separationSpeed(
        playerVelocity: CGVector,
        normalVelocity: CGVector,
        contactNormal: CGVector
    ) -> CGFloat {
        let length = hypot(contactNormal.dx, contactNormal.dy)
        guard length > 0 else { return 0 }

        let relative = CGVector(
            dx: playerVelocity.dx - normalVelocity.dx,
            dy: playerVelocity.dy - normalVelocity.dy
        )
        let projected = relative.dx * contactNormal.dx + relative.dy * contactNormal.dy
        return abs(projected / length)
    }

    /// Converts what `didBegin` can see into what the player actually did.
    ///
    /// MEASURED (Phase 7, iOS 26.5 simulator): the contact delegate runs
    /// *after* the solver, so both bodies already carry their post-bounce
    /// velocities. Across launch speeds of 200 / 600 / 1400 pt/s the reported
    /// normal-component speed came to 143.2 / 471.2 / 1127.3 against
    /// pre-impact speeds of 174.8 / 574.8 / 1374.8 — a ratio of 0.820, 0.820,
    /// 0.820. That is `ballRestitution`, exactly, which is the textbook
    /// definition of the coefficient: separation over approach along the
    /// normal, independent of the two masses.
    ///
    /// So dividing it back out recovers how hard the player hit, which is what
    /// GAMEPLAY §11 means by intensity. Without this the tiers are quietly
    /// denominated in restitution units, and a Phase 15 tweak to
    /// `ballRestitution` would re-grade every collision in the game without
    /// touching a single threshold.
    static func approachSpeed(fromSeparation separation: CGFloat) -> CGFloat {
        // Ball-on-ball, and SpriteKit takes the maximum of the two bodies
        // (measured in Phase 4), so both sides contribute the same value.
        let restitution = GameConfiguration.Physics.ballRestitution
        guard restitution > 0 else { return separation }
        return separation / restitution
    }

    // MARK: - Repeat suppression

    /// Whether a hit on this ball counts, recording it if so.
    ///
    /// Balls that come to rest against each other re-contact every frame. Left
    /// unchecked that is 60 events/sec from one nudge, which no downstream
    /// system could sensibly consume.
    func accept(_ ball: ObjectIdentifier, at time: TimeInterval? = nil) -> Bool {
        let now = time ?? currentTime
        let cooldown = GameConfiguration.Collision.repeatContactCooldown

        if let last = lastEventTime[ball], now - last < cooldown, now >= last {
            return false
        }

        // Drop expired entries so the table cannot outlive the balls it names.
        // ObjectIdentifier is only unique among *live* objects: a recycled
        // address inheriting a stale timestamp would silently eat a real hit.
        lastEventTime = lastEventTime.filter { now - $0.value < cooldown }
        lastEventTime[ball] = now
        return true
    }
}
