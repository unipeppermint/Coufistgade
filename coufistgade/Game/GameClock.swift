//
//  GameClock.swift
//  coufistgade
//
//  Elapsed *game* time, which is not the same as elapsed real time.
//
//  GAMEPLAY §20 requires the round timer to be based on game time, and §24
//  requires pause to stop both the round timer and the combo timer. Neither is
//  possible with SpriteKit's `currentTime`: that is an absolute system clock, so
//  time spent paused or backgrounded still passes.
//
//  This accumulates per-frame deltas only while running, and discards deltas
//  too large to be a real frame. Pure logic, no SpriteKit — the whole thing is
//  driven by whatever time value the caller supplies.
//

import Foundation

final class GameClock {

    /// Seconds of game time accumulated.
    private(set) var elapsed: TimeInterval = 0

    private(set) var isRunning = false

    /// Absolute time of the previous accepted frame.
    private var lastFrameTime: TimeInterval?

    /// Frames whose delta was rejected as implausible. Diagnostic only.
    private(set) var discardedFrameCount = 0

    // MARK: - Control

    func start() {
        elapsed = 0
        discardedFrameCount = 0
        lastFrameTime = nil
        isRunning = true
    }

    func pause() {
        isRunning = false
        // Dropped deliberately: the next resume must measure from its own first
        // frame, not from whenever the clock last ticked. Keeping it would hand
        // resume a delta covering the entire pause.
        lastFrameTime = nil
    }

    func resume() {
        guard !isRunning else { return }
        lastFrameTime = nil
        isRunning = true
    }

    func reset() {
        elapsed = 0
        discardedFrameCount = 0
        lastFrameTime = nil
        isRunning = false
    }

    // MARK: - Advancing

    /// Advances by the gap since the previous frame.
    ///
    /// Returns the delta applied, which is zero when the clock is stopped, on
    /// the first frame after starting or resuming, or when the gap is rejected.
    @discardableResult
    func advance(to absoluteTime: TimeInterval) -> TimeInterval {
        guard isRunning else { return 0 }

        // First frame of this run: establish a baseline, advance nothing.
        guard let previous = lastFrameTime else {
            lastFrameTime = absoluteTime
            return 0
        }

        let delta = absoluteTime - previous
        lastFrameTime = absoluteTime

        // Backwards means the clock source was re-presented; too large means the
        // app was away. Neither is game time that the player experienced.
        guard delta > 0, delta <= GameConfiguration.Round.maximumFrameDelta else {
            if delta > GameConfiguration.Round.maximumFrameDelta {
                discardedFrameCount += 1
            }
            return 0
        }

        elapsed += delta
        return delta
    }
}
