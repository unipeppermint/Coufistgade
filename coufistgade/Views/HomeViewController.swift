//
//  HomeViewController.swift
//  coufistgade
//
//  Owns the Home UI only (ARCHITECTURE §5). No physics, no game state.
//  Play and Settings are deliberately inert until Phase 3 and Phase 14
//  create their destination screens.
//

import UIKit

final class HomeViewController: UIViewController {

    enum AccessibilityID {
        static let playButton = "home.playButton"
        static let settingsButton = "home.settingsButton"
        static let bestScoreValue = "home.bestScoreValue"
    }

    private let store: PersistenceManager

    private let heroBallView = HeroBallView()
    private let titleLabel = UILabel()
    private let bestScoreCaptionLabel = UILabel()
    private let bestScoreValueLabel = UILabel()
    private let bestScoreStack = UIStackView()
    private let playButton = BouncyButton()
    private let settingsButton = UIButton(type: .system)

    init(store: PersistenceManager = PersistenceManager()) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("HomeViewController is code-only; this app uses no storyboards or nibs.")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupActions()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Read on each appearance so returning from a round shows a fresh best.
        refreshBestScore()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        heroBallView.startFloating()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Nothing offscreen should keep the render server busy.
        heroBallView.stopFloating()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = UIColor(resource: .appBackground)

        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textAlignment = .center
        // Wide tracking reads as "premium wordmark" rather than "body text".
        titleLabel.attributedText = NSAttributedString(
            string: "BOUNCY",
            attributes: [
                .kern: 6,
                .font: Theme.Typography.rounded(
                    .largeTitle,
                    weight: .bold,
                    maximumPointSize: Theme.Typography.MaxPointSize.wordmark
                ),
                .foregroundColor: UIColor(resource: .textPrimary),
            ]
        )
        // The wordmark shrinks rather than truncating if space is still tight.
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.6

        bestScoreCaptionLabel.text = Strings.bestCaption
        bestScoreCaptionLabel.font = Theme.Typography.rounded(
            .caption1,
            weight: .semibold,
            maximumPointSize: Theme.Typography.MaxPointSize.caption
        )
        bestScoreCaptionLabel.textColor = UIColor(resource: .textSecondary)
        bestScoreCaptionLabel.adjustsFontForContentSizeCategory = true
        bestScoreCaptionLabel.textAlignment = .center

        bestScoreValueLabel.font = Theme.Typography.numeric(
            .title1,
            maximumPointSize: Theme.Typography.MaxPointSize.scoreValue
        )
        bestScoreValueLabel.textColor = UIColor(resource: .textPrimary)
        bestScoreValueLabel.adjustsFontForContentSizeCategory = true
        bestScoreValueLabel.textAlignment = .center
        bestScoreValueLabel.accessibilityIdentifier = AccessibilityID.bestScoreValue

        bestScoreStack.axis = .vertical
        bestScoreStack.alignment = .center
        bestScoreStack.spacing = Theme.Spacing.xs / 2
        bestScoreStack.addArrangedSubview(bestScoreCaptionLabel)
        bestScoreStack.addArrangedSubview(bestScoreValueLabel)
        // One combined announcement instead of two disconnected fragments.
        bestScoreStack.isAccessibilityElement = true
        bestScoreStack.accessibilityTraits = .staticText

        var playConfig = UIButton.Configuration.filled()
        playConfig.baseBackgroundColor = UIColor(resource: .accent)
        // Dark-on-accent clears 4.5:1; white on this cyan would not.
        playConfig.baseForegroundColor = UIColor(resource: .appBackground)
        playConfig.cornerStyle = .capsule
        playConfig.attributedTitle = AttributedString(
            Strings.play,
            attributes: AttributeContainer([
                .kern: 2,
                .font: Theme.Typography.rounded(
                    .headline,
                    weight: .bold,
                    maximumPointSize: Theme.Typography.MaxPointSize.buttonLabel
                ),
            ])
        )
        playButton.configuration = playConfig
        playButton.accessibilityIdentifier = AccessibilityID.playButton
        playButton.accessibilityLabel = Strings.startGameLabel

        var settingsConfig = UIButton.Configuration.plain()
        settingsConfig.image = UIImage(
            systemName: "gearshape.fill",
            // Constant glyph in a constant 44pt target: scaling it with
            // Dynamic Type only distorts the icon inside a fixed frame.
            withConfiguration: UIImage.SymbolConfiguration(
                pointSize: Theme.Layout.settingsIconPointSize
            )
        )
        settingsConfig.baseForegroundColor = UIColor(resource: .textSecondary)
        settingsConfig.contentInsets = .zero
        settingsButton.configuration = settingsConfig
        settingsButton.backgroundColor = UIColor(resource: .surface)
        settingsButton.layer.cornerRadius = Theme.Layout.minimumTouchTarget / 2
        settingsButton.accessibilityIdentifier = AccessibilityID.settingsButton
        settingsButton.accessibilityLabel = Strings.openSettingsLabel

        [heroBallView, titleLabel, bestScoreStack, playButton, settingsButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
    }

    private func setupConstraints() {
        let safe = view.safeAreaLayoutGuide

        let heroCenterY = heroBallView.centerYAnchor.constraint(equalTo: safe.centerYAnchor)
        // Yields to the required spacing chain on short screens or large text.
        heroCenterY.priority = .defaultHigh

        let heroWidth = heroBallView.widthAnchor.constraint(
            equalTo: safe.widthAnchor,
            multiplier: Theme.Layout.heroBallWidthRatio
        )
        heroWidth.priority = .defaultHigh

        // Breakable: at accessibility text sizes the ball should give up space
        // rather than push the required chain past the screen and conflict.
        // The maximum stays required — the ball must never grow unbounded.
        let heroMinimumWidth = heroBallView.widthAnchor.constraint(
            greaterThanOrEqualToConstant: Theme.Layout.heroBallMinimumDiameter
        )
        heroMinimumWidth.priority = .defaultHigh

        // Preferred rhythm; yields to the required minimum gap below it.
        let bestScoreToPlaySpacing = bestScoreStack.bottomAnchor.constraint(
            equalTo: playButton.topAnchor,
            constant: -Theme.Spacing.l
        )
        bestScoreToPlaySpacing.priority = .defaultHigh

        // The button may grow for a taller label, but never shrink below the
        // 56pt target — that is what erased the "PLAY" title before.
        let playPreferredHeight = playButton.heightAnchor.constraint(
            equalToConstant: Theme.Layout.primaryButtonHeight
        )
        playPreferredHeight.priority = .defaultHigh

        NSLayoutConstraint.activate([
            settingsButton.topAnchor.constraint(equalTo: safe.topAnchor, constant: Theme.Spacing.xs),
            settingsButton.trailingAnchor.constraint(
                equalTo: safe.trailingAnchor,
                constant: -Theme.Spacing.m
            ),
            settingsButton.widthAnchor.constraint(equalToConstant: Theme.Layout.minimumTouchTarget),
            settingsButton.heightAnchor.constraint(equalToConstant: Theme.Layout.minimumTouchTarget),

            titleLabel.topAnchor.constraint(
                equalTo: settingsButton.bottomAnchor,
                constant: Theme.Spacing.l
            ),
            titleLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: safe.leadingAnchor,
                constant: Theme.Spacing.m
            ),
            titleLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: safe.trailingAnchor,
                constant: -Theme.Spacing.m
            ),
            titleLabel.centerXAnchor.constraint(equalTo: safe.centerXAnchor),

            heroCenterY,
            heroWidth,
            heroMinimumWidth,
            heroBallView.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            heroBallView.heightAnchor.constraint(equalTo: heroBallView.widthAnchor),
            heroBallView.widthAnchor.constraint(
                lessThanOrEqualToConstant: Theme.Layout.heroBallMaximumDiameter
            ),
            heroBallView.topAnchor.constraint(
                greaterThanOrEqualTo: titleLabel.bottomAnchor,
                constant: Theme.Spacing.m
            ),

            bestScoreStack.topAnchor.constraint(
                greaterThanOrEqualTo: heroBallView.bottomAnchor,
                constant: Theme.Spacing.m
            ),
            bestScoreStack.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            bestScoreStack.leadingAnchor.constraint(
                greaterThanOrEqualTo: safe.leadingAnchor,
                constant: Theme.Spacing.m
            ),
            bestScoreToPlaySpacing,
            bestScoreStack.bottomAnchor.constraint(
                lessThanOrEqualTo: playButton.topAnchor,
                constant: -Theme.Spacing.s
            ),

            playButton.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            playButton.widthAnchor.constraint(
                equalTo: safe.widthAnchor,
                multiplier: Theme.Layout.primaryButtonWidthRatio
            ),
            playPreferredHeight,
            playButton.heightAnchor.constraint(
                greaterThanOrEqualToConstant: Theme.Layout.primaryButtonHeight
            ),
            playButton.bottomAnchor.constraint(
                equalTo: safe.bottomAnchor,
                constant: -Theme.Spacing.xl
            ),
        ])
    }

    private func setupActions() {
        playButton.addTarget(self, action: #selector(handlePlayTapped), for: .touchUpInside)
        settingsButton.addTarget(self, action: #selector(handleSettingsTapped), for: .touchUpInside)
    }

    // MARK: - Data

    private func refreshBestScore() {
        let best = store.bestScore
        bestScoreValueLabel.text = best.formatted()
        bestScoreStack.accessibilityLabel = Strings.bestScoreLabel(best)
    }

    // MARK: - Actions

    @objc private func handlePlayTapped() {
        navigationController?.pushViewController(GameViewController(), animated: true)
    }

    @objc private func handleSettingsTapped() {
        navigationController?.pushViewController(SettingsViewController(), animated: true)
    }
}
