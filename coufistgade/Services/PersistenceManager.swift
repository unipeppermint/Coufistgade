//
//  PersistenceManager.swift
//  coufistgade
//
//  Everything that outlives a round (ARCHITECTURE §19): records, the game
//  count, and the four settings.
//
//  UserDefaults, per §19's MVP note. A struct over a singleton so tests can hand
//  in their own suite and so no global mutable state appears — the type is
//  cheap to construct and holds nothing but its defaults reference.
//
//  Grew out of Phase 2's ScoreStore. The keys were centralised there for exactly
//  this expansion, so no call site had to change to reach the new values.
//

import Foundation

struct PersistenceManager {

    private enum Key {
        // Unchanged from ScoreStore: renaming it would silently reset the best
        // score of anyone who had already played.
        static let bestScore = "bouncy.bestScore"
        static let bestCombo = "bouncy.bestCombo"
        static let totalGames = "bouncy.totalGames"
        static let soundEnabled = "bouncy.soundEnabled"
        static let musicEnabled = "bouncy.musicEnabled"
        static let hapticsEnabled = "bouncy.hapticsEnabled"
        static let reduceMotionEnabled = "bouncy.reduceMotionEnabled"
        static let unlockedAchievements = "bouncy.unlockedAchievements"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // `bool(forKey:)` answers false for an absent key, which would ship the
        // game silent and inert on first launch. Registering the intended
        // defaults is what makes "on unless turned off" true.
        defaults.register(defaults: [
            Key.soundEnabled: true,
            Key.musicEnabled: true,
            Key.hapticsEnabled: true,
            Key.reduceMotionEnabled: false,
        ])
    }

    // MARK: - Achievements

    /// 已解锁成就的 id。
    ///
    /// 存 id 而不是索引或位掩码：成就表将来会插入新条目，索引会整体错位，把玩家
    /// 已拿到的成就变成别的成就。
    var unlockedAchievementIDs: Set<String> {
        Set(defaults.stringArray(forKey: Key.unlockedAchievements) ?? [])
    }

    /// 追加解锁，已存在的忽略。
    func unlockAchievements(_ ids: [String]) {
        guard !ids.isEmpty else { return }
        let merged = unlockedAchievementIDs.union(ids)
        // 排序后再存，让 UserDefaults 的内容可预测——调试和测试都更好读。
        defaults.set(merged.sorted(), forKey: Key.unlockedAchievements)
    }

    // MARK: - Records

    var bestScore: Int { defaults.integer(forKey: Key.bestScore) }
    var bestCombo: Int { defaults.integer(forKey: Key.bestCombo) }
    var totalGames: Int { defaults.integer(forKey: Key.totalGames) }

    /// Files a finished round and reports what it beat.
    ///
    /// One call rather than three, so a round cannot be half-recorded — the game
    /// count and both records move together or not at all.
    @discardableResult
    func record(score: Int, combo: Int) -> RoundRecord {
        defaults.set(totalGames + 1, forKey: Key.totalGames)

        // Strictly greater: tying a record is not beating it, and showing the
        // badge for a tie would cheapen it.
        let beatScore = score > bestScore
        if beatScore { defaults.set(score, forKey: Key.bestScore) }

        let beatCombo = combo > bestCombo
        if beatCombo { defaults.set(combo, forKey: Key.bestCombo) }

        return RoundRecord(isNewBestScore: beatScore, isNewBestCombo: beatCombo)
    }

    // MARK: - Settings

    /// Phase 14 binds these to switches. Wired to the services already, so the
    /// stored values take effect rather than sitting unread.
    var soundEnabled: Bool {
        get { defaults.bool(forKey: Key.soundEnabled) }
        nonmutating set { defaults.set(newValue, forKey: Key.soundEnabled) }
    }

    /// Stored, but deliberately not shown. No music exists in the app, so nothing
    /// reads this — the Settings row was removed because a switch that saves a
    /// preference and then does nothing reads as an unfinished app to App Review
    /// (2.1 App Completeness). The key stays so the row can come back without a
    /// schema change, and so existing installs keep whatever they had set.
    var musicEnabled: Bool {
        get { defaults.bool(forKey: Key.musicEnabled) }
        nonmutating set { defaults.set(newValue, forKey: Key.musicEnabled) }
    }

    var hapticsEnabled: Bool {
        get { defaults.bool(forKey: Key.hapticsEnabled) }
        nonmutating set { defaults.set(newValue, forKey: Key.hapticsEnabled) }
    }

    /// The app's own Reduce Motion preference, independent of the system's.
    /// Read through `MotionPreference`, never directly — see the note there.
    var reduceMotionEnabled: Bool {
        get { defaults.bool(forKey: Key.reduceMotionEnabled) }
        nonmutating set { defaults.set(newValue, forKey: Key.reduceMotionEnabled) }
    }
}

/// What a filed round beat.
struct RoundRecord: Equatable {
    let isNewBestScore: Bool
    let isNewBestCombo: Bool
}
