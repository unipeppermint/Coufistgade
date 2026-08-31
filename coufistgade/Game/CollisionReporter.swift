//
//  CollisionReporter.swift
//  coufistgade
//
//  Debug instrument for Phase 7: makes collision events visible before any
//  real feedback exists, so the GAMEPLAY §11 tier thresholds can be checked
//  against impact speeds the game actually produces.
//
//  An SKLabelNode for the same reason as BallSpeedTracker — it belongs to the
//  scene, and the HUD stays a UIKit concern owned by GameViewController
//  (ARCHITECTURE §23).
//
//  This is scaffolding. Phase 10's real feedback replaces it.
//

import SpriteKit
import os

final class CollisionReporter: SKLabelNode {

    private static let logger = Logger(subsystem: "com.cclv.coufistgade", category: "Collision")

    private var hitCount = 0
    private var countsByTier: [ImpactIntensity: Int] = [:]

    override init() {
        super.init()
        fontName = "Menlo"
        fontSize = 12
        fontColor = UIColor(resource: .textSecondary)
        horizontalAlignmentMode = .left
        verticalAlignmentMode = .bottom
        position = CGPoint(x: 12, y: 40)
        zPosition = 1000
        text = "hits 0"
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("CollisionReporter is code-only.")
    }

    func report(_ collision: BallCollision) {
        hitCount += 1
        countsByTier[collision.intensity, default: 0] += 1

        let tier = String(describing: collision.intensity).uppercased()
        text = String(format: "hits %d   %@ %.0f pt/s", hitCount, tier, collision.impactSpeed)

        Self.logger.info(
            """
            HIT #\(self.hitCount) \(tier, privacy: .public) \
            speed=\(collision.impactSpeed, format: .fixed(precision: 1)) \
            at=(\(collision.point.x, format: .fixed(precision: 0)),\
            \(collision.point.y, format: .fixed(precision: 0))) \
            tally=\(self.tally, privacy: .public)
            """
        )
    }

    /// Running distribution across the tiers — the number that says whether the
    /// thresholds are placed sensibly or whether every hit lands in one bucket.
    private var tally: String {
        ImpactIntensity.allCases
            .map { "\(String(describing: $0).prefix(1))\(countsByTier[$0] ?? 0)" }
            .joined(separator: "/")
    }
}
