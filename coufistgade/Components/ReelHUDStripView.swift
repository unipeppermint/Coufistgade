//
//  ReelHUDStripView.swift
//  coufistgade
//
//  对局中的三个轮子，连同「还差多少」。见 GAMEPLAY §27、UI_DESIGN §13a。
//
//  为什么轮子要在对局里出现，而不只在结算页：三个维度的当前值玩家在 HUD 上本来
//  就看得见（得分实时显示，连击也一样），所以结算时再揭晓一遍并没有悬念可言——
//  而悬念也不该用随机数去造。正确的做法是把已知变成压力：「还差 3 次命中就到
//  ⭐️」是个能在最后十秒主动去争的目标，比回合结束后翻一张成绩单强得多。
//
//  **高度必须恒定。** HUD 的高度决定物理天花板的位置（GameScreenView
//  .playableInsets），所以「还差多少」那行字在内容变化时不能改变自身高度，否则
//  天花板会在对局中上下移动，把球推来推去。这和 GameHUDView 里 combo 行用
//  alpha 0 而不是 isHidden 是同一条约束。
//

import UIKit

final class ReelHUDStripView: UIView {

    enum AccessibilityID {
        static let strip = "game.reelStrip"
        static func slot(_ index: Int) -> String { "game.reelSlot.\(index)" }
        static func shortfall(_ index: Int) -> String { "game.reelShortfall.\(index)" }
    }

    /// 一列：符号窗 + 还差多少。
    ///
    /// 对局中不显示维度标题（HITS / CHAIN / SCORE）——那三个词会让这一条占掉两行，
    /// 而天花板每一点都是从可玩区域里扣的。符号本身与位置足以区分，无障碍标签里
    /// 也带着维度名。
    private final class Column: UIView {

        let reelWindow: ReelWindowView
        private let shortfallLabel = UILabel()
        private let dimension: ReelDimension

        init(dimension: ReelDimension, index: Int) {
            self.dimension = dimension
            self.reelWindow = ReelWindowView(size: .compact)
            super.init(frame: .zero)

            reelWindow.accessibilityIdentifier = AccessibilityID.slot(index)

            shortfallLabel.font = Theme.Typography.rounded(
                .caption2,
                weight: .semibold,
                // 上限压得比正文低：这行字只是个数字，放大它会挤掉可玩区域。
                maximumPointSize: Theme.Layout.reelShortfallHeight
            )
            shortfallLabel.textColor = UIColor(resource: .textSecondary)
            shortfallLabel.adjustsFontForContentSizeCategory = true
            shortfallLabel.textAlignment = .center
            shortfallLabel.accessibilityIdentifier = AccessibilityID.shortfall(index)
            // 不参与无障碍：整列由 reelWindow 的标签一句读完，这行会造成重复。
            shortfallLabel.isAccessibilityElement = false

            let stack = UIStackView(arrangedSubviews: [reelWindow, shortfallLabel])
            stack.axis = .vertical
            stack.alignment = .fill
            stack.spacing = 1
            stack.translatesAutoresizingMaskIntoConstraints = false
            addSubview(stack)

            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: topAnchor),
                stack.bottomAnchor.constraint(equalTo: bottomAnchor),
                stack.leadingAnchor.constraint(equalTo: leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: trailingAnchor),
                // 固定高度，见文件头：内容在「+13」与「✓」之间变，高度不能跟着变。
                shortfallLabel.heightAnchor.constraint(
                    equalToConstant: Theme.Layout.reelShortfallHeight
                ),
            ])
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("ReelHUDStripView.Column is code-only.")
        }

        /// 应用一个轮子的当前状态。
        ///
        /// 返回符号是否变了，让调用方决定要不要给反馈——跨档是这条 HUD 上唯一
        /// 值得一次回弹与一声提示的事件。
        @discardableResult
        func apply(slot: ReelSlot, shortfall: Int?, emphasis: ReelWindowView.Emphasis) -> Bool {
            let changed = reelWindow.symbol != slot.symbol
            reelWindow.symbol = slot.symbol
            reelWindow.apply(emphasis)

            if let shortfall, shortfall > 0 {
                shortfallLabel.text = ReelStrings.shortfall(shortfall)
                shortfallLabel.textColor = UIColor(resource: .textSecondary)
            } else {
                // 已经够到目标档。用对勾而不是清空文本：空字符串会让这行量成 0 高，
                // 固定高度约束虽然挡住了，但对勾同时也是有用的信息——这个维度已经
                // 不再拖后腿了。
                shortfallLabel.text = ReelStrings.shortfallMet
                shortfallLabel.textColor = UIColor(resource: .accent)
            }

            reelWindow.accessibilityLabel = ReelStrings.hudSlotLabel(slot, shortfall: shortfall)
            return changed
        }

        func reset() {
            reelWindow.symbol = .cherry
            reelWindow.apply(.neutral)
            shortfallLabel.text = ReelStrings.shortfallMet
            reelWindow.accessibilityLabel = nil
        }
    }

    private var columns: [Column] = []
    private let stack = UIStackView()

    init() {
        super.init(frame: .zero)

        columns = ReelDimension.allCases.enumerated().map { index, dimension in
            Column(dimension: dimension, index: index)
        }

        stack.axis = .horizontal
        // 三列等宽：轮子该是三个一样的格子。
        stack.distribution = .fillEqually
        stack.alignment = .fill
        stack.spacing = Theme.Spacing.xs / 2
        columns.forEach { stack.addArrangedSubview($0) }

        // 轮窗要有个最小宽度，否则它会缩到符号的固有宽度——那样三个格子看起来
        // 是圆的，读不出「轮子」。宽略大于高，是老虎机轮窗本来的比例。
        columns.forEach {
            $0.reelWindow.widthAnchor.constraint(
                greaterThanOrEqualToConstant: Theme.Layout.reelWindowCompactWidth
            ).isActive = true
        }

        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        accessibilityIdentifier = AccessibilityID.strip

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("ReelHUDStripView is code-only; this app uses no storyboards or nibs.")
    }

    // MARK: - 事件

    /// 应用一次进度更新。
    ///
    /// 返回**跨了档的那些维度**。调用方用它决定要不要给反馈：跨档是这条 HUD 上
    /// 唯一的事件，而每次命中都会调到这里（得分变了），绝大多数时候什么都没变。
    @discardableResult
    func apply(_ progress: ReelProgress) -> [ReelDimension] {
        let outcome = progress.outcome
        let lagging = Set(outcome.laggingDimensions)
        var advanced: [ReelDimension] = []

        // 没有奖励时谁都不标。
        //
        // 判据是「这一局现在赔不赔钱」，不是「有几个轮子在拖后腿」——齐平时三个
        // 轮子**全都**落在最低档，若按数量判断，⭐️⭐️⭐️ 反而一个都不会亮。
        //
        // 回合开头（0/0/0，三个都在 🍒）正是不赔钱的情形：此时把三个都描上边等于
        // 没说任何话。「还差多少」那三个数字仍然写着，目标不会因此消失。
        let marks = !outcome.isBlank

        for (column, slot) in zip(columns, outcome.slots) {
            let emphasis: ReelWindowView.Emphasis = if !marks {
                .neutral
            } else if outcome.isAligned {
                // 齐平在某个付钱的档位上：三个一起描亮，这是值得看见的状态。
                .aligned
            } else {
                lagging.contains(slot.dimension) ? .lagging : .neutral
            }
            let changed = column.apply(
                slot: slot,
                shortfall: progress.shortfall(for: slot.dimension),
                emphasis: emphasis
            )
            if changed { advanced.append(slot.dimension) }
        }
        return advanced
    }

    /// 给跨档的那一列一次回弹。
    func playAdvanceBounce(for dimensions: [ReelDimension]) {
        for dimension in dimensions {
            guard let index = ReelDimension.allCases.firstIndex(of: dimension) else { continue }
            columns[index].reelWindow.playSettleBounce()
        }
    }

    func reset() {
        columns.forEach { $0.reset() }
    }

    // MARK: - Inspection

    var displayedSymbols: [ReelSymbol] { columns.map(\.reelWindow.symbol) }
}
