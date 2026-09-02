//
//  ReelOutcome.swift
//  coufistgade
//
//  三个轮子的定义。见 docs/GAMEPLAY.md §27。
//
//  设计上最重要的两条：
//
//  **一、没有随机数。** 三个轮子分别读本局的命中数、最高连击、得分，各自按阈值
//  落到一个档位。同一局成绩永远转出同一个结果——轮子是把玩家已经打出来的东西
//  翻出来给他看，不是一次抽奖。所以没有下注、没有货币、没有派彩概率，App Store
//  分级问卷里 Chance-Based Activities 那四项照旧全答 No。
//
//  **二、按最低档赔付。** 奖励由三个轮子里**最低**的那一档决定。
//
//  第二条是第一条的必然结果，而不是独立的选择。三个维度在一局里只增不减，所以
//  「三轮必须完全同档才赔」会被继续游戏**打破**：得分 990 时再命中一次就跨进
//  seven 档，而命中与连击还在 star，线就断了。那会让终局出现「停手保住线」的
//  最优解——在一个 60 秒的动作游戏里这是坏激励。
//
//  按最低档赔付则永远不惩罚继续玩：推高任何一个维度，最低档只可能上升或不变。
//  于是规则和游戏自身的指令一致——全都往上推，尤其是最弱的那个。
//
//  三轮真正同档（`isAligned`）仍然是个被庆祝的时刻，但它的赔付等于它的最低档，
//  没有额外加钱。给它额外加钱会把上面那个停手激励原样带回来。
//
//  另见 ReelEvaluator（判定逻辑）与 GameConfiguration.Reels（阈值与奖励表）。
//

import Foundation

/// 轮子上的符号，按档位递增。
///
/// 用 CaseIterable 且顺序即档位高低：`allCases` 的次序被滚动动画当作轮带用，
/// 也被测试用来核对阈值表是单调的。
enum ReelSymbol: String, CaseIterable {
    case cherry
    case bell
    case star
    case seven

    /// 档位序号，0 起。仅用于比较高低与查奖励表，不要持久化。
    var tier: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }

    /// 比这一档高一级的符号；已是顶档则为 nil。
    ///
    /// 对局中的「还差多少」就是朝这个目标算的。
    var next: ReelSymbol? {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self), index + 1 < all.count else { return nil }
        return all[index + 1]
    }

    /// 显示用的字形。
    ///
    /// 用 emoji 而不是图片资源：三个轮子就四种符号，做成 asset 要连带处理
    /// @2x/@3x 与深浅色两套，而这里只需要一个能在标签里排版的字形。
    /// 真要换成美术资源，只改这一处。
    var glyph: String {
        switch self {
        case .cherry: "🍒"
        case .bell: "🔔"
        case .star: "⭐️"
        case .seven: "7️⃣"
        }
    }

    /// 本地化用的 key 片段。稳定值，**不可修改**——改了文案就查不到。
    var localizationKey: String { "reel.symbol.\(rawValue)" }
}

/// 一个轮子读的是哪个维度。
///
/// 三个轮子读三件不同的事，这是「奖励取决于最弱一项」能成为全面性要求的原因。
/// 顺序即从左到右的排列：命中（量）→ 连击（串）→ 得分（总），从过程到结果，
/// 读起来是一句话。
enum ReelDimension: String, CaseIterable {
    /// 本局有效碰撞次数。
    case hits
    /// 本局最高连击。
    case combo
    /// 本局得分（**加成前**）。
    case score

    var localizationKey: String { "reel.dimension.\(rawValue)" }
}

/// 一个轮子的结果：读了哪个维度、落在哪个符号、当时的原始数值。
///
/// 带上 `value` 是为了让界面能解释「凭什么是这个符号」——无障碍标签会读出
/// 「命中 12，⭐️」，玩家因此能反推阈值，而不用猜。
struct ReelSlot: Equatable {
    let dimension: ReelDimension
    let symbol: ReelSymbol
    let value: Int
}

/// 三个轮子的整体结果。
struct ReelOutcome: Equatable {

    /// 左到右三个轮子，顺序即 `ReelDimension.allCases`。
    let slots: [ReelSlot]

    /// 三个轮子里最低的那一档。**这一档决定赔付。**
    ///
    /// 见文件头第二条：按最低档赔付是为了让推高任何维度永远不亏。
    let floorSymbol: ReelSymbol

    /// 本次结算加的分。由 `floorSymbol` 决定。
    let bonus: Int

    /// 三个轮子完全同档。
    ///
    /// 这是「三个维度齐平」的那一刻，值得庆祝，但**不额外加钱**——加钱会让
    /// 「保住齐平」重新变成停手的理由（见文件头）。
    var isAligned: Bool {
        Set(slots.map(\.symbol)).count == 1
    }

    /// 没有奖励。最低档是樱桃时为真。
    ///
    /// 界面用它决定要不要显示奖励行——没有奖励就整行不出现，不显示「+0」。
    var isBlank: Bool { bonus == 0 }

    /// 拖住赔付的那些轮子，即落在最低档上的。
    ///
    /// 对局中用它给出「往哪推」的指引：其余轮子再高也不会提高奖励。
    var laggingDimensions: [ReelDimension] {
        slots.filter { $0.symbol == floorSymbol }.map(\.dimension)
    }
}

/// 对局中的进度：当前结果，加上「离下一档还差多少」。
///
/// 只在对局里用（HUD），结算页用不到——那时已经没有下一档可争了。
///
/// 存在的意义是把已知变成压力：三个维度的当前值玩家在 HUD 上都看得见，所以悬念
/// 无从制造（也不该用随机数制造）。但「还差 3 次命中就到 ⭐️」是个能主动去争的
/// 目标，比回合结束后揭晓一张成绩单强得多。
struct ReelProgress: Equatable {

    let outcome: ReelOutcome

    /// 下一个能提高奖励的档位；已在顶档则为 nil。
    let target: ReelSymbol?

    /// 每个还没够到 `target` 的维度，还差多少数值。
    ///
    /// 已经够到的维度不在表里——它们显示为「已达成」而不是一个数字。
    let shortfalls: [ReelDimension: Int]

    /// 这个维度还差多少；已达成则为 nil。
    func shortfall(for dimension: ReelDimension) -> Int? {
        shortfalls[dimension]
    }
}
