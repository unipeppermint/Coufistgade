//
//  Achievement.swift
//  coufistgade
//
//  成就的定义。见 PRD §10a 与 UI_DESIGN §15a。
//
//  用一张表而不是一串 switch：整条难度曲线可以在一处审阅，调整目标值不动逻辑
//  ——和 GameConfiguration.Combo.multiplierLadder 同一个思路。
//
//  每条成就只声明"看哪个指标、到多少算达成"，怎么判定与怎么显示都在别处。
//

import Foundation

/// 成就衡量的对象。
///
/// 分两类，判定时机不同：单局指标来自刚结束的这一局，生涯指标来自持久化层。
enum AchievementMetric: String, CaseIterable {
    /// 单局：本局得分。
    case roundScore
    /// 单局：本局最高连击。
    case roundCombo
    /// 单局：本局有效碰撞次数。
    case roundHits
    /// 生涯：累计局数。
    case totalGames

    /// 生涯指标可以显示进度条，单局指标不行——"本局得 500 分"没有中间进度，
    /// 上一局得 300 分不代表离达成更近。
    var showsProgress: Bool {
        switch self {
        case .roundScore, .roundCombo, .roundHits: false
        case .totalGames: true
        }
    }
}

struct Achievement: Equatable, Identifiable {
    /// 持久化用的稳定标识。**不可修改**——改了等于把玩家已解锁的成就清零。
    let id: String
    let metric: AchievementMetric
    /// 达到这个值即解锁。
    let target: Int

    var titleKey: String { "achievement.\(id).title" }
    var detailKey: String { "achievement.\(id).detail" }
}

extension Achievement {

    /// 全部成就，按难度递增。
    ///
    /// 刻意从"几乎必然达成"开始：第一条在第一局结束时就会解锁，让玩家立刻知道
    /// 这套系统存在。后面的目标值按已测数据设定——连击 10 是阶梯顶端，单局 1000
    /// 分需要约 30 次高倍率命中。
    static let all: [Achievement] = [
        Achievement(id: "firstPoints", metric: .roundScore, target: 10),
        Achievement(id: "century", metric: .roundScore, target: 100),
        Achievement(id: "fiveHundred", metric: .roundScore, target: 500),
        Achievement(id: "thousand", metric: .roundScore, target: 1000),

        Achievement(id: "chainFour", metric: .roundCombo, target: 4),
        Achievement(id: "chainSeven", metric: .roundCombo, target: 7),
        Achievement(id: "chainTen", metric: .roundCombo, target: 10),

        Achievement(id: "busyRound", metric: .roundHits, target: 25),

        Achievement(id: "tenRounds", metric: .totalGames, target: 10),
        Achievement(id: "fiftyRounds", metric: .totalGames, target: 50),
    ]
}

/// 一局结束时的统计，用于判定单局成就。
struct RoundSummary: Equatable {
    let score: Int
    let highestCombo: Int
    let hits: Int
}
