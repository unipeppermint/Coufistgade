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
    /// 结算转轴（GAMEPLAY §27）。本局没有转轴结果时不会被插进视图树。
    private let reelPanel = ReelPanelView()

    private let prefersReducedMotion: () -> Bool
    private let audio: AudioPlaying
    private let haptics: HapticPlaying
    private let announcer: Announcer

    /// 爬分用的计时器。存下来是为了在页面消失时停掉——玩家可能在爬分途中就点了
    /// 「再来一局」。
    private var countUpTimer: Timer?

    init(
        result: RoundResult,
        prefersReducedMotion: @escaping () -> Bool = { MotionPreference.isReduced },
        audio: AudioPlaying = SilentAudio(),
        haptics: HapticPlaying = SilentHaptics(),
        announcer: Announcer = Announcer()
    ) {
        self.result = result
        self.prefersReducedMotion = prefersReducedMotion
        // 默认静音：这个页面在测试里被大量构造，不该每次都起音频引擎。
        // 真实调用点（GameViewController）会传入实际服务。
        self.audio = audio
        self.haptics = haptics
        self.announcer = announcer
        super.init(nibName: nil, bundle: nil)
    }

    deinit {
        countUpTimer?.invalidate()
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
        // 转轴先揭晓，成就与破纪录随后——顺序即因果：奖励分要先落进总分，
        // 「新纪录」才有理由出现。
        revealReelsIfNeeded()
        // 在 viewDidAppear 而不是回合结束时播放：解锁提示应当和玩家看到成就的
        // 那一刻对齐，而不是提前到页面还没出现的时候。
        playUnlockFeedbackIfNeeded()
        guard result.isNewRecord else { return }
        celebrateRecord()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 玩家可能在爬分途中就点了「再来一局」。计时器必须停，否则它会继续改写
        // 一个已经离场的标签。
        countUpTimer?.invalidate()
        countUpTimer = nil
    }

    // MARK: - 转轴

    /// 播一次转轴揭晓，收尾时把总分爬上去。
    ///
    /// 结果早在回合结束时就定好了（GameViewController 算的），这里只负责呈现——
    /// 动画不改变任何数值。
    private func revealReelsIfNeeded() {
        guard let outcome = result.reelOutcome else { return }

        reelPanel.reveal(
            outcome,
            audio: audio,
            haptics: haptics,
            reducedMotion: prefersReducedMotion()
        ) { [weak self] in
            self?.countUpScore(to: self?.result.score ?? 0)
            self?.announceReelOutcome(outcome)
        }
    }

    /// 总分从对局分爬到含奖励的总分。
    ///
    /// 这是奖励分的兑现时刻：没有这一下，那笔奖励只是页面上多出来的一行字，
    /// 玩家不会觉得它是自己的分。
    private func countUpScore(to finalScore: Int) {
        let start = startingScore
        guard finalScore > start else {
            // 没有可爬的（奖励为 0），直接确保标签是终值。
            setScoreLabel(finalScore)
            return
        }

        guard !prefersReducedMotion() else {
            // 降级：直接给终值。爬分是纯动效，去掉它不损失任何信息。
            setScoreLabel(finalScore)
            return
        }

        let steps = GameConfiguration.Reels.scoreCountUpSteps
        let interval = GameConfiguration.Reels.scoreCountUpDuration / Double(steps)
        var step = 0

        countUpTimer?.invalidate()
        countUpTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) {
            [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            step += 1
            let progress = Double(step) / Double(steps)
            // 末步直接落在终值上，不靠插值凑——浮点数在这里差 1 分都会很显眼。
            let value = step >= steps
                ? finalScore
                : start + Int((Double(finalScore - start) * progress).rounded())
            self.setScoreLabel(value)

            guard step >= steps else { return }
            timer.invalidate()
            self.countUpTimer = nil
        }
    }

    /// 把转轴结果播报给 VoiceOver。
    ///
    /// 用 announceImmediately：这一页刚出现时成就解锁可能刚播过一句，而转轴的
    /// 奖励分是玩家必须知道的——它改变了上面那个总分。
    private func announceReelOutcome(_ outcome: ReelOutcome) {
        guard !outcome.isBlank else { return }
        if outcome.isAligned {
            announcer.announceImmediately(
                ReelStrings.lineAnnouncement(symbol: outcome.floorSymbol, bonus: outcome.bonus)
            )
        } else {
            announcer.announceImmediately(ReelStrings.bonusAnnouncement(outcome.bonus))
        }
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
        var arranged: [UIView] = [
            newRecordLabel,
            scoreCaptionLabel,
            scoreValueLabel,
        ]
        // 转轴紧贴在总分下面：它要改的就是上面那个数，两者中间不该隔着别的统计。
        //
        // 本局没有转轴结果时整块不插入，而不是插入后隐藏——旧的 RoundResult
        // （默认 reelOutcome 为 nil）在这一页上应当和加转轴之前一模一样。
        if result.reelOutcome != nil {
            arranged.append(reelPanel)
        }
        arranged.append(contentsOf: [comboRow, bestRow, bestComboRow])
        arranged.forEach { stack.addArrangedSubview($0) }
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
        // 起始值是**对局分**，不是总分：转轴揭晓完毕后再爬到含奖励的总分，
        // 那一下才是奖励分的兑现（见 revealReelsIfNeeded）。
        //
        // 没有转轴结果时 baseScore == score，所以这一页和加转轴之前完全一样。
        setScoreLabel(startingScore)
        comboRow.value = "\(result.roundCombo)"
        bestRow.value = "\(result.bestScore)"
        bestComboRow.value = "\(result.bestCombo)"
        addUnlockedAchievementsIfAny()

        // 终态先摆上，让页面在动画开始前就是完整的：VoiceOver 用户与截图都不该
        // 看到一个空面板。reveal 会从这个状态接手。
        if let outcome = result.reelOutcome {
            reelPanel.configure(outcome)
        }
    }

    /// 大号总分的起点。
    ///
    /// 只有在真的要爬分时才从 baseScore 起：奖励为 0 时爬分是从同一个数爬到同一个
    /// 数，白跑一趟计时器。
    private var startingScore: Int {
        guard let outcome = result.reelOutcome, !outcome.isBlank else { return result.score }
        return result.baseScore
    }

    private func setScoreLabel(_ score: Int) {
        scoreValueLabel.text = "\(score)"
        scoreValueLabel.accessibilityLabel = Strings.scoreLabel(score)
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
