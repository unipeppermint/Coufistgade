//
//  ReelEvaluator.swift
//  coufistgade
//
//  把一局成绩判成三个轮子的结果。见 docs/GAMEPLAY.md §27。
//
//  纯逻辑：不碰 SpriteKit、不碰 UIKit、不读时钟、**不取随机数**。同一个
//  RoundSummary 进来永远得到同一个 ReelOutcome 出去——这条由
//  ReelEvaluatorTests 直接断言，因为它既是玩法设计的核心，也是这个功能能过
//  App Store 分级问卷的前提（见 ReelOutcome 顶部说明）。
//
//  两条入口：
//  - `evaluate` 判一局的最终结果，结算时用。
//  - `progress` 在此之上加「离下一档还差多少」，对局中 HUD 用。
//
//  也是无状态的：轮子只看当下这三个数，不看它们是怎么到那儿的。这一点是刻意的
//  ——路径相关的规则（比如「途中攒下的线」）会让结果无法从 RoundSummary 复算，
//  预览、测试与结算就得各自留一份历史。
//

import Foundation

struct ReelEvaluator {

    /// 阈值表。可注入，让测试能用自造的表验证边界，而不必迁就正式数值。
    private let thresholds: [ReelDimension: [(minimumValue: Int, symbol: ReelSymbol)]]
    private let bonus: (ReelSymbol) -> Int

    /// `bonus` 用 nil 而不是直接写默认值。
    ///
    /// 项目开着 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`，而默认参数表达式是在
    /// init 的隔离域**之外**求值的——把 `GameConfiguration.Reels.bonus(for:)`
    /// 写成默认值会取到一个 main-actor 方法的引用，于是编译器警告。
    /// 挪进函数体就没这个问题：这里已经在 main actor 上了。
    ///
    /// `thresholds` 不受影响，因为读一个 static let 常量本身是安全的。
    init(
        thresholds: [ReelDimension: [(minimumValue: Int, symbol: ReelSymbol)]]
            = GameConfiguration.Reels.thresholds,
        bonus: ((ReelSymbol) -> Int)? = nil
    ) {
        self.thresholds = thresholds
        self.bonus = bonus ?? { GameConfiguration.Reels.bonus(for: $0) }
    }

    // MARK: - 结算

    /// 结算一局的转轴。
    ///
    /// 传进来的 `summary.score` 必须是**加成前**的分数。转轴的奖励分随后叠加到
    /// 总分上，若这里读的是已含加成的分数，轮子就在读自己的输出，成环。
    func evaluate(_ summary: RoundSummary) -> ReelOutcome {
        // 顺序即 allCases，也就是屏幕上从左到右的排列。写成 map 而不是手列三条，
        // 是为了将来加第四个维度时这里不用改。
        let slots = ReelDimension.allCases.map { dimension in
            let value = value(of: dimension, in: summary)
            return ReelSlot(dimension: dimension, symbol: symbol(for: dimension, value: value), value: value)
        }

        // 最低档决定赔付。见 ReelOutcome 顶部：这是为了让推高任何一个维度永远
        // 不会降低奖励，否则终局会出现「停手保住线」的最优解。
        let floor = slots.map(\.symbol).min { $0.tier < $1.tier } ?? .cherry

        return ReelOutcome(slots: slots, floorSymbol: floor, bonus: bonus(floor))
    }

    // MARK: - 对局中

    /// 当前结果，加上离下一档还差多少。
    ///
    /// 目标是**比最低档高一级**的那个符号：只有把最低的那个（或那几个）推上去才
    /// 能提高奖励，已经更高的轮子再涨也不加钱。
    func progress(_ summary: RoundSummary) -> ReelProgress {
        let outcome = evaluate(summary)
        guard let target = outcome.floorSymbol.next else {
            // 已在顶档，没有可争的下一档了。
            return ReelProgress(outcome: outcome, target: nil, shortfalls: [:])
        }

        var shortfalls: [ReelDimension: Int] = [:]
        for slot in outcome.slots {
            // 已经够到目标档的轮子不进表——它们显示为「已达成」。
            guard slot.symbol.tier < target.tier else { continue }
            guard let required = minimumValue(for: target, in: slot.dimension) else { continue }
            shortfalls[slot.dimension] = max(0, required - slot.value)
        }
        return ReelProgress(outcome: outcome, target: target, shortfalls: shortfalls)
    }

    /// 某个维度要落到某个符号，至少需要多少数值。
    ///
    /// 阈值表的反查。表里没有这一档时返回 nil——只可能来自测试自造的表。
    func minimumValue(for symbol: ReelSymbol, in dimension: ReelDimension) -> Int? {
        thresholds[dimension]?.first { $0.symbol == symbol }?.minimumValue
    }

    // MARK: - 取值

    private func value(of dimension: ReelDimension, in summary: RoundSummary) -> Int {
        switch dimension {
        case .hits: summary.hits
        case .combo: summary.highestCombo
        case .score: summary.score
        }
    }

    /// 数值落到哪个符号。
    ///
    /// 表按高档在前排列，第一条够到的即为结果——和
    /// `ComboManager` 查 `multiplierLadder` 是同一个查法。
    ///
    /// 表缺失或全表都够不到时退回最低档：轮子必须转出一个符号，空着比给个偏低的
    /// 符号更糟。正式配置里每张表最低一档都是 0，够不到的情况只可能来自测试自造的表。
    private func symbol(for dimension: ReelDimension, value: Int) -> ReelSymbol {
        guard let ladder = thresholds[dimension] else { return .cherry }
        for rung in ladder where value >= rung.minimumValue {
            return rung.symbol
        }
        return .cherry
    }
}
