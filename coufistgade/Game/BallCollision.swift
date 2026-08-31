//
//  BallCollision.swift
//  coufistgade
//
//  The vocabulary of a scoring collision. Deliberately a plain value with no
//  SpriteKit contact type in it: everything downstream (score, combo,
//  particles, audio, haptics) consumes this, not SKPhysicsContact, so none of
//  those systems need a live physics world to be exercised.
//
//  Phase 7 produces these events. Phase 8 is the first phase to act on one.
//

import CoreGraphics

/// GAMEPLAY §11: collisions are graded so feedback can scale with the hit.
enum ImpactIntensity: Int, Comparable, CaseIterable {
    case low
    case medium
    case high

    /// Classifies by closing speed along the contact normal.
    ///
    /// Returns nil for a graze. A graze is not a fourth tier — it is not an
    /// event at all, because balls touch constantly while drifting and only a
    /// deliberate hit should read as one.
    init?(impactSpeed: CGFloat) {
        let thresholds = GameConfiguration.Collision.self
        switch impactSpeed {
        case ..<thresholds.grazeSpeed: return nil
        case ..<thresholds.mediumImpactSpeed: self = .low
        case ..<thresholds.highImpactSpeed: self = .medium
        default: self = .high
        }
    }

    static func < (lhs: ImpactIntensity, rhs: ImpactIntensity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// One player-ball-hits-normal-ball event.
struct BallCollision {
    let playerBall: BallNode
    let normalBall: BallNode

    /// Where the two surfaces met, in scene coordinates. Particles and score
    /// pops originate here rather than at a ball's centre.
    let point: CGPoint

    /// Speed along the contact normal, in points/sec. Kept alongside the tier
    /// so feedback can interpolate rather than being limited to three steps.
    let impactSpeed: CGFloat

    let intensity: ImpactIntensity
}
