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
    private let scrollView = UIScrollView()

    private let prefersReducedMotion: () -> Bool
    private let audio: AudioPlaying
    private let haptics: HapticPlaying

    init(
        result: RoundResult,
        prefersReducedMotion: @escaping () -> Bool = { MotionPreference.isReduced },
        audio: AudioPlaying = SilentAudio(),
        haptics: HapticPlaying = SilentHaptics()
    ) {
        self.result = result
        self.prefersReducedMotion = prefersReducedMotion
        // 默认静音：这个页面在测试里被大量构造，不该每次都起音频引擎。
        // 真实调用点（GameViewController）会传入实际服务。
        self.audio = audio
        self.haptics = haptics
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("ResultViewController is code-only; this app uses no storyboards or nibs.")
    }

    // MARK: - 新解锁的成就

    /// 把本局新解锁的成就插到统计行下面。
    ///
    /// 一条都没有时整段不出现——空数组是常态（大多数局都不会解锁新东西），
    /// 所以这里不能留下标题或空隙。
    ///
    /// 复用 AchievementRowView，传 isUnlocked: true：这里显示的定义上都是刚
    /// 解锁的，不需要锁头也不需要进度条。
    private func addUnlockedAchievementsIfAny() {
        guard !result.unlockedAchievements.isEmpty else { return }

        // 插入到统计行之后、按钮之前。
        //
        // 不能用 addArrangedSubview：它总是追加到末尾，而按钮在 setupUI() 里已经
        // 先加进去了，结果成就行落到「再来一局」下面。
        guard var index = stack.arrangedSubviews.firstIndex(of: bestComboRow) else { return }
        index += 1

        let caption = UILabel()
        caption.text = AchievementStrings.newlyUnlockedCaption
        caption.font = Theme.Typography.rounded(
            .caption1,
            weight: .semibold,
            maximumPointSize: Theme.Typography.MaxPointSize.caption
        )
        caption.textColor = UIColor(resource: .accent)
        caption.adjustsFontForContentSizeCategory = true
        caption.textAlignment = .center
        stack.insertArrangedSubview(caption, at: index)
        index += 1

        var lastRow: UIView = caption
        for achievement in result.unlockedAchievements {
            let row = AchievementRowView(achievement: achievement, isUnlocked: true, progress: nil)
            stack.insertArrangedSubview(row, at: index)
            index += 1
            lastRow = row
        }

        // bestComboRow 原本带 .l 间距把统计与按钮分开；成就段插进来后，这段间距
        // 应当落在成就段之后，否则「新解锁」会和上面的统计粘在一起。
        stack.setCustomSpacing(Theme.Spacing.l, after: bestComboRow)
        stack.setCustomSpacing(Theme.Spacing.s, after: caption)
        stack.setCustomSpacing(Theme.Spacing.l, after: lastRow)
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
        // 在 viewDidAppear 而不是回合结束时播放：解锁提示应当和玩家看到成就的
        // 那一刻对齐，而不是提前到页面还没出现的时候。
        playUnlockFeedbackIfNeeded()
        guard result.isNewRecord else { return }
        celebrateRecord()
    }

    /// 本局有新解锁时播放提示音与震动。
    ///
    /// 只播一次，不按成就条数重复：一局解锁三条会响三声，听起来像故障。数量由
    /// 页面上列出的行数表达。
    private func playUnlockFeedbackIfNeeded() {
        guard !result.unlockedAchievements.isEmpty else { return }
        audio.playAchievementUnlock()
        haptics.playAchievementUnlock()
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

        // UI_DESIGN §13：Play Again 是主操作，Home 是次要操作。此前两者都是纯
        // 文字，视觉上没有主次之分。配置与首页 PLAY 一致，让「主操作」这件事
        // 在两个页面上是同一个样子。
        var playAgainConfig = UIButton.Configuration.filled()
        playAgainConfig.baseBackgroundColor = UIColor(resource: .accent)
        // 深色字压在 accent 上过 4.5:1；白字不过。
        playAgainConfig.baseForegroundColor = UIColor(resource: .appBackground)
        playAgainConfig.cornerStyle = .capsule
        playAgainConfig.attributedTitle = AttributedString(
            Strings.playAgain,
            attributes: AttributeContainer([
                .kern: 2,
                .font: Theme.Typography.rounded(
                    .headline,
                    weight: .bold,
                    maximumPointSize: Theme.Typography.MaxPointSize.buttonLabel
                ),
            ])
        )
        playAgainButton.configuration = playAgainConfig
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

        // 内容装进滚动视图：统计行是固定的六行，但「新解锁的成就」段长度不定，
        // 叠上大号 Dynamic Type 后总高度会超出屏幕，此前底部的「回主页」会被裁掉。
        //
        // 不加 alwaysBounceVertical：内容装得下时这一页应当和原来一样是静止的，
        // 回弹会让它看起来像个列表。
        scrollView.alwaysBounceVertical = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
    }

    private func setupConstraints() {
        let safe = view.safeAreaLayoutGuide
        let buttonHeight = playAgainButton.heightAnchor.constraint(
            equalToConstant: Theme.Layout.primaryButtonHeight
        )
        buttonHeight.priority = .defaultHigh

        // 内容装得下时仍然居中（和加滚动之前一样），装不下时才滚动：
        // content guide 高度低优先级等于视口高度，被下面两条必需的边距不等式顶开。
        let contentFillsViewport = scrollView.contentLayoutGuide.heightAnchor.constraint(
            equalTo: scrollView.frameLayoutGuide.heightAnchor
        )
        contentFillsViewport.priority = .defaultLow

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safe.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: safe.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            contentFillsViewport,
            stack.centerYAnchor.constraint(equalTo: scrollView.contentLayoutGuide.centerYAnchor),
            stack.topAnchor.constraint(
                greaterThanOrEqualTo: scrollView.contentLayoutGuide.topAnchor,
                constant: Theme.Spacing.m
            ),
            scrollView.contentLayoutGuide.bottomAnchor.constraint(
                greaterThanOrEqualTo: stack.bottomAnchor,
                constant: Theme.Spacing.m
            ),
            stack.leadingAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.leadingAnchor,
                constant: Theme.Spacing.l
            ),

            // 宽度来自视口，不能来自内容：横向绑 frameLayoutGuide，否则标签换行
            // 与内容宽度互为因果。
            stack.widthAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.widthAnchor,
                constant: -Theme.Spacing.l * 2
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
        addUnlockedAchievementsIfAny()
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
