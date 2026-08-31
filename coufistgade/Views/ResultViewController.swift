//
//  ResultViewController.swift
//  coufistgade
//
//  End-of-round summary (UI_DESIGN §13, GAMEPLAY §22).
//
//  Owns no game state — it is handed a RoundResult and displays it. Play Again
//  and Home are reported through closures so this screen knows nothing about the
//  navigation stack it sits in.
//

import UIKit

final class ResultViewController: UIViewController {

    enum AccessibilityID {
        static let scoreValue = "result.scoreValue"
        static let bestValue = "result.bestValue"
        static let comboValue = "result.comboValue"
        static let bestComboValue = "result.bestComboValue"
        static let newRecordBadge = "result.newRecord"
        static let playAgainButton = "result.playAgain"
        static let homeButton = "result.home"
    }

    private let result: RoundResult

    var onPlayAgain: (() -> Void)?
    var onHome: (() -> Void)?

    private let newRecordLabel = UILabel()
    private let scoreCaptionLabel = UILabel()
    private let scoreValueLabel = UILabel()
    private let bestRow = StatRow(caption: Strings.bestCaption, id: AccessibilityID.bestValue)
    private let comboRow = StatRow(caption: Strings.comboCaptionPlain, id: AccessibilityID.comboValue)
    private let bestComboRow = StatRow(caption: Strings.bestComboCaption, id: AccessibilityID.bestComboValue)
    private let playAgainButton = BouncyButton()
    private let homeButton = UIButton(type: .system)
    private let stack = UIStackView()

    private let prefersReducedMotion: () -> Bool

    init(
        result: RoundResult,
        prefersReducedMotion: @escaping () -> Bool = { MotionPreference.isReduced }
    ) {
        self.result = result
        self.prefersReducedMotion = prefersReducedMotion
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("ResultViewController is code-only; this app uses no storyboards or nibs.")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupActions()
        populate()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard result.isNewRecord else { return }
        celebrateRecord()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = UIColor(resource: .appBackground)

        newRecordLabel.text = Strings.newRecord
        newRecordLabel.font = Theme.Typography.rounded(
            .headline,
            weight: .heavy,
            maximumPointSize: Theme.Typography.MaxPointSize.caption
        )
        newRecordLabel.textColor = UIColor(resource: .accent)
        newRecordLabel.adjustsFontForContentSizeCategory = true
        newRecordLabel.textAlignment = .center
        newRecordLabel.accessibilityIdentifier = AccessibilityID.newRecordBadge
        newRecordLabel.isHidden = !result.isNewRecord

        scoreCaptionLabel.text = Strings.scoreCaption
        scoreCaptionLabel.font = Theme.Typography.rounded(
            .caption1,
            weight: .semibold,
            maximumPointSize: Theme.Typography.MaxPointSize.caption
        )
        scoreCaptionLabel.textColor = UIColor(resource: .textSecondary)
        scoreCaptionLabel.adjustsFontForContentSizeCategory = true
        scoreCaptionLabel.textAlignment = .center

        // The one number the player came here for, so it gets the display size.
        scoreValueLabel.font = Theme.Typography.numeric(
            .largeTitle,
            maximumPointSize: Theme.Typography.MaxPointSize.wordmark * 1.6
        )
        scoreValueLabel.textColor = UIColor(resource: .textPrimary)
        scoreValueLabel.adjustsFontForContentSizeCategory = true
        scoreValueLabel.textAlignment = .center
        scoreValueLabel.accessibilityIdentifier = AccessibilityID.scoreValue

        playAgainButton.setTitle(Strings.playAgain, for: .normal)
        playAgainButton.accessibilityIdentifier = AccessibilityID.playAgainButton

        var homeConfig = UIButton.Configuration.plain()
        homeConfig.baseForegroundColor = UIColor(resource: .textSecondary)
        homeButton.configuration = homeConfig
        homeButton.setTitle(Strings.home, for: .normal)
        homeButton.titleLabel?.adjustsFontForContentSizeCategory = true
        homeButton.accessibilityIdentifier = AccessibilityID.homeButton

        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = Theme.Spacing.s
        [
            newRecordLabel,
            scoreCaptionLabel,
            scoreValueLabel,
            comboRow,
            bestRow,
            bestComboRow,
        ].forEach { stack.addArrangedSubview($0) }
        // The score block and the actions are separate groups, so the actions sit
        // apart rather than reading as another statistic.
        stack.setCustomSpacing(Theme.Spacing.l, after: bestComboRow)
        [playAgainButton, homeButton].forEach { stack.addArrangedSubview($0) }
        stack.setCustomSpacing(0, after: scoreCaptionLabel)

        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
    }

    private func setupConstraints() {
        let safe = view.safeAreaLayoutGuide
        let buttonHeight = playAgainButton.heightAnchor.constraint(
            equalToConstant: Theme.Layout.primaryButtonHeight
        )
        buttonHeight.priority = .defaultHigh

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: safe.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: Theme.Spacing.l),
            stack.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -Theme.Spacing.l),
            stack.topAnchor.constraint(greaterThanOrEqualTo: safe.topAnchor, constant: Theme.Spacing.m),
            stack.bottomAnchor.constraint(
                lessThanOrEqualTo: safe.bottomAnchor,
                constant: -Theme.Spacing.m
            ),

            buttonHeight,
            homeButton.heightAnchor.constraint(
                greaterThanOrEqualToConstant: Theme.Layout.minimumTouchTarget
            ),
        ])
    }

    private func setupActions() {
        playAgainButton.addTarget(self, action: #selector(handlePlayAgain), for: .touchUpInside)
        homeButton.addTarget(self, action: #selector(handleHome), for: .touchUpInside)
    }

    private func populate() {
        scoreValueLabel.text = "\(result.score)"
        scoreValueLabel.accessibilityLabel = Strings.scoreLabel(result.score)
        comboRow.value = "\(result.roundCombo)"
        bestRow.value = "\(result.bestScore)"
        bestComboRow.value = "\(result.bestCombo)"
    }

    // MARK: - New record

    /// UI_DESIGN §14: scale and glow, kept restrained.
    ///
    /// No particle burst here — that would mean a SpriteKit view on a screen that
    /// otherwise needs none. The scale and glow carry it.
    private func celebrateRecord() {
        guard !prefersReducedMotion() else { return }

        newRecordLabel.layer.shadowColor = UIColor(resource: .accent).cgColor
        newRecordLabel.layer.shadowRadius = 12
        newRecordLabel.layer.shadowOpacity = 0.9
        newRecordLabel.layer.shadowOffset = .zero

        newRecordLabel.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
        newRecordLabel.alpha = 0
        UIView.animate(
            withDuration: 0.45,
            delay: 0.1,
            usingSpringWithDamping: 0.55,
            initialSpringVelocity: 0.4
        ) {
            self.newRecordLabel.transform = .identity
            self.newRecordLabel.alpha = 1
        }
    }

    // MARK: - Actions

    @objc private func handlePlayAgain() { onPlayAgain?() }
    @objc private func handleHome() { onHome?() }
}

/// A caption/value pair, used for the two secondary statistics.
private final class StatRow: UIView {

    private let captionLabel = UILabel()
    private let valueLabel = UILabel()

    var value: String? {
        get { valueLabel.text }
        set {
            valueLabel.text = newValue
            valueLabel.accessibilityLabel = "\(captionLabel.text ?? "") \(newValue ?? "")"
        }
    }

    init(caption: String, id: String) {
        super.init(frame: .zero)

        captionLabel.text = caption
        captionLabel.font = Theme.Typography.rounded(
            .subheadline,
            weight: .medium,
            maximumPointSize: Theme.Typography.MaxPointSize.caption
        )
        captionLabel.textColor = UIColor(resource: .textSecondary)
        captionLabel.adjustsFontForContentSizeCategory = true

        valueLabel.font = Theme.Typography.numeric(
            .subheadline,
            maximumPointSize: Theme.Typography.MaxPointSize.caption
        )
        valueLabel.textColor = UIColor(resource: .textPrimary)
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.textAlignment = .right
        valueLabel.accessibilityIdentifier = id

        let row = UIStackView(arrangedSubviews: [captionLabel, valueLabel])
        row.axis = .horizontal
        row.alignment = .firstBaseline
        row.distribution = .equalSpacing
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("StatRow is code-only.")
    }
}
