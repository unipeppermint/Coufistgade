//
//  GameOverlayView.swift
//  coufistgade
//
//  The dimmed panel shown over a stopped game: paused, or the round just ended.
//
//  One view for both because they are the same shape — a title, an optional
//  detail line, a primary action and a secondary one (GAMEPLAY §24's
//  Resume/Quit and §23's Play Again/Home). Two near-identical views would drift.
//
//  Phase 12 replaces the round-end case with the real ResultViewController.
//  This is not a stand-in for the pause case, which has no other home.
//

import UIKit

final class GameOverlayView: UIView {

    enum AccessibilityID {
        static let title = "game.overlayTitle"
        static let primaryButton = "game.overlayPrimary"
        static let secondaryButton = "game.overlaySecondary"
    }

    /// What the overlay is for. Keeps the two configurations side by side
    /// instead of spread across the call sites.
    struct Content {
        let title: String
        let detail: String?
        let primaryTitle: String
        let secondaryTitle: String
    }

    private let panel = UIView()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let primaryButton = BouncyButton()
    private let secondaryButton = UIButton(type: .system)
    private let stack = UIStackView()

    var onPrimaryTapped: (() -> Void)?
    var onSecondaryTapped: (() -> Void)?

    init() {
        super.init(frame: .zero)
        setupUI()
        setupConstraints()
        setupActions()
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("GameOverlayView is code-only; this app uses no storyboards or nibs.")
    }

    // MARK: - Setup

    private func setupUI() {
        // Dims the game without hiding it: the player should still see the field
        // they are returning to.
        backgroundColor = UIColor(resource: .appBackground).withAlphaComponent(0.82)

        panel.backgroundColor = UIColor(resource: .surface)
        panel.layer.cornerRadius = Theme.Radius.card
        panel.layer.cornerCurve = .continuous

        titleLabel.font = Theme.Typography.rounded(
            .title1,
            weight: .bold,
            maximumPointSize: Theme.Typography.MaxPointSize.wordmark
        )
        titleLabel.textColor = UIColor(resource: .textPrimary)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityIdentifier = AccessibilityID.title

        detailLabel.font = Theme.Typography.rounded(
            .subheadline,
            weight: .medium,
            maximumPointSize: Theme.Typography.MaxPointSize.caption
        )
        detailLabel.textColor = UIColor(resource: .textSecondary)
        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.textAlignment = .center
        detailLabel.numberOfLines = 0

        primaryButton.accessibilityIdentifier = AccessibilityID.primaryButton

        var secondaryConfig = UIButton.Configuration.plain()
        secondaryConfig.baseForegroundColor = UIColor(resource: .textSecondary)
        secondaryButton.configuration = secondaryConfig
        secondaryButton.titleLabel?.adjustsFontForContentSizeCategory = true
        secondaryButton.accessibilityIdentifier = AccessibilityID.secondaryButton

        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = Theme.Spacing.s
        [titleLabel, detailLabel, primaryButton, secondaryButton]
            .forEach { stack.addArrangedSubview($0) }

        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(stack)
        addSubview(panel)
    }

    private func setupConstraints() {
        let primaryHeight = primaryButton.heightAnchor.constraint(
            equalToConstant: Theme.Layout.primaryButtonHeight
        )
        // Breakable, so an accessibility text size can grow the button rather
        // than clipping its label.
        primaryHeight.priority = .defaultHigh

        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: centerYAnchor),
            panel.leadingAnchor.constraint(
                greaterThanOrEqualTo: leadingAnchor,
                constant: Theme.Spacing.m
            ),
            panel.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor,
                constant: -Theme.Spacing.m
            ),
            panel.widthAnchor.constraint(
                lessThanOrEqualTo: widthAnchor,
                multiplier: 0.86
            ),
            // A floor as well as a ceiling: the paused panel has no detail line,
            // and without this it collapsed to the width of "Paused" while the
            // round-end panel sat much wider. Same furniture, same footprint.
            panel.widthAnchor.constraint(greaterThanOrEqualTo: widthAnchor, multiplier: 0.7),

            stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: Theme.Spacing.l),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -Theme.Spacing.m),
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: Theme.Spacing.m),
            stack.trailingAnchor.constraint(
                equalTo: panel.trailingAnchor,
                constant: -Theme.Spacing.m
            ),

            primaryHeight,
            secondaryButton.heightAnchor.constraint(
                greaterThanOrEqualToConstant: Theme.Layout.minimumTouchTarget
            ),
        ])
    }

    private func setupActions() {
        primaryButton.addTarget(self, action: #selector(handlePrimary), for: .touchUpInside)
        secondaryButton.addTarget(self, action: #selector(handleSecondary), for: .touchUpInside)
    }

    // MARK: - Presentation

    func show(_ content: Content) {
        titleLabel.text = content.title
        detailLabel.text = content.detail
        detailLabel.isHidden = content.detail == nil
        primaryButton.setTitle(content.primaryTitle, for: .normal)
        secondaryButton.setTitle(content.secondaryTitle, for: .normal)

        isHidden = false
        // Moves VoiceOver focus into the panel and, more importantly, stops it
        // reaching the game behind — a paused game is not interactive.
        accessibilityViewIsModal = true
        UIAccessibility.post(notification: .layoutChanged, argument: titleLabel)
    }

    func hide() {
        isHidden = true
        accessibilityViewIsModal = false
    }

    var isShowing: Bool { !isHidden }
    var displayedTitle: String? { titleLabel.text }
    var displayedDetail: String? { detailLabel.isHidden ? nil : detailLabel.text }

    // MARK: - Actions

    @objc private func handlePrimary() { onPrimaryTapped?() }
    @objc private func handleSecondary() { onSecondaryTapped?() }
}
