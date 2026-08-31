//
//  GameManager.swift
//  coufistgade
//
//  Start, pause, resume, finish, restart (ARCHITECTURE §9), and the state
//  machine those verbs move through (GAMEPLAY §25).
//
//  A single enum rather than a set of Booleans, because §25 asks for exactly
//  that: `isPaused && !isFinished && hasStarted` admits states that cannot
//  exist, and every reader would have to know which combinations are real.
//
//  Owns the round clock. Holds no SpriteKit and no UIKit: it decides *what
//  state the game is in*, and the scene decides what that means for physics.
//

import Foundation

/// GAMEPLAY §25.
enum GameState: Equatable {
    case idle
    case playing
    case paused
    case finished
}

protocol GameManagerDelegate: AnyObject {
    func gameManager(_ manager: GameManager, didChangeState state: GameState)
    /// Whole seconds remaining changed. Deliberately not every frame — see
    /// `tick(to:)`.
    func gameManager(_ manager: GameManager, didUpdateRemainingTime seconds: Int)
    func gameManagerDidFinishRound(_ manager: GameManager)
}

final class GameManager {

    weak var delegate: GameManagerDelegate?

    private let clock = GameClock()

    private(set) var state: GameState = .idle {
        didSet {
            guard state != oldValue else { return }
            delegate?.gameManager(self, didChangeState: state)
        }
    }

    /// Whole seconds last reported, so the HUD is pushed on change only.
    private var lastReportedSecond: Int?

    var elapsedTime: TimeInterval { clock.elapsed }

    /// Round length. A DEBUG flag can shorten it so the end-of-round path is
    /// reachable from a script without waiting a full minute.
    private var roundDuration: TimeInterval {
        #if DEBUG
        DebugOptions.shortRound
            ? DebugOptions.shortRoundDuration
            : GameConfiguration.Round.duration
        #else
        GameConfiguration.Round.duration
        #endif
    }

    var remainingTime: TimeInterval {
        max(0, roundDuration - clock.elapsed)
    }

    /// Rounded up, so the readout shows "1" through the final second rather than
    /// sitting on "0" while the round is still live.
    var remainingSeconds: Int { Int(remainingTime.rounded(.up)) }

    var isPlaying: Bool { state == .playing }

    // MARK: - Transitions

    /// Begins a round. Valid from any state, so Play Again is the same call.
    func start() {
        clock.start()
        lastReportedSecond = nil
        state = .playing
        reportRemainingTimeIfChanged()
    }

    /// GAMEPLAY §24. Only meaningful while playing: pausing an idle or finished
    /// game is a no-op rather than an error, because the app-lifecycle hooks
    /// fire regardless of what the player was doing.
    func pause() {
        guard state == .playing else { return }
        clock.pause()
        state = .paused
    }

    /// §24: "Resume returns the game to the previous state."
    func resume() {
        guard state == .paused else { return }
        clock.resume()
        state = .playing
    }

    /// Ends the round early. The timer expiring calls this too.
    func finish() {
        guard state == .playing || state == .paused else { return }
        clock.pause()
        state = .finished
        delegate?.gameManagerDidFinishRound(self)
    }

    func reset() {
        clock.reset()
        lastReportedSecond = nil
        state = .idle
    }

    // MARK: - Per-frame

    /// Advances the round. Called from the scene's update, so it must stay cheap.
    ///
    /// Reports remaining time only when the whole-second value changes, not
    /// every frame — the HUD is UIKit, and ARCHITECTURE §23 forbids refreshing
    /// it per frame.
    func tick(to absoluteTime: TimeInterval) {
        guard state == .playing else { return }

        clock.advance(to: absoluteTime)
        reportRemainingTimeIfChanged()

        if clock.elapsed >= roundDuration {
            finish()
        }
    }

    private func reportRemainingTimeIfChanged() {
        let seconds = remainingSeconds
        guard seconds != lastReportedSecond else { return }
        lastReportedSecond = seconds
        delegate?.gameManager(self, didUpdateRemainingTime: seconds)
    }

    #if DEBUG
    /// Frames the clock rejected as implausible — a long background, typically.
    var discardedFrameCount: Int { clock.discardedFrameCount }
    #endif
}
