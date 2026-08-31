//
//  HeroBallView.swift
//  coufistgade
//
//  The visual hero of the Home screen (UI_DESIGN §6).
//  Purely decorative: it owns no physics. The real physical ball is a
//  SpriteKit node created in Phase 4.
//

import UIKit

final class HeroBallView: UIView {

    /// Fraction of the diameter the ball travels while breathing.
    private static let floatTravelRatio: CGFloat = 0.04
    private static let floatScale: CGFloat = 1.03
    private static let floatAnimationKey = "heroBallFloat"

    /// Injectable so tests can exercise both motion paths without touching
    /// the simulator's accessibility settings.
    private let prefersReducedMotion: () -> Bool

    private let bodyLayer = CAGradientLayer()
    private let highlightLayer = CAGradientLayer()

    init(prefersReducedMotion: @escaping () -> Bool = { MotionPreference.isReduced }) {
        self.prefersReducedMotion = prefersReducedMotion
        super.init(frame: .zero)
        setupLayers()
        observeSystemChanges()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("HeroBallView is code-only; this app uses no storyboards or nibs.")
    }

    // MARK: - Setup

    private func setupLayers() {
        isUserInteractionEnabled = false

        // Body: lit from the upper-left, falling off to a deep core.
        // The accent is held across most of the surface so the ball and the
        // Play button read as the same accent (UI_DESIGN §3).
        bodyLayer.type = .radial
        bodyLayer.colors = [
            UIColor(resource: .ballHighlight).cgColor,
            UIColor(resource: .accent).cgColor,
            UIColor(resource: .ballCore).cgColor,
        ]
        bodyLayer.locations = [0.0, 0.42, 1.0]
        bodyLayer.startPoint = CGPoint(x: 0.35, y: 0.3)
        bodyLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        layer.addSublayer(bodyLayer)

        // Specular highlight, offset toward the same light source.
        highlightLayer.type = .radial
        highlightLayer.colors = [
            UIColor.white.withAlphaComponent(0.75).cgColor,
            UIColor.white.withAlphaComponent(0.18).cgColor,
            UIColor.white.withAlphaComponent(0).cgColor,
        ]
        highlightLayer.locations = [0.0, 0.45, 1.0]
        highlightLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        highlightLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        layer.addSublayer(highlightLayer)

        // Outer glow, tinted to the ball so the accent reads as light spill.
        layer.shadowColor = UIColor(resource: .accent).cgColor
        layer.shadowOpacity = 0.4
        layer.shadowRadius = 24
        layer.shadowOffset = CGSize(width: 0, height: 10)
    }

    private func observeSystemChanges() {
        // Two system events can silently strip or invalidate the animation:
        // a Reduce Motion toggle, and the render server dropping animations
        // while backgrounded. Both need an explicit re-evaluation.
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(motionPreferenceOrLifecycleChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(motionPreferenceOrLifecycleChanged),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func motionPreferenceOrLifecycleChanged() {
        guard window != nil else { return }
        startFloating()
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        let diameter = min(bounds.width, bounds.height)
        let ballRect = CGRect(
            x: bounds.midX - diameter / 2,
            y: bounds.midY - diameter / 2,
            width: diameter,
            height: diameter
        )

        bodyLayer.frame = ballRect
        bodyLayer.cornerRadius = diameter / 2
        bodyLayer.masksToBounds = true

        // Highlight sits in the upper-left quadrant at ~38% of the diameter.
        let highlightSize = diameter * 0.38
        highlightLayer.frame = CGRect(
            x: ballRect.minX + diameter * 0.16,
            y: ballRect.minY + diameter * 0.12,
            width: highlightSize,
            height: highlightSize
        )
        highlightLayer.cornerRadius = highlightSize / 2

        layer.shadowPath = UIBezierPath(ovalIn: ballRect).cgPath
    }

    // MARK: - Motion

    /// True when the breathe animation is currently attached.
    var isFloating: Bool {
        layer.animation(forKey: Self.floatAnimationKey) != nil
    }

    func startFloating() {
        layer.removeAnimation(forKey: Self.floatAnimationKey)

        // UI_DESIGN §20: reduce large motion, but never remove the object.
        guard !prefersReducedMotion() else { return }

        let diameter = min(bounds.width, bounds.height)
        guard diameter > 0 else { return }

        let travel = diameter * Self.floatTravelRatio

        let rise = CABasicAnimation(keyPath: "transform.translation.y")
        rise.fromValue = travel / 2
        rise.toValue = -travel / 2

        let swell = CABasicAnimation(keyPath: "transform.scale")
        swell.fromValue = 1.0
        swell.toValue = Self.floatScale

        let group = CAAnimationGroup()
        group.animations = [rise, swell]
        group.duration = Theme.Duration.heroFloatCycle / 2
        group.autoreverses = true
        group.repeatCount = .infinity
        group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        group.isRemovedOnCompletion = false

        layer.add(group, forKey: Self.floatAnimationKey)
    }

    func stopFloating() {
        layer.removeAnimation(forKey: Self.floatAnimationKey)
    }
}
