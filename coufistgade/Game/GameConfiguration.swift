//
//  GameConfiguration.swift
//  coufistgade
//
//  Single home for gameplay and physics constants (ARCHITECTURE §20,
//  GAMEPLAY §8: "All values should be centralized in GameConfiguration /
//  PhysicsConfiguration").
//
//  UI design tokens live in Theme — do not mix the two.
//  Every value here is a documented starting point, not a tuned one.
//  Phase 15 is where these get play-tested on a physical device.
//

import SpriteKit

enum GameConfiguration {

    enum Physics {
        /// GAMEPLAY §8: "gravity: 0 or very small".
        ///
        /// OPEN ISSUE, now quantified (Phase 4 measurement, 600 pt/s launch):
        ///
        ///     t=0s   600 pt/s      t=10s  134 (22%)
        ///     t=1s   517 (86%)     t=20s   30 (5%)
        ///     t=5s   284 (47%)     t=32s  <5  — reads as stationary
        ///
        /// Wall bounces are near-lossless (0.998 retained), so `linearDamping`
        /// alone drives this. A ball drifts to a visual standstill in ~32s,
        /// roughly half a round: without intervention the back half of a 60s
        /// round would be spent hitting motionless targets.
        ///
        /// RESOLVED in Phase 6 by giving normal balls zero damping — see
        /// `normalBallLinearDamping`. Kept here because the figures above are the
        /// evidence for that decision, and because they describe an *empty*
        /// field: in play, ball-to-ball impacts dominate (see
        /// `ballLinearDamping`).
        static let gravity = CGVector(dx: 0, dy: 0)

        // Applied to ball bodies starting in Phase 4. Kept here rather than at
        // the call site so the whole tuning block from GAMEPLAY §8 stays
        // together and reviewable.
        static let ballFriction: CGFloat = 0.15
        static let ballRestitution: CGFloat = 0.82
        static let ballAngularDamping: CGFloat = 0.2

        /// Player ball only. Damping here is *wanted*: a thrown ball has to
        /// settle so the player can grab it again.
        ///
        /// MEASURED (Phase 15, full field): a 1200 pt/s throw falls below
        /// 600 pt/s in 0.1s, 300 in 0.4s, and 150 — slow enough to feel
        /// grabbable — in 1.1s.
        ///
        /// Far quicker than the Phase 4 figure quoted under `gravity`, because
        /// that was measured on an empty field where only damping removed energy.
        /// In play, ball-to-ball impacts at restitution 0.82 do most of the work.
        /// The number to trust for grabbability is this one.
        static let ballLinearDamping: CGFloat = 0.15

        /// RESOLUTION of the GAMEPLAY §8 open issue, using the Phase 4
        /// measurement: at 0.15 damping a ball reached a visual standstill in
        /// ~32s, half a round, which would leave the back half of the round
        /// spent hitting motionless targets.
        ///
        /// Zero damping for normal balls, because the same measurement showed
        /// wall bounces retain 0.998 — so with no damping a drifting ball stays
        /// in motion indefinitely and the playground stays alive on its own. No
        /// speed floor, no stall detection, no recycling machinery needed.
        ///
        /// Energy still leaves the system where it should: ball-to-ball impacts
        /// resolve at restitution 0.82, so interaction costs energy while mere
        /// existence does not.
        static let normalBallLinearDamping: CGFloat = 0.0

        /// Not in GAMEPLAY §8, but §26 ranks "ball weight" among the highest
        /// priorities and mass governs momentum transfer on impact. Leaving it
        /// at SpriteKit's default would forfeit a key feel variable.
        static let ballDensity: CGFloat = 1.0

        /// MEASURED (Phase 4, iOS 26.5 simulator): SpriteKit resolves a
        /// collision using the *maximum* restitution of the two bodies, not the
        /// product, minimum, or average. With the wall at 1.0, a ball retained
        /// 0.998 of its speed across every wall bounce — its own 0.82 was
        /// ignored entirely.
        ///
        /// So this value, not `ballRestitution`, governs wall bounce liveliness.
        /// Keeping it at 1.0 makes walls perfectly elastic and leaves
        /// `ballLinearDamping` as the only energy sink, which is the simpler
        /// system to reason about. Lower it to 0.82 if wall bounces should
        /// visibly cost energy the way GAMEPLAY §8's ball value implies.
        static let boundaryFriction: CGFloat = 0.0
        static let boundaryRestitution: CGFloat = 1.0
    }

    enum Ball {
        /// GAMEPLAY §4 suggests 50–70pt for the player ball.
        ///
        /// Deliberately a fixed point size rather than a fraction of the screen:
        /// a finger does not scale with the display, so a screen-relative ball
        /// would be *harder* to grab on a small phone.
        static let playerDiameter: CGFloat = 60

        /// GAMEPLAY §5 suggests 35–55pt. Unused until Phase 6, but kept beside
        /// the player value so the size relationship is reviewable in one place.
        static let normalDiameter: CGFloat = 44

        /// The glow is baked into the texture, so the sprite is larger than the
        /// physical ball. Physics radius derives from the diameter above, never
        /// from the sprite size — confusing the two would inflate the hitbox.
        static let glowPadding: CGFloat = 10

        /// GAMEPLAY §5: initial count 5–8, maximum 10, minimum 4.
        static let initialNormalCountRange: ClosedRange<Int> = 5...8
        static let maximumNormalCount = 10
        static let minimumNormalCount = 4

        /// Gap required between ball surfaces at spawn, so GAMEPLAY §2's "no
        /// severe overlap" holds and the solver never has to push a stack apart.
        static let spawnSeparation: CGFloat = 8

        /// Extra clearance from the player ball at spawn (GAMEPLAY §18: never
        /// respawn directly on top of the player).
        static let spawnClearanceFromPlayer: CGFloat = 60

        /// Rejection-sampling budget per ball. Falls back to the least-bad
        /// candidate rather than failing to spawn, so the count is always met.
        static let spawnAttempts = 24

        /// Normal balls start drifting slowly rather than sitting still, so the
        /// playground reads as alive the moment the round begins. Modest on
        /// purpose — fast free-floating balls would fight the player for
        /// attention.
        static let normalDriftSpeedRange: ClosedRange<CGFloat> = 60...140
    }

    enum Input {
        /// How hard the ball chases the finger, in 1/s. This is the whole of
        /// GAMEPLAY §6's "slight physical lag": the ball approaches the finger
        /// exponentially with a time constant of 1/gain, so 18 predicts ~55ms.
        ///
        /// MEASURED (Phase 15): 33ms to close 63% of an 80pt gap, and the ball
        /// settles exactly on the finger — no steady-state offset. Faster than
        /// the continuous model predicts because the controller is discrete: each
        /// frame commands `gap × gain` for a whole 16.7ms step.
        ///
        /// Raise it for a snappier ball, lower it for a heavier one.
        static let dragFollowGain: CGFloat = 18

        /// Ceiling on the chase speed. A finger that jumps across the screen
        /// would otherwise command an enormous velocity for one frame.
        static let dragMaxFollowSpeed: CGFloat = 2500

        /// Grab radius beyond the ball's own edge. Modest on purpose — larger
        /// and the ball starts feeling magnetic.
        static let grabPadding: CGFloat = 12

        /// Trailing window used to estimate throw speed, measured back from the
        /// moment of release.
        ///
        /// GAMEPLAY §7's `dragDistance / dragDuration` over the *whole* drag
        /// misreads the common "move slowly, then flick" gesture, averaging the
        /// flick away. Only the last few samples describe the throw.
        ///
        /// MEASURED constraint: this must stay *shorter* than a typical flick or
        /// it reintroduces the same dilution at smaller scale. A flick runs 2–3
        /// frames (~33ms); at 0.08s the estimate for an 1800 pt/s flick came out
        /// at 731 pt/s because most of the window was the preceding slow drag.
        /// 0.05s still spans 3 samples at 60Hz (6 at 120Hz) for smoothing.
        static let throwSampleWindow: TimeInterval = 0.05

        /// Below this, releasing drops the ball where it sits instead of
        /// throwing it.
        ///
        /// GAMEPLAY §7 calls for a minimum velocity; read as a dead zone rather
        /// than a floor to boost up to. Boosting would make it impossible to
        /// place the ball deliberately, which matters for lining up a shot.
        static let minimumThrowSpeed: CGFloat = 60

        /// GAMEPLAY §7: "Do not allow unrealistic velocities."
        static let maximumThrowSpeed: CGFloat = 2200
    }

    enum Collision {
        /// Approach speed along the contact normal, in points/sec, separating
        /// the tiers in GAMEPLAY §11. See
        /// `CollisionManager.approachSpeed(fromSeparation:)` for why this is
        /// approach and not the speed the contact delegate reports directly.
        ///
        /// RE-SPACED in Phase 15 from 400/1000, against measured throw-to-tier
        /// behaviour (hand-placed collision course, one ball each):
        ///
        ///     throw  200 →  172 low     throw 1100 → 1070 high
        ///     throw  400 →  371 low     throw 1600 → 1571 high
        ///     throw  700 →  671 medium  throw 2200 → 2171 high
        ///
        /// At the old thresholds High began at ~1100 against a 2200 cap, so more
        /// than half the usable throw range collapsed into the top tier: a heavy
        /// haptic, 24 particles and the loudest cue became the *default* for any
        /// committed throw. GAMEPLAY §12 gives High "additional visual emphasis",
        /// which only reads as emphasis if it is uncommon.
        ///
        /// These split the deliberate-throw range (roughly 150 to 2200) into
        /// thirds, so High now needs about two-thirds power.
        static let mediumImpactSpeed: CGFloat = 700
        static let highImpactSpeed: CGFloat = 1400

        /// Below this a contact is not an event at all.
        ///
        /// Deliberately set just above `Ball.normalDriftSpeedRange`'s 140
        /// ceiling. Normal balls drift forever by design (see
        /// `Physics.normalBallLinearDamping`), so a lower floor would let a
        /// ball wander into a parked player ball and register a hit the player
        /// did nothing to earn — free points for putting the phone down, once
        /// Phase 8 attaches scoring.
        ///
        /// The cost is that a very gentle deliberate tap does not register
        /// either. That trade-off is a design call: if passive contact should
        /// count, this is the single number to lower.
        ///
        /// VERIFIED (Phase 9): a full 60s round with the ball never touched
        /// scored 0 with a peak combo of 0 — drift alone cannot earn anything.
        /// Hits do keep arriving for a while *after* a hard throw, because
        /// struck balls carry that energy back (they have no damping by
        /// design). Those are the player's own shot returning, not free points.
        static let grazeSpeed: CGFloat = 150

        /// Repeat contacts with the same ball inside this window are ignored.
        ///
        /// Two balls resting against each other re-contact every frame; without
        /// this, one nudge would emit 60 events/sec and GAMEPLAY §12's "never
        /// trigger haptics every frame" would be impossible to honour downstream.
        /// Short enough that a genuine second hit still registers.
        static let repeatContactCooldown: TimeInterval = 0.15
    }

    enum Score {
        /// GAMEPLAY §13: base score is 10 points.
        static let base = 10

        /// Multiplier applied when no combo system is driving one.
        ///
        /// GAMEPLAY §13 is `baseScore × comboMultiplier`, and §15 starts the
        /// combo ladder at 1x for combo 0–1 — so this is that first rung, not a
        /// placeholder to be removed. Phase 9 supplies the rest of the ladder.
        static let defaultMultiplier = 1

        /// Deliberately NOT scaled by `ImpactIntensity`.
        ///
        /// Tempting, and wrong: GAMEPLAY §13 defines score as base × combo
        /// only, and §12 assigns intensity to *feedback*. Paying more for a
        /// harder hit would also fight §14's design, where the reward for
        /// skill is chaining collisions rather than hitting hard — and it would
        /// quietly punish the delicate taps that set up a chain.
        static let scalesWithImpactIntensity = false
    }

    enum Combo {
        /// GAMEPLAY §14: approximately 2 seconds.
        ///
        /// Must stay comfortably longer than
        /// `Collision.repeatContactCooldown`, or chaining hits on one ball
        /// would be impossible and the combo system would cap itself.
        static let window: TimeInterval = 2.0

        /// GAMEPLAY §15's ladder, as data rather than a switch.
        ///
        /// Ordered high threshold first; the first rung the count reaches wins.
        /// A table keeps the whole curve reviewable in one place and tunable in
        /// Phase 15 without touching logic — the docs call these values a
        /// proposal to be play-tested.
        ///
        ///     combo 0–1 → 1x    combo 4–6 → 3x    combo 10+ → 10x
        ///     combo 2–3 → 2x    combo 7–9 → 5x
        static let multiplierLadder: [(minimumCount: Int, multiplier: Int)] = [
            (10, 10),
            (7, 5),
            (4, 3),
            (2, 2),
        ]

        /// Below this the combo readout stays hidden (UI_DESIGN §10: "appear
        /// only when relevant"). 2 is where the ladder first pays more than 1x,
        /// so it is exactly when the combo starts to matter.
        static let minimumVisibleCount = 2

        /// Combos that earn their own cue, from GAMEPLAY §16's escalation list.
        ///
        /// Exact counts rather than "at or above", because the combo rises one
        /// at a time: each of these is crossed exactly once per rally, so the
        /// milestone fires once. A `>=` rule would fire on every hit past 10.
        static let milestoneCounts: Set<Int> = [2, 4, 7, 10]

        /// GAMEPLAY §16's escalation points.
        ///
        /// Combo 2 is the small emphasis, which the readout appearing already
        /// provides. 4 is the stronger score animation, 10 the major moment.
        /// Combo 7's special particle treatment is deliberately absent: it is
        /// Phase 10's, and a constant here with no consumer would be dead code.
        static let strongEmphasisCount = 4
        static let majorEmphasisCount = 10
    }

    /// GAMEPLAY §12's feedback ladder, one place per tier.
    ///
    /// Everything here is keyed by `ImpactIntensity` so the three tiers stay
    /// visibly parallel: if a tier gains a parameter, it gains it for all three
    /// or the asymmetry is obvious in review.
    enum Feedback {

        enum Particles {
            /// UI_DESIGN §12: enhance impact, not cover the screen.
            static func count(for intensity: ImpactIntensity) -> Int {
                switch intensity {
                case .low: 6
                case .medium: 14
                case .high: 24
                }
            }

            static func speed(for intensity: ImpactIntensity) -> CGFloat {
                switch intensity {
                case .low: 90
                case .medium: 170
                case .high: 280
                }
            }

            static func size(for intensity: ImpactIntensity) -> CGFloat {
                switch intensity {
                case .low: 5
                case .medium: 7
                case .high: 9
                }
            }

            /// Short on purpose: a burst that outlives the impact reads as smoke.
            static let lifetime: TimeInterval = 0.42
            /// Spread of the burst, in radians. Full circle — the impact throws
            /// debris every way, and a directed cone needs a normal the emitter
            /// does not have.
            static let angleRange: CGFloat = .pi * 2
        }

        enum Audio {
            /// Pitch of the collision cue, in Hz. Lower for a heavier hit: a
            /// big impact should sound bigger, and rising pitch with force
            /// reads as comical rather than weighty.
            static func frequency(for intensity: ImpactIntensity) -> Double {
                switch intensity {
                case .low: 660
                case .medium: 480
                case .high: 320
                }
            }

            static func amplitude(for intensity: ImpactIntensity) -> Double {
                switch intensity {
                case .low: 0.18
                case .medium: 0.30
                case .high: 0.42
                }
            }

            /// Duration of one cue. Percussive — long enough to have a body,
            /// short enough that rapid hits do not smear into a drone.
            static func duration(for intensity: ImpactIntensity) -> Double {
                switch intensity {
                case .low: 0.09
                case .medium: 0.13
                case .high: 0.18
                }
            }

            /// Cue for reaching a combo milestone: a brighter, shorter blip
            /// layered over the impact rather than replacing it.
            static let comboFrequency: Double = 880
            static let comboAmplitude: Double = 0.22
            static let comboDuration: Double = 0.10

            /// How fast a cue's envelope falls, as an exponential rate.
            ///
            /// MEASURED: at 18 the High cue was still above the audibility
            /// threshold 0.168s after it started, past the 0.15s collision
            /// cooldown — so a fast rally would have layered each cue over its
            /// own successor and smeared into a drone. 26 puts the High tail
            /// well under the cooldown while leaving the attack intact.
            ///
            /// Raising it further makes every hit a dry click; lowering it
            /// brings the smearing back.
            static let decayRate: Double = 26

            /// Simultaneous voices. Past this the oldest is reused — a cap is
            /// what keeps a burst of hits from clipping into noise.
            static let voiceCount = 6
        }

        enum Haptics {
            /// GAMEPLAY §12 gives Low no haptic at all: every hit buzzing would
            /// desensitise the player and drain the battery for nothing.
            static func style(
                for intensity: ImpactIntensity
            ) -> UIImpactFeedbackGenerator.FeedbackStyle? {
                switch intensity {
                case .low: nil
                case .medium: .light
                case .high: .heavy
                }
            }

            /// Floor between haptics, in seconds. The collision cooldown alone
            /// permits ~7/s, which is far too many to feel as distinct taps.
            static let minimumInterval: TimeInterval = 0.12
        }

        enum ScorePopup {
            /// How far the floating value drifts up before fading, in points.
            static let riseDistance: CGFloat = 46
            static let duration: TimeInterval = 0.62
            static let fontSize: CGFloat = 17
            static let comboFontSize: CGFloat = 22
        }
    }

    enum Round {
        /// GAMEPLAY §20: 60 seconds.
        static let duration: TimeInterval = 60

        /// Largest frame delta the game clock will accept, in seconds.
        ///
        /// SpriteKit hands `update(_:)` an absolute system time, not a
        /// game-relative one. After a long interruption the first frame back
        /// carries the whole gap — background the app for two minutes and an
        /// unguarded clock would consume the entire round in one frame.
        ///
        /// 0.25s is ~15 frames at 60Hz: long enough that an ordinary hitch
        /// still counts, short enough that a real absence is discarded.
        static let maximumFrameDelta: TimeInterval = 0.25

        /// Remaining seconds below which the readout turns urgent.
        static let urgentRemainingTime: TimeInterval = 10
    }

    enum World {
        /// Extra inset inside the safe area so a ball never sits half-hidden
        /// under the Dynamic Island or the home indicator (GAMEPLAY §9).
        static let boundaryInset: CGFloat = 4

        /// Portrait-only game, so this is effectively evaluated once.
        static let backgroundGradientRadiusRatio: CGFloat = 0.75
    }
}
