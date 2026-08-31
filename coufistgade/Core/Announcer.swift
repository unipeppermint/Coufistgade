//
//  Announcer.swift
//  coufistgade
//
//  Speaks game events to VoiceOver.
//
//  A real-time game is otherwise silent to a VoiceOver user: the HUD labels are
//  correct, but nothing tells the user they changed, and a player cannot swipe
//  to the score mid-throw. Without this the round simply ends with no
//  indication it ever started.
//
//  Rate-limited, because the opposite failure is worse. Collisions arrive up to
//  seven a second, and VoiceOver queues announcements — an unthrottled feed
//  would still be reading hit four when the round ended.
//

import UIKit

final class Announcer {

    /// Minimum gap between spoken announcements, in seconds.
    ///
    /// Long enough that each is heard before the next arrives; short enough that
    /// a milestone still lands close to the moment it happened.
    static let minimumInterval: TimeInterval = 2.0

    private let speak: (String) -> Void
    private let now: () -> TimeInterval
    private var lastSpokenTime: TimeInterval = -.greatestFiniteMagnitude

    /// Both injected so tests need neither VoiceOver running nor real time.
    init(
        now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        speak: @escaping (String) -> Void = { message in
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    ) {
        self.now = now
        self.speak = speak
    }

    /// Speaks unless something was said too recently.
    ///
    /// Returns whether it spoke, which is what makes the throttle testable.
    @discardableResult
    func announce(_ message: String) -> Bool {
        guard UIAccessibility.isVoiceOverRunning || isForcedForTesting else { return false }
        return announceIgnoringVoiceOverState(message)
    }

    /// Speaks regardless of the rate limit. For the end of a round, which the
    /// user must hear even if a combo was just announced.
    @discardableResult
    func announceImmediately(_ message: String) -> Bool {
        guard UIAccessibility.isVoiceOverRunning || isForcedForTesting else { return false }
        lastSpokenTime = now()
        speak(message)
        return true
    }

    private func announceIgnoringVoiceOverState(_ message: String) -> Bool {
        let time = now()
        guard time - lastSpokenTime >= Self.minimumInterval else { return false }
        lastSpokenTime = time
        speak(message)
        return true
    }

    /// Tests inject their own `speak`, so they need the guard bypassed —
    /// VoiceOver is not running in a test process.
    private var isForcedForTesting: Bool {
        #if DEBUG
        return isTestOverrideEnabled
        #else
        return false
        #endif
    }

    #if DEBUG
    /// Set by tests only. Nothing in the app touches it.
    var isTestOverrideEnabled = false
    #endif
}
