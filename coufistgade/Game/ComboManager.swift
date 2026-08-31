//
//  ComboManager.swift
//  coufistgade
//
//  Owns the combo count, its window, and the multiplier (ARCHITECTURE §15).
//
//  Pure logic with an injected clock: time arrives as a parameter, never read
//  from a global. That makes the whole window testable without waiting in real
//  time, and it means the combo is driven by the *scene* clock — so a paused
//  game cannot silently expire a player's combo.
//

import Foundation

final class ComboManager {

    private(set) var count = 0

    /// Highest combo reached this round. GAMEPLAY §22 shows this on the result
    /// screen; kept here because only this type sees every increment.
    ///
    /// Round-scoped, not all-time — the doc review flagged that ambiguity, and
    /// the all-time record belongs to persistence in Phase 13.
    private(set) var highestCount = 0

    /// Scene time of the most recent scoring hit. nil means no combo running.
    private var lastHitTime: TimeInterval?

    /// GAMEPLAY §13's multiplier, from §15's ladder.
    var multiplier: Int {
        GameConfiguration.Combo.multiplierLadder
            .first { count >= $0.minimumCount }?
            .multiplier
            ?? GameConfiguration.Score.defaultMultiplier
    }

    /// Whether the readout should be on screen (UI_DESIGN §10).
    var isVisible: Bool { count >= GameConfiguration.Combo.minimumVisibleCount }

    var emphasis: ComboEmphasis {
        if count >= GameConfiguration.Combo.majorEmphasisCount { return .major }
        if count >= GameConfiguration.Combo.strongEmphasisCount { return .strong }
        return .normal
    }

    /// Counts a scoring collision and returns the resulting combo state.
    ///
    /// Expires first: a hit arriving after a long gap starts a new combo at 1
    /// rather than extending a dead one. Doing it here as well as in
    /// `expireIfNeeded` means correctness does not depend on the frame loop
    /// having run — which it has not, on the very first hit.
    @discardableResult
    func registerHit(at time: TimeInterval) -> ComboEvent {
        expireIfNeeded(at: time)

        count += 1
        highestCount = max(highestCount, count)
        lastHitTime = time

        return currentEvent
    }

    /// Drops the combo if the window has elapsed.
    ///
    /// Returns true only on the transition, so the caller can report a change
    /// without pushing state every frame (ARCHITECTURE §23).
    @discardableResult
    func expireIfNeeded(at time: TimeInterval) -> Bool {
        guard let lastHitTime, count > 0 else { return false }
        // A clock that jumped backwards (scene re-presented, tests) must not
        // freeze the combo open forever.
        let elapsed = time - lastHitTime
        guard elapsed >= GameConfiguration.Combo.window || elapsed < 0 else { return false }

        count = 0
        self.lastHitTime = nil
        return true
    }


    /// Clears everything for a new round, `highestCount` included.
    func reset() {
        count = 0
        highestCount = 0
        lastHitTime = nil
    }

    var currentEvent: ComboEvent {
        ComboEvent(
            count: count,
            multiplier: multiplier,
            emphasis: emphasis,
            isVisible: isVisible
        )
    }
}

/// How loudly the HUD should react (GAMEPLAY §16).
enum ComboEmphasis: Int, Comparable, CaseIterable {
    case normal
    case strong
    case major

    static func < (lhs: ComboEmphasis, rhs: ComboEmphasis) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// The combo state after a change.
struct ComboEvent: Equatable {
    let count: Int
    let multiplier: Int
    let emphasis: ComboEmphasis
    /// Whether the readout belongs on screen. Computed here rather than in the
    /// HUD so the threshold lives with the rest of the combo rules.
    let isVisible: Bool
}
