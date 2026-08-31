//
//  ComboHUDView.swift
//  coufistgade
//
//  The combo readout (UI_DESIGN §10): appears only when relevant, emphasises
//  on increase, never becomes persistent oversized text.
//
//  Shows the multiplier as the headline because that is what the player is
//  earning; the hit count is the smaller supporting number. The two are not
//  interchangeable — GAMEPLAY §15's ladder means 5 hits and 6 hits both pay 3x.
//

import UIKit

final class ComboHUDView: UIView {

    enum AccessibilityID {
        static let value = "game.comboValue"
    }

    private enum Animation {
        static let fadeDuration: TimeInterval = 0.16
        static let growDuration: TimeInterval = 0.10
        static let settleDuration: TimeInterval = 0.16
        /// Escalates with GAMEPLAY §16 without becoming a different animation.
        static func popScale(for emphasis: ComboEmphasis) -> CGFloat {
            switch emphasis {
            case .normal: 1.15
            case .strong: 1.28
            case .major: 1.45
            }
        }
    }

    private let countLabel = UILabel()
    private let multiplierLabel = UILabel()
    private let stack = UIStackView()

    private let prefersReducedMotion: () -> Bool

    init(prefersReducedMotion: @escaping () -> Bool = { MotionPreference.isReduced }) {
        self.prefersReducedMotion = prefersReducedMotion
        super.init(frame: .zero)
        setupUI()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("ComboHUDView is code-only; this app uses no storyboards or nibs.")
    }

    // MARK: - Setup

    private func setupUI() {
        isUserInteractionEnabled = false
        // Hidden by alpha, never by isHidden, and seeded with text below: see
        // the note in GameHUDView about why this view must keep its frame — and
        // its height — even when invisible.
        alpha = 0

        countLabel.font = Theme.Typography.rounded(
            .caption2,
            weight: .semibold,
            maximumPointSize: Theme.Typography.MaxPointSize.caption
        )
        countLabel.textColor = UIColor(resource: .textSecondary)
        countLabel.adjustsFontForContentSizeCategory = true

        multiplierLabel.font = Theme.Typography.numeric(
            .headline,
            maximumPointSize: Theme.Typography.MaxPointSize.caption
        )
        // The accent marks it as the reward, distinct from the white score.
        multiplierLabel.textColor = UIColor(resource: .accent)
        multiplierLabel.adjustsFontForContentSizeCategory = true
        multiplierLabel.accessibilityIdentifier = AccessibilityID.value

        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = Theme.Spacing.xs / 2
        [countLabel, multiplierLabel].forEach { stack.addArrangedSubview($0) }

        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        // Seed both labels so the row has its full height from the start.
        //
        // MEASURED: alpha 0 alone does not reserve space — empty labels have
        // zero intrinsic height, so the HUD measured 51pt before the first
        // combo and 71.3pt after, moving the physics ceiling by 20pt the first
        // time a player chained two hits. The seed text is invisible at alpha 0
        // and is overwritten before the readout ever fades in.
        countLabel.text = Strings.comboCaption(GameConfiguration.Combo.minimumVisibleCount)
        multiplierLabel.text = "×\(GameConfiguration.Score.defaultMultiplier)"
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
        ])
    }

    // MARK: - Updating

    var displayedMultiplierText: String? { multiplierLabel.text }
    var isReadoutVisible: Bool { alpha > 0 }

    func apply(_ event: ComboEvent) {
        // Text first, so a skipped or interrupted animation cannot leave a
        // stale multiplier on screen.
        if event.isVisible {
            countLabel.text = Strings.comboCaption(event.count)
            multiplierLabel.text = "×\(event.multiplier)"
            multiplierLabel.accessibilityLabel = Strings.comboLabel(
                count: event.count,
                multiplier: event.multiplier
            )
        }

        setReadout(visible: event.isVisible)
        guard event.isVisible else { return }
        pop(emphasis: event.emphasis)
    }

    /// Hides the readout immediately, for a new round.
    func reset() {
        multiplierLabel.layer.removeAllAnimations()
        layer.removeAllAnimations()
        multiplierLabel.transform = .identity
        alpha = 0
    }

    // MARK: - Animation

    private func setReadout(visible: Bool) {
        let target: CGFloat = visible ? 1 : 0
        guard alpha != target else { return }
        guard !prefersReducedMotion() else {
            alpha = target
            return
        }

        UIView.animate(
            withDuration: Animation.fadeDuration,
            delay: 0,
            options: [.curveEaseOut, .beginFromCurrentState, .allowUserInteraction]
        ) {
            self.alpha = target
        }
    }

    private func pop(emphasis: ComboEmphasis) {
        guard !prefersReducedMotion() else { return }

        multiplierLabel.layer.removeAllAnimations()
        multiplierLabel.transform = .identity
        let scale = Animation.popScale(for: emphasis)

        UIView.animate(
            withDuration: Animation.growDuration,
            delay: 0,
            options: [.curveEaseOut, .beginFromCurrentState, .allowUserInteraction]
        ) {
            self.multiplierLabel.transform = CGAffineTransform(scaleX: scale, y: scale)
        } completion: { _ in
            UIView.animate(
                withDuration: Animation.settleDuration,
                delay: 0,
                options: [.curveEaseIn, .beginFromCurrentState, .allowUserInteraction]
            ) {
                self.multiplierLabel.transform = .identity
            }
        }
    }
}
