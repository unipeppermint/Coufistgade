//
//  AchievementTracker.swift
//  coufistgade
//
//  判定成就是否解锁，并记住结果。
//
//  纯逻辑：不碰 SpriteKit、不碰 UIKit、不读时钟。生涯数据由持久化层提供，
//  单局数据由调用方传入——所以整套判定可以直接测，不需要真跑一局。
//

import Foundation

final class AchievementTracker {

    private var store: PersistenceManager

    init(store: PersistenceManager = PersistenceManager()) {
        self.store = store
    }

    // MARK: - 查询

    func isUnlocked(_ achievement: Achievement) -> Bool {
        store.unlockedAchievementIDs.contains(achievement.id)
    }

    var unlockedCount: Int {
        Achievement.all.filter(isUnlocked).count
    }

    /// 生涯类成就的当前进度，0 到 1。
    ///
    /// 单局类成就返回 nil：上一局得 300 分不代表离"单局 500 分"更近，画一条
    /// 进度条会是误导。
    func progress(for achievement: Achievement) -> Double? {
        guard achievement.metric.showsProgress else { return nil }
        guard let current = careerValue(for: achievement.metric) else { return nil }
        return min(1, Double(current) / Double(achievement.target))
    }

    // MARK: - 判定

    /// 结算一局，返回**本局新解锁**的成就。
    ///
    /// 只返回新解锁的，不返回已经拿到的——结算页要展示的是"你刚达成了什么"。
    ///
    /// 必须在 `PersistenceManager.record` **之后**调用：生涯指标要包含刚结束
    /// 这一局，否则"累计 10 局"永远差一局才解锁。
    @discardableResult
    func evaluate(_ summary: RoundSummary) -> [Achievement] {
        var newlyUnlocked: [Achievement] = []

        for achievement in Achievement.all where !isUnlocked(achievement) {
            guard value(for: achievement.metric, in: summary) >= achievement.target else { continue }
            newlyUnlocked.append(achievement)
        }

        guard !newlyUnlocked.isEmpty else { return [] }
        // 一次写入而不是逐条写：一局结束只落一次盘。
        store.unlockAchievements(newlyUnlocked.map(\.id))
        return newlyUnlocked
    }

    // MARK: - 取值

    private func value(for metric: AchievementMetric, in summary: RoundSummary) -> Int {
        switch metric {
        case .roundScore: summary.score
        case .roundCombo: summary.highestCombo
        case .roundHits: summary.hits
        case .totalGames: store.totalGames
        }
    }

    private func careerValue(for metric: AchievementMetric) -> Int? {
        switch metric {
        case .totalGames: store.totalGames
        case .roundScore, .roundCombo, .roundHits: nil
        }
    }
}
