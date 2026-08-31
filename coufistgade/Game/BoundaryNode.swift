//
//  BoundaryNode.swift
//  coufistgade
//
//  The walls of the playable area (GAMEPLAY §9).
//
//  Extracted from GameScene once that file crossed the 200-line mark set in
//  Phase 4 as the God Object warning line. This is a genuine responsibility
//  moving out, not lines being relocated: turning a rect into a configured
//  physics edge is self-contained and has nothing to do with scene assembly.
//

import SpriteKit

final class BoundaryNode: SKNode {

    /// The rect currently enclosed, in scene coordinates.
    private(set) var enclosedRect: CGRect = .zero

    override init() {
        super.init()
        name = "boundary"
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("BoundaryNode is code-only; this app uses no storyboards or nibs.")
    }

    /// Rebuilds the edge to enclose `rect`. A degenerate rect leaves the node
    /// bodyless rather than producing an invalid physics body.
    func enclose(_ rect: CGRect) {
        enclosedRect = rect

        guard rect.width > 0, rect.height > 0 else {
            physicsBody = nil
            return
        }

        // An edge loop is massless and immovable, so a fast ball cannot push the
        // wall or tunnel through it the way a thin volume body allows.
        let body = SKPhysicsBody(edgeLoopFrom: rect)

        // An edge loop defaults to isDynamic/affectedByGravity == true even
        // though it cannot actually move. Stating the intent explicitly keeps
        // the wall inert if gravity ever becomes non-zero (GAMEPLAY §8).
        body.isDynamic = false
        body.affectedByGravity = false
        body.allowsRotation = false

        body.friction = GameConfiguration.Physics.boundaryFriction
        // NB: this value, not the ball's, governs bounce liveliness — SpriteKit
        // resolves a collision with the maximum restitution of the two bodies.
        // See the note in GameConfiguration.Physics.
        body.restitution = GameConfiguration.Physics.boundaryRestitution

        body.categoryBitMask = PhysicsCategory.boundary
        // Balls collide with the wall; the wall reports no contacts of its own,
        // so a wall bounce can never be mistaken for a scoring event.
        body.collisionBitMask = PhysicsCategory.allBalls
        body.contactTestBitMask = PhysicsCategory.none

        physicsBody = body
    }
}
