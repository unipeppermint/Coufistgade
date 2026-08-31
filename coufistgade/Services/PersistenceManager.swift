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

    /// Stored per §19. No music exists yet, so nothing reads it — the setting is
    /// persisted so Phase 14 can present it without a schema change.
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
