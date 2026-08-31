//
//  EffectManager.swift
//  coufistgade
//
//  Impact particles, combo effects, and the floating score (ARCHITECTURE §16).
//
//  Every node it creates removes itself, so nothing accumulates over a round.
//  Textures are built once and shared, for the same reason BallNode caches its
//  own: an SKEmitterNode with a per-instance texture cannot be batched.
//
//  Honours Reduce Motion by suppressing motion, not information — the score
//  still appears, it simply does not fly.
//

import SpriteKit

final class EffectManager {

    /// Where effects are added. The scene outlives this object.
    private unowned let container: SKNode

    private let prefersReducedMotion: () -> Bool

    private static var sparkTexture: SKTexture?

    init(
        container: SKNode,
        prefersReducedMotion: @escaping () -> Bool = { MotionPreference.isReduced }
    ) {
        self.container = container
        self.prefersReducedMotion = prefersReducedMotion
    }

    // MARK: - Impact

    /// GAMEPLAY §12's particle burst, scaled by tier.
    func playImpact(_ collision: BallCollision) {
        // Reduce Motion: a burst of flying particles is exactly what the setting
        // asks to be spared. The hit still reads through sound, haptics, and the
        // score, so nothing is lost but the motion.
        guard !prefersReducedMotion() else { return }

        let emitter = makeEmitter(for: collision)
        emitter.position = collision.point
        emitter.zPosition = Layer.particles
        container.addChild(emitter)

        // Emits once, then leaves. Lifetime plus a margin so the last particle
        // finishes its own fade before the node goes.
        let lifetime = GameConfiguration.Feedback.Particles.lifetime
        emitter.run(.sequence([.wait(forDuration: lifetime * 2), .removeFromParent()]))
    }

    private func makeEmitter(for collision: BallCollision) -> SKEmitterNode {
        let config = GameConfiguration.Feedback.Particles.self
        let intensity = collision.intensity
        let emitter = SKEmitterNode()

        emitter.particleTexture = Self.spark()
        // UI_DESIGN §12: particle colour follows the ball.
        emitter.particleColor = collision.normalBall.kind.highlightColor
        emitter.particleColorBlendFactor = 1
        emitter.particleBlendMode = .add

        // A single burst, not a stream: numParticlesToEmit stops it dead.
        emitter.numParticlesToEmit = config.count(for: intensity)
        emitter.particleBirthRate = CGFloat(config.count(for: intensity)) * 60

        emitter.particleLifetime = config.lifetime
        emitter.particleLifetimeRange = config.lifetime * 0.4

        emitter.particleSpeed = config.speed(for: intensity)
        emitter.particleSpeedRange = config.speed(for: intensity) * 0.5
        emitter.emissionAngleRange = config.angleRange

        emitter.particleSize = CGSize(
            width: config.size(for: intensity),
            height: config.size(for: intensity)
        )
        emitter.particleScaleSpeed = -1.4
        emitter.particleAlpha = 0.9
        emitter.particleAlphaSpeed = -1 / CGFloat(config.lifetime)

        return emitter
    }

    /// A soft round dot. Built once: an emitter with its own texture cannot
    /// batch, and this is the hot path during a rally.
    private static func spark() -> SKTexture {
        if let cached = sparkTexture { return cached }

        let diameter: CGFloat = 16
        let size = CGSize(width: diameter, height: diameter)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let centre = CGPoint(x: diameter / 2, y: diameter / 2)
            let colours = [
                UIColor.white.cgColor,
                UIColor.white.withAlphaComponent(0).cgColor,
            ]
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colours as CFArray,
                locations: [0, 1]
            ) else { return }
            context.cgContext.drawRadialGradient(
                gradient,
                startCenter: centre,
                startRadius: 0,
                endCenter: centre,
                endRadius: diameter / 2,
                options: []
            )
        }

        let texture = SKTexture(image: image)
        sparkTexture = texture
        return texture
    }

    // MARK: - Score popup

    /// The floating value at the point of impact (UI_DESIGN §9's score
    /// animation, at the place the score was earned rather than in the HUD).
    func playScorePopup(_ event: ScoreEvent, at point: CGPoint) {
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        let isCombo = event.multiplier > 1
        label.text = isCombo ? "+\(event.points)" : "+\(event.points)"
        label.fontSize = isCombo
            ? GameConfiguration.Feedback.ScorePopup.comboFontSize
            : GameConfiguration.Feedback.ScorePopup.fontSize
        // Accent for a multiplied score, so a combo hit is visibly worth more.
        label.fontColor = isCombo
            ? UIColor(resource: .accent)
            : UIColor(resource: .textPrimary)
        label.position = point
        label.zPosition = Layer.popup
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center

        container.addChild(label)

        let duration = GameConfiguration.Feedback.ScorePopup.duration
        guard !prefersReducedMotion() else {
            // Still shown, just held in place and faded — the information is
            // not the part Reduce Motion objects to.
            label.run(.sequence([
                .wait(forDuration: duration * 0.5),
                .fadeOut(withDuration: duration * 0.5),
                .removeFromParent(),
            ]))
            return
        }

        let rise = SKAction.moveBy(
            x: 0,
            y: GameConfiguration.Feedback.ScorePopup.riseDistance,
            duration: duration
        )
        rise.timingMode = .easeOut
        let fade = SKAction.sequence([
            .wait(forDuration: duration * 0.45),
            .fadeOut(withDuration: duration * 0.55),
        ])
        label.run(.sequence([.group([rise, fade]), .removeFromParent()]))
    }

    // MARK: - Combo emphasis

    /// GAMEPLAY §16's escalation, on the ball rather than in the HUD: at high
    /// combo the player is watching the ball, not the top of the screen.
    func playComboEmphasis(_ event: ComboEvent, on ball: BallNode) {
        guard event.emphasis > .normal, !prefersReducedMotion() else { return }

        let scale = event.emphasis == .major ? 1.35 : 1.18
        let pulse = SKAction.sequence([
            .scale(to: scale, duration: 0.08),
            .scale(to: 1.0, duration: 0.16),
        ])
        pulse.timingMode = .easeOut
        // Keyed so a rapid second milestone replaces the pulse instead of
        // queueing behind it and leaving the ball briefly oversized.
        ball.removeAction(forKey: ActionKey.comboPulse)
        ball.run(pulse, withKey: ActionKey.comboPulse)
    }

    private enum ActionKey {
        static let comboPulse = "combo.pulse"
    }

    /// Draw order for everything this manager adds. Above the balls, which sit
    /// at 0, and below the debug overlays at 1000.
    private enum Layer {
        static let particles: CGFloat = 10
        static let popup: CGFloat = 20
    }
}
