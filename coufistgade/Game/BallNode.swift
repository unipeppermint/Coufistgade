//
//  BallNode.swift
//  coufistgade
//
//  A ball and its SpriteKit representation (ARCHITECTURE §11).
//
//  Subclasses SKSpriteNode rather than wrapping one so that Phase 7's contact
//  callbacks can recover the ball with a plain cast off contact.bodyA.node,
//  with no node-to-entity registry to keep in sync.
//
//  SKSpriteNode with a cached texture, not SKShapeNode: shape nodes
//  re-rasterise every frame, which will not hold 60fps with 10 balls plus
//  particles (ARCHITECTURE §25).
//
//  Phase 4 creates only the .player kind; .normal is wired up in Phase 6.
//

import SpriteKit

final class BallNode: SKSpriteNode {

    enum Kind {
        case player
        case normal

        /// Physical diameter in points. The sprite is larger — see `spriteSize`.
        var diameter: CGFloat {
            switch self {
            case .player: GameConfiguration.Ball.playerDiameter
            case .normal: GameConfiguration.Ball.normalDiameter
            }
        }

        var categoryBitMask: UInt32 {
            switch self {
            case .player: PhysicsCategory.playerBall
            case .normal: PhysicsCategory.normalBall
            }
        }

        /// The player ball carries the app's accent so it reads as the hero
        /// (UI_DESIGN §3); normal balls stay neutral so they do not compete.
        var coreColor: UIColor {
            switch self {
            case .player: UIColor(resource: .ballCore)
            case .normal: UIColor(resource: .normalBallCore)
            }
        }

        var surfaceColor: UIColor {
            switch self {
            case .player: UIColor(resource: .accent)
            case .normal: UIColor(resource: .normalBallCore).lightened(by: 0.18)
            }
        }

        var highlightColor: UIColor {
            switch self {
            case .player: UIColor(resource: .ballHighlight)
            case .normal: UIColor(resource: .normalBallHighlight)
            }
        }

        /// GAMEPLAY §4: the player ball produces stronger feedback, so it gets
        /// a glow while normal balls do not.
        var glowOpacity: CGFloat {
            switch self {
            case .player: 0.5
            case .normal: 0.0
            }
        }

        /// Which contacts get *reported*, independent of which bodies physically
        /// collide (`collisionBitMask`).
        ///
        /// Declared on the player side only. SpriteKit reports a pair once if
        /// either body names the other, so setting it on both would be
        /// redundant, and naming it here states the asymmetry the game actually
        /// has: only the player hitting a ball is a scoring event. Wall bounces
        /// and normal-on-normal drift are silent (GAMEPLAY §17's chain
        /// reactions are a later, deliberate change).
        var contactTestBitMask: UInt32 {
            switch self {
            case .player: PhysicsCategory.normalBall
            case .normal: PhysicsCategory.none
            }
        }

        /// Differs by kind on purpose — see the note in
        /// GameConfiguration.Physics. The player ball must settle; normal balls
        /// must not grind to a halt mid-round.
        var linearDamping: CGFloat {
            switch self {
            case .player: GameConfiguration.Physics.ballLinearDamping
            case .normal: GameConfiguration.Physics.normalBallLinearDamping
            }
        }
    }

    /// One texture per kind — every ball of a kind shares it, so the renderer
    /// can batch them into a single draw call.
    private static var textureCache: [Kind: SKTexture] = [:]

    let kind: Kind

    /// Physics radius. Derived from the configured diameter, never from
    /// `size`, which includes the glow padding.
    var physicalRadius: CGFloat { kind.diameter / 2 }

    init(kind: Kind) {
        self.kind = kind

        let texture = Self.texture(for: kind)
        super.init(texture: texture, color: .clear, size: Self.spriteSize(for: kind))

        name = "ball.\(kind)"
        setupPhysicsBody()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("BallNode is code-only; this app uses no storyboards or nibs.")
    }

    // MARK: - Placement

    /// Clamps the ball fully inside `rect`.
    ///
    /// Needed whenever the playable area changes: the edge loop only pushes
    /// outward from the inside, so a ball left beyond a rebuilt wall stays
    /// trapped there. Lives on the ball because it is pure ball geometry —
    /// both the scene (player) and BallManager (normals) need exactly this.
    func contain(in rect: CGRect) {
        guard rect.width > 0, rect.height > 0 else { return }

        let limits = rect.insetBy(dx: physicalRadius, dy: physicalRadius)
        guard limits.width > 0, limits.height > 0 else {
            // Area too small to hold the ball at all: centre it rather than
            // clamp against a degenerate rect and wedge it into a corner.
            position = CGPoint(x: rect.midX, y: rect.midY)
            return
        }

        position = CGPoint(
            x: min(max(position.x, limits.minX), limits.maxX),
            y: min(max(position.y, limits.minY), limits.maxY)
        )
    }

    // MARK: - Physics

    private func setupPhysicsBody() {
        let body = SKPhysicsBody(circleOfRadius: physicalRadius)

        body.isDynamic = true
        // Gravity is zero today, but stating this keeps the ball inert if
        // GAMEPLAY §8's "very small" gravity is ever adopted.
        body.affectedByGravity = false
        // angularDamping below is only meaningful if the ball can spin.
        body.allowsRotation = true

        body.density = GameConfiguration.Physics.ballDensity
        body.friction = GameConfiguration.Physics.ballFriction
        body.restitution = GameConfiguration.Physics.ballRestitution
        body.linearDamping = kind.linearDamping
        body.angularDamping = GameConfiguration.Physics.ballAngularDamping

        // GAMEPLAY §9 requires no tunnelling at speed. Without this a fast ball
        // steps straight through the edge loop between frames.
        body.usesPreciseCollisionDetection = true

        body.categoryBitMask = kind.categoryBitMask
        // Balls bounce off the walls and off each other.
        body.collisionBitMask = PhysicsCategory.boundary | PhysicsCategory.allBalls
        body.contactTestBitMask = kind.contactTestBitMask

        physicsBody = body
    }

    // MARK: - Texture

    private static func spriteSize(for kind: Kind) -> CGSize {
        let padded = kind.diameter + GameConfiguration.Ball.glowPadding * 2
        return CGSize(width: padded, height: padded)
    }

    private static func texture(for kind: Kind) -> SKTexture {
        if let cached = textureCache[kind] { return cached }
        let texture = makeTexture(for: kind)
        textureCache[kind] = texture
        return texture
    }

    /// Draws the ball once: outer glow, lit body, specular highlight.
    ///
    /// The glow is baked in rather than produced by an SKEffectNode (a
    /// per-frame Core Image pass) or a second sprite (double the node count).
    private static func makeTexture(for kind: Kind) -> SKTexture {
        let canvas = spriteSize(for: kind)
        let diameter = kind.diameter
        let padding = GameConfiguration.Ball.glowPadding
        let ballRect = CGRect(x: padding, y: padding, width: diameter, height: diameter)
        let centre = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
        let colourSpace = CGColorSpaceCreateDeviceRGB()

        let renderer = UIGraphicsImageRenderer(size: canvas)
        let image = renderer.image { context in
            let cg = context.cgContext

            if kind.glowOpacity > 0 {
                let glowColours = [
                    kind.surfaceColor.withAlphaComponent(kind.glowOpacity).cgColor,
                    kind.surfaceColor.withAlphaComponent(0).cgColor,
                ]
                if let glow = CGGradient(
                    colorsSpace: colourSpace,
                    colors: glowColours as CFArray,
                    locations: [0, 1]
                ) {
                    cg.drawRadialGradient(
                        glow,
                        startCenter: centre,
                        startRadius: diameter / 2 * 0.85,
                        endCenter: centre,
                        endRadius: canvas.width / 2,
                        options: []
                    )
                }
            }

            // Body, lit from the upper-left. Matches HeroBallView so the game
            // ball and the Home hero read as the same object.
            cg.saveGState()
            cg.addEllipse(in: ballRect)
            cg.clip()

            let bodyColours = [
                kind.highlightColor.cgColor,
                kind.surfaceColor.cgColor,
                kind.coreColor.cgColor,
            ]
            if let body = CGGradient(
                colorsSpace: colourSpace,
                colors: bodyColours as CFArray,
                locations: [0, 0.42, 1]
            ) {
                let lightSource = CGPoint(
                    x: ballRect.minX + diameter * 0.35,
                    y: ballRect.minY + diameter * 0.3
                )
                cg.drawRadialGradient(
                    body,
                    startCenter: lightSource,
                    startRadius: 0,
                    endCenter: lightSource,
                    endRadius: diameter * 0.95,
                    options: [.drawsAfterEndLocation]
                )
            }

            // Specular dot, offset toward the same light source.
            let specularSize = diameter * 0.38
            let specularRect = CGRect(
                x: ballRect.minX + diameter * 0.16,
                y: ballRect.minY + diameter * 0.12,
                width: specularSize,
                height: specularSize
            )
            let specularColours = [
                UIColor.white.withAlphaComponent(0.75).cgColor,
                UIColor.white.withAlphaComponent(0).cgColor,
            ]
            if let specular = CGGradient(
                colorsSpace: colourSpace,
                colors: specularColours as CFArray,
                locations: [0, 1]
            ) {
                let specularCentre = CGPoint(x: specularRect.midX, y: specularRect.midY)
                cg.drawRadialGradient(
                    specular,
                    startCenter: specularCentre,
                    startRadius: 0,
                    endCenter: specularCentre,
                    endRadius: specularSize / 2,
                    options: []
                )
            }

            cg.restoreGState()
        }

        return SKTexture(image: image)
    }
}

private extension UIColor {
    /// Nudges a colour toward white, used to give the neutral ball a lit
    /// surface without needing a third asset.
    func lightened(by amount: CGFloat) -> UIColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return self }
        return UIColor(
            red: min(1, red + amount),
            green: min(1, green + amount),
            blue: min(1, blue + amount),
            alpha: alpha
        )
    }
}
