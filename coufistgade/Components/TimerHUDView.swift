//
//  TimerHUDView.swift
//  coufistgade
//
//  Time remaining in the round.
//
//  Not specified in UI_DESIGN §8, which lists only Score and Pause. Added
//  because GAMEPLAY §20 fixes the round at 60 seconds and §21 ends it abruptly:
//  without a readout the round simply stops, and a player who cannot see time
//  running out cannot decide whether to line up a careful shot or take a wild
//  one. Flagged in the phase summary as a deliberate addition to the spec.
//
//  Styled as the quieter sibling of the score — same numeric font, secondary
//  colour — so it informs without competing.
//

import UIKit

final class TimerHUDView: UIView {

    enum AccessibilityID {
        static let value = "game.timerValue"
    }

    private let valueLabel = UILabel()

    private let prefersReducedMotion: () -> Bool
    private var isUrgent = false

    init(prefersReducedMotion: @escaping () -> Bool = { MotionPreference.isReduced }) {
        self.prefersReducedMotion = prefersReducedMotion
        super.init(frame: .zero)
        setupUI()
        setupConstraints()
        update(remainingSeconds: Int(GameConfiguration.Round.duration), animated: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("TimerHUDView is code-only; this app uses no storyboards or nibs.")
    }

    // MARK: - Setup

    private func setupUI() {
        isUserInteractionEnabled = false

        valueLabel.font = Theme.Typography.numeric(
            .title3,
            maximumPointSize: Theme.Typography.MaxPointSize.caption
        )
        valueLabel.textColor = UIColor(resource: .textSecondary)
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.textAlignment = .center
        valueLabel.accessibilityIdentifier = AccessibilityID.value

        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(valueLabel)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            valueLabel.topAnchor.constraint(equalTo: topAnchor),
            valueLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    // MARK: - Updating

    var displayedText: String? { valueLabel.text }
    var isShowingUrgency: Bool { isUrgent }

    func update(remainingSeconds: Int, animated: Bool = true) {
        let clamped = max(0, remainingSeconds)
        valueLabel.text = "\(clamped)"
        valueLabel.accessibilityLabel = Strings.secondsRemainingLabel(clamped)

        let shouldBeUrgent = TimeInterval(clamped) <= GameConfiguration.Round.urgentRemainingTime
            && clamped > 0
        setUrgent(shouldBeUrgent, animated: animated)
    }

    func reset() {
        valueLabel.layer.removeAllAnimations()
        valueLabel.transform = .identity
        isUrgent = false
        valueLabel.textColor = UIColor(resource: .textSecondary)
        update(remainingSeconds: Int(GameConfiguration.Round.duration), animated: false)
    }

    /// The last ten seconds read differently, so the player notices without a
    /// countdown sound or a flashing overlay.
    private func setUrgent(_ urgent: Bool, animated: Bool) {
        let colour = urgent
            ? UIColor(resource: .accent)
            : UIColor(resource: .textSecondary)
        valueLabel.textColor = colour

        guard urgent, animated, !prefersReducedMotion() else {
            isUrgent = urgent
            return
        }
        isUrgent = urgent

        // A small pulse on each urgent second. Deliberately smaller than the
        // score pop — the timer should register, not demand attention.
        valueLabel.layer.removeAllAnimations()
        valueLabel.transform = .identity
        UIView.animate(
            withDuration: 0.10,
            delay: 0,
            options: [.curveEaseOut, .beginFromCurrentState, .allowUserInteraction]
        ) {
            self.valueLabel.transform = CGAffineTransform(scaleX: 1.14, y: 1.14)
        } completion: { _ in
            UIView.animate(
                withDuration: 0.16,
                delay: 0,
                options: [.curveEaseIn, .beginFromCurrentState, .allowUserInteraction]
            ) {
                self.valueLabel.transform = .identity
            }
        }
    }
}
