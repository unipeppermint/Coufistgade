//
//  ScoreHUDView.swift
//  coufistgade
//
//  The score readout at the top of the game screen (UI_DESIGN §8, §9).
//
//  A view rather than two labels on the controller because it owns behaviour:
//  the pop animation, the Reduce Motion rule, and the guarantee that the number
//  is correct even when the animation is skipped.
//
//  Pure UIKit. It knows about ScoreEvent and nothing else about the game.
//

import UIKit

final class ScoreHUDView: UIView {

    enum AccessibilityID {
        static let value = "game.scoreValue"
    }

    private enum Animation {
        static let growDuration: TimeInterval = 0.09
        static let settleDuration: TimeInterval = 0.13

        /// UI_DESIGN §9 specifies 1.0 → 1.2 → 1.0 for an ordinary score.
        /// GAMEPLAY §16 asks for a stronger version at combo 4 and a major but
        /// tasteful one at combo 10 — the same animation, scaled, rather than a
        /// different effect that would read as a glitch.
        static func popScale(for emphasis: ComboEmphasis) -> CGFloat {
            switch emphasis {
            case .normal: 1.2
            case .strong: 1.32
            case .major: 1.5
            }
        }
    }

    private let captionLabel = UILabel()
    private let valueLabel = UILabel()
    private let stack = UIStackView()

    private let prefersReducedMotion: () -> Bool

    /// Injected so the Reduce Motion branch is testable without changing a
    /// device setting — the pattern HeroBallView already uses.
    init(prefersReducedMotion: @escaping () -> Bool = { MotionPreference.isReduced }) {
        self.prefersReducedMotion = prefersReducedMotion
        super.init(frame: .zero)
        setupUI()
        setupConstraints()
        update(score: 0, animated: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("ScoreHUDView is code-only; this app uses no storyboards or nibs.")
    }

    // MARK: - Setup

    private func setupUI() {
        isUserInteractionEnabled = false

        captionLabel.text = Strings.scoreCaption
        captionLabel.font = Theme.Typography.rounded(
            .caption2,
            weight: .semibold,
            maximumPointSize: Theme.Typography.MaxPointSize.caption
        )
        captionLabel.textColor = UIColor(resource: .textSecondary)
        captionLabel.adjustsFontForContentSizeCategory = true
        captionLabel.textAlignment = .center

        valueLabel.font = Theme.Typography.numeric(
            .title1,
            maximumPointSize: Theme.Typography.MaxPointSize.scoreValue
        )
        valueLabel.textColor = UIColor(resource: .textPrimary)
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.textAlignment = .center
        valueLabel.accessibilityIdentifier = AccessibilityID.value

        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 0
        [captionLabel, valueLabel].forEach { stack.addArrangedSubview($0) }

        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    /// What the readout currently shows. The HUD's own state, rather than the
    /// game's — the two matching is precisely what is worth asserting.
    var displayedScoreText: String? { valueLabel.text }

    // MARK: - Updating

    /// Sets the displayed score, optionally with the UI_DESIGN §9 pop.
    ///
    /// The text is assigned before any animation starts, so an interrupted or
    /// skipped animation can never leave a stale number on screen.
    func update(
        score: Int,
        animated: Bool = true,
        emphasis: ComboEmphasis = .normal
    ) {
        valueLabel.text = "\(score)"
        // The value carries the meaning; the caption is decoration. VoiceOver
        // reads one label instead of two fragments.
        valueLabel.accessibilityLabel = Strings.scoreLabel(score)

        guard animated, !prefersReducedMotion() else { return }
        pop(emphasis: emphasis)
    }

    func apply(_ event: ScoreEvent, emphasis: ComboEmphasis = .normal) {
        update(score: event.total, emphasis: emphasis)
    }

    /// Returns the readout to zero without a pop — a new round is not an event
    /// worth emphasising.
    func reset() {
        valueLabel.layer.removeAllAnimations()
        valueLabel.transform = .identity
        update(score: 0, animated: false)
    }

    // MARK: - Animation

    private func pop(emphasis: ComboEmphasis) {
        // Restart from identity: rapid hits would otherwise compound the scale.
        valueLabel.layer.removeAllAnimations()
        valueLabel.transform = .identity
        let scale = Animation.popScale(for: emphasis)

        UIView.animate(
            withDuration: Animation.growDuration,
            delay: 0,
            options: [.curveEaseOut, .beginFromCurrentState, .allowUserInteraction]
        ) {
            self.valueLabel.transform = CGAffineTransform(scaleX: scale, y: scale)
        } completion: { _ in
            UIView.animate(
                withDuration: Animation.settleDuration,
                delay: 0,
                options: [.curveEaseIn, .beginFromCurrentState, .allowUserInteraction]
            ) {
                self.valueLabel.transform = .identity
            }
        }
    }
}
