//
//  ReelPanelView.swift
//  coufistgade
//
//  结算页上的三个轮子（UI_DESIGN §13a，GAMEPLAY §27）。
//
//  纯 UIKit，不是 SpriteKit：这一页没有物理世界，为三个滚动的标签起一个 SKView
//  是不成比例的。滚动本身就是换文字加一次形变，UIView 动画足够。
//
//  两条入口分开：`configure(_:)` 直接呈现终态，`reveal(...)` 才播揭晓动画。
//  测试走前者，于是不必等计时器；真实调用点走后者。这也让 Reduce Motion 的处理
//  变成一行——降级就是只调 configure。
//
//  每个轮子是一个独立的无障碍元素，读作「命中 12，星」：把数值一起读出来，玩家
//  才能反推出阈值，而不是只知道落了个符号。
//

import UIKit

final class ReelPanelView: UIView {

    enum AccessibilityID {
        static let panel = "result.reelPanel"
        static let bonusValue = "result.reelBonus"
        static let lineCaption = "result.reelLine"
        /// 单个轮子。带序号，从 0 起，顺序即 ReelDimension.allCases。
        static func slot(_ index: Int) -> String { "result.reelSlot.\(index)" }
    }

    /// 一列：维度标题 + 符号窗口。
    private final class ReelColumn: UIView {

        private let captionLabel = UILabel()
        private let symbolLabel = UILabel()
        private let symbolWindow = UIView()

        /// 当前显示的符号。滚动过程中会被反复改写。
        var symbol: ReelSymbol = .cherry {
            didSet { symbolLabel.text = symbol.glyph }
        }

        init(dimension: ReelDimension, accessibilityID: String) {
            super.init(frame: .zero)

            captionLabel.text = ReelStrings.dimensionCaption(dimension)
            captionLabel.font = Theme.Typography.rounded(
                .caption2,
                weight: .semibold,
                maximumPointSize: Theme.Typography.MaxPointSize.caption
            )
            captionLabel.textColor = UIColor(resource: .textSecondary)
            captionLabel.adjustsFontForContentSizeCategory = true
            captionLabel.textAlignment = .center

            // 符号是 emoji，跟随 Dynamic Type 但设上限：轮窗是固定尺寸的方块，
            // 字形无限放大会顶出窗口。
            symbolLabel.font = Theme.Typography.rounded(
                .title1,
                weight: .regular,
                maximumPointSize: Theme.Layout.reelSymbolMaxPointSize
            )
            symbolLabel.adjustsFontForContentSizeCategory = true
            symbolLabel.textAlignment = .center
            symbolLabel.text = symbol.glyph

            symbolWindow.backgroundColor = UIColor(resource: .appBackground)
            symbolWindow.layer.cornerRadius = Theme.Radius.button
            symbolWindow.layer.cornerCurve = .continuous
            // 轮窗的边，让三个格子读起来像三个轮子而不是三段文字。
            // 用和 .neutral 同一组常量，否则「重置后的样子」和「初始的样子」会分叉。
            symbolWindow.layer.borderWidth = Self.defaultBorderWidth
            symbolWindow.layer.borderColor = Self.defaultBorderColor

            symbolLabel.translatesAutoresizingMaskIntoConstraints = false
            symbolWindow.addSubview(symbolLabel)

            let stack = UIStackView(arrangedSubviews: [captionLabel, symbolWindow])
            stack.axis = .vertical
            stack.spacing = Theme.Spacing.xs / 2
            stack.alignment = .fill
            stack.translatesAutoresizingMaskIntoConstraints = false
            addSubview(stack)

            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: topAnchor),
                stack.bottomAnchor.constraint(equalTo: bottomAnchor),
                stack.leadingAnchor.constraint(equalTo: leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: trailingAnchor),

                // 窗口至少和触控目标一样高，且不低于自身内容——大号 Dynamic Type
                // 下由内容顶开。
                symbolWindow.heightAnchor.constraint(
                    greaterThanOrEqualToConstant: Theme.Layout.reelWindowMinimumHeight
                ),
                symbolLabel.centerXAnchor.constraint(equalTo: symbolWindow.centerXAnchor),
                symbolLabel.centerYAnchor.constraint(equalTo: symbolWindow.centerYAnchor),
                symbolLabel.topAnchor.constraint(
                    greaterThanOrEqualTo: symbolWindow.topAnchor,
                    constant: Theme.Spacing.xs
                ),
                symbolWindow.bottomAnchor.constraint(
                    greaterThanOrEqualTo: symbolLabel.bottomAnchor,
                    constant: Theme.Spacing.xs
                ),
            ])

            // 整列读作一句，见文件头。
            isAccessibilityElement = true
            accessibilityIdentifier = accessibilityID
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("ReelColumn is code-only.")
        }

        /// 定住时的一下回弹。
        func playSettleBounce() {
            let overshoot = GameConfiguration.Reels.settleOvershoot
            symbolWindow.transform = CGAffineTransform(scaleX: overshoot, y: overshoot)
            UIView.animate(
                withDuration: GameConfiguration.Reels.settleDuration,
                delay: 0,
                usingSpringWithDamping: 0.5,
                initialSpringVelocity: 0.6
            ) {
                self.symbolWindow.transform = .identity
            }
        }

        /// 窗口的三种强调状态（GAMEPLAY §27）。
        ///
        /// 分三种而不是一个布尔，因为按最低档赔付之后，屏幕上要表达的事情多了一件：
        /// 哪几个轮子在**拖住**赔付。那几个描暗一点的边，是「往这儿推」的指引。
        enum Emphasis {
            /// 三轮齐平：全部描亮。
            case aligned
            /// 落在最低档，正是它决定了这次赔多少。
            case lagging
            /// 比最低档高，对赔付没有影响。
            case neutral
        }

        func apply(_ emphasis: Emphasis) {
            switch emphasis {
            case .aligned:
                symbolWindow.layer.borderColor = UIColor(resource: .accent).cgColor
                symbolWindow.layer.borderWidth = 2
            case .lagging:
                // 同一个强调色但压暗：它是要被推上去的那个，不是成就。
                symbolWindow.layer.borderColor = UIColor(resource: .accent)
                    .withAlphaComponent(0.5).cgColor
                symbolWindow.layer.borderWidth = 2
            case .neutral:
                symbolWindow.layer.borderColor = Self.defaultBorderColor
                symbolWindow.layer.borderWidth = Self.defaultBorderWidth
            }
        }

        private static let defaultBorderWidth: CGFloat = 1
        private static var defaultBorderColor: CGColor {
            UIColor(resource: .textSecondary).withAlphaComponent(0.25).cgColor
        }
    }

    // MARK: - 视图

    private var columns: [ReelColumn] = []
    private let bonusCaptionLabel = UILabel()
    private let bonusValueLabel = UILabel()
    private let hintLabel = UILabel()
    private let columnStack = UIStackView()
    private let rootStack = UIStackView()

    /// 每次揭晓自增。排队中的锁定回调靠比对它决定自己是否已作废。
    ///
    /// 用一个自增计数而不是持有计时器：锁定是三次一次性的延时调用，没有需要反复
    /// 触发的循环。玩家在揭晓途中点「再来一局」时，token 一变，那几次排队中的调用
    /// 会各自静默退出，不必逐个 invalidate，也不会漏掉一个。
    private var revealToken = 0

    /// 是否有一次揭晓正在进行中。
    ///
    /// 单独一个标志，而不是从 token 推断：token 只说「第几次」，说不了「有没有在
    /// 跑」。测试要断言的是后者。
    private var isRevealing = false

    private var outcome: ReelOutcome?

    // MARK: - 生命周期

    init() {
        super.init(frame: .zero)
        setupUI()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("ReelPanelView is code-only; this app uses no storyboards or nibs.")
    }

    // deinit 不再需要：锁定用的是 asyncAfter + [weak self]，视图消失后那几次调用
    // 拿到 nil 就自己退出，没有计时器持有 self、也没有东西需要显式停掉。

    // MARK: - Setup

    private func setupUI() {
        columns = ReelDimension.allCases.enumerated().map { index, dimension in
            ReelColumn(dimension: dimension, accessibilityID: AccessibilityID.slot(index))
        }

        columnStack.axis = .horizontal
        // 三列等宽：轮子该是三个一样的格子，宽度不能随标题长短变化。
        columnStack.distribution = .fillEqually
        columnStack.alignment = .fill
        columnStack.spacing = Theme.Spacing.xs
        columns.forEach { columnStack.addArrangedSubview($0) }

        bonusCaptionLabel.font = Theme.Typography.rounded(
            .caption1,
            weight: .semibold,
            maximumPointSize: Theme.Typography.MaxPointSize.caption
        )
        bonusCaptionLabel.textColor = UIColor(resource: .accent)
        bonusCaptionLabel.adjustsFontForContentSizeCategory = true
        bonusCaptionLabel.textAlignment = .center
        bonusCaptionLabel.accessibilityIdentifier = AccessibilityID.lineCaption
        bonusCaptionLabel.numberOfLines = 0

        bonusValueLabel.font = Theme.Typography.numeric(
            .title3,
            maximumPointSize: Theme.Typography.MaxPointSize.scoreValue
        )
        bonusValueLabel.textColor = UIColor(resource: .accent)
        bonusValueLabel.adjustsFontForContentSizeCategory = true
        bonusValueLabel.textAlignment = .center
        bonusValueLabel.accessibilityIdentifier = AccessibilityID.bonusValue

        // 什么都没中时显示规则，而不是显示「+0」。
        //
        // 这是这套机制唯一的说明书：轮子第一次出现在玩家面前时他并不知道要凑什么，
        // 而没中恰好是最该解释规则的时刻。中了就不必解释了。
        hintLabel.text = ReelStrings.hint
        hintLabel.font = Theme.Typography.rounded(
            .caption2,
            weight: .regular,
            maximumPointSize: Theme.Typography.MaxPointSize.caption
        )
        hintLabel.textColor = UIColor(resource: .textSecondary)
        hintLabel.adjustsFontForContentSizeCategory = true
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 0

        rootStack.axis = .vertical
        rootStack.alignment = .fill
        rootStack.spacing = Theme.Spacing.xs
        [columnStack, bonusCaptionLabel, bonusValueLabel, hintLabel]
            .forEach { rootStack.addArrangedSubview($0) }
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rootStack)

        // 面板本身不是无障碍元素——每列各自是，见文件头。这里只给个容器标签，
        // 让 VoiceOver 用户知道这一段是什么。
        accessibilityIdentifier = AccessibilityID.panel
        accessibilityLabel = ReelStrings.panelLabel
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: topAnchor),
            rootStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            rootStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            rootStack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    // MARK: - 终态

    /// 直接呈现结果，不播动画。
    ///
    /// 测试与 Reduce Motion 都走这里。`reveal` 内部也以它收尾，所以「动画播完的
    /// 样子」和「不播动画的样子」由同一段代码产生，不会分叉。
    func configure(_ outcome: ReelOutcome) {
        // 作废正在进行的揭晓：token 一变，排队中的锁定回调会各自退出。
        revealToken += 1
        isRevealing = false
        self.outcome = outcome

        for (column, slot) in zip(columns, outcome.slots) {
            column.symbol = slot.symbol
            column.accessibilityLabel = ReelStrings.slotLabel(slot)
        }

        // 三种状态，不是两种。按最低档赔付之后，「不同档但仍有奖励」是个独立的
        // 情形——它既不是齐平，也不是什么都没有。
        let lagging = Set(outcome.laggingDimensions)
        for (column, slot) in zip(columns, outcome.slots) {
            if outcome.isAligned {
                column.apply(.aligned)
            } else {
                column.apply(lagging.contains(slot.dimension) ? .lagging : .neutral)
            }
        }

        if outcome.isBlank {
            // 没有奖励时不显示文案，也不显示「+0」——「+0」读起来像个 bug。
            // 拖住的那几个轮子仍然描暗边：此时它们正是把奖励压在 0 的原因。
            bonusCaptionLabel.isHidden = true
        } else if outcome.isAligned {
            bonusCaptionLabel.text = ReelStrings.lineCaption(outcome.floorSymbol)
            bonusCaptionLabel.isHidden = false
        } else {
            // 赔付由最低那一档决定，所以文案报的是那一档。
            bonusCaptionLabel.text = ReelStrings.floorCaption(outcome.floorSymbol)
            bonusCaptionLabel.isHidden = false
        }

        bonusValueLabel.isHidden = outcome.isBlank
        bonusValueLabel.text = outcome.isBlank ? nil : ReelStrings.bonusValue(outcome.bonus)

        // 规则说明只在没有奖励时出现，见 setupUI 里的说明。
        hintLabel.isHidden = !outcome.isBlank
    }

    // MARK: - 揭晓

    /// 播一次揭晓：三个轮子依次滚动、定住，最后揭出奖励分。
    ///
    /// - Parameters:
    ///   - outcome: 要揭晓的结果。已经定好了，动画不改变它。
    ///   - audio: 定住与成线的提示音。
    ///   - haptics: 同上的触感。
    ///   - reducedMotion: 为真时直接呈现终态并播一次成线音，不滚动。
    ///   - completion: 全部揭晓完毕后调用。用于播报无障碍提示。
    func reveal(
        _ outcome: ReelOutcome,
        audio: AudioPlaying,
        haptics: HapticPlaying,
        reducedMotion: Bool,
        completion: (() -> Void)? = nil
    ) {
        // 先把终态算出来但不显示，滚动过程中显示的是别的符号。
        self.outcome = outcome

        guard !reducedMotion else {
            // 降级路径：不滚动，但**保留声音与触感**。Reduce Motion 是对动效的
            // 偏好，不是对反馈的偏好——把提示音一起去掉会让这一页在无障碍设置下
            // 变得毫无回应。
            configure(outcome)
            playOutcomeFeedback(outcome, audio: audio, haptics: haptics)
            completion?()
            return
        }

        // 起始状态：符号**立刻就是终值**，奖励行还不出现。
        //
        // 不再滚动（原先这里让三列乱转 0.9 秒再落回终值）。轮子整局都在 HUD 上，
        // 玩家在回合结束前就知道三个符号是什么——此时再转一遍不只是穿帮，更糟的是
        // 它读起来像「结果是现在才定的」，而这套机制的全部前提恰恰是结果由这一局
        // 的表现决定、早已确定（见 ReelOutcome 顶部）。
        //
        // 保留的是节奏：三列依次「锁定」，各给一次回弹与一声提示。悬念没了，
        // 但那本来也不该由假装的随机过程提供。
        bonusCaptionLabel.isHidden = true
        bonusValueLabel.isHidden = true
        hintLabel.isHidden = true
        for (column, slot) in zip(columns, outcome.slots) {
            // 无障碍标签一开始就设成终值：VoiceOver 用户不该被滚动过程中的中间态
            // 干扰，他们要的是结果。
            column.accessibilityLabel = ReelStrings.slotLabel(slot)
        }

        let config = GameConfiguration.Reels.self

        // 用一个自增的 token 而不是持有计时器：锁定是三次一次性的延时调用，没有
        // 需要反复触发的循环。玩家在揭晓途中点「再来一局」时，token 变化会让排队
        // 中的那几次调用自己作废，不必逐个 invalidate。
        revealToken += 1
        let token = revealToken
        isRevealing = true

        for (index, column) in columns.enumerated() {
            let slot = outcome.slots[index]
            let delay = Double(index) * config.spinStagger

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.revealToken == token else { return }
                // 符号已经是终值了（上面设过），这里只做强调——回弹加一声。
                column.playSettleBounce()
                audio.playReelSettle(slot.symbol)
                haptics.playReelSettle()

                // 最后一列锁完才揭奖励，由同一条链保证顺序。
                guard index == self.columns.count - 1 else { return }
                self.revealBonus(
                    outcome,
                    token: token,
                    audio: audio,
                    haptics: haptics,
                    completion: completion
                )
            }
        }
    }

    /// 三轮锁完之后，揭出奖励分。
    ///
    /// 也要收 token：这一段在延时之后才跑，若玩家正好在这段延时里点了「再来一局」，
    /// 没有 token 检查就会给一个已经作废的结果补上奖励行。
    private func revealBonus(
        _ outcome: ReelOutcome,
        token: Int,
        audio: AudioPlaying,
        haptics: HapticPlaying,
        completion: (() -> Void)?
    ) {
        DispatchQueue.main.asyncAfter(
            deadline: .now() + GameConfiguration.Reels.bonusRevealDelay
        ) { [weak self] in
            guard let self, self.revealToken == token else { return }
            // 终态由 configure 统一给出，见它的注释。它同时会把 isRevealing 置回
            // false —— 揭晓到这里就结束了。
            self.configure(outcome)

            if !outcome.isBlank {
                self.bonusValueLabel.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
                self.bonusValueLabel.alpha = 0
                UIView.animate(
                    withDuration: GameConfiguration.Reels.settleDuration,
                    delay: 0,
                    usingSpringWithDamping: 0.55,
                    initialSpringVelocity: 0.5
                ) {
                    self.bonusValueLabel.transform = .identity
                    self.bonusValueLabel.alpha = 1
                }
            }

            self.playAlignmentFeedbackIfNeeded(outcome, audio: audio, haptics: haptics)
            completion?()
        }
    }

    /// 三轮齐平时的额外反馈。只有高档齐平才给，见配置里 `celebratedAlignments`。
    ///
    /// 齐平不额外加钱（见 ReelOutcome 顶部），所以这一声就是它全部的回报——
    /// 「三个维度推到同一档」这件事本身值得被听见。
    private func playAlignmentFeedbackIfNeeded(
        _ outcome: ReelOutcome,
        audio: AudioPlaying,
        haptics: HapticPlaying
    ) {
        guard outcome.isAligned,
              GameConfiguration.Reels.celebratedAlignments.contains(outcome.floorSymbol)
        else { return }
        audio.playReelLine()
        haptics.playReelLine()
    }

    /// Reduce Motion 下的一次性反馈：没有逐列定住，所以只给齐平那一下。
    private func playOutcomeFeedback(
        _ outcome: ReelOutcome,
        audio: AudioPlaying,
        haptics: HapticPlaying
    ) {
        playAlignmentFeedbackIfNeeded(outcome, audio: audio, haptics: haptics)
    }

    // spinningSymbol 已删除。它为滚动过程生成中间符号，而现在没有滚动过程——
    // 符号一开始就是终值，三列只是依次锁定（见 reveal 里的说明）。

    #if DEBUG
    /// 揭晓是否还在进行。测试用它确认揭晓已被作废或已同步完成。
    var debugIsRevealing: Bool { isRevealing }
    #endif
}
