//
//  FeedbackCoordinator.swift
//  coufistgade
//
//  Maps one scoring collision onto GAMEPLAY §12's feedback ladder: particles,
//  sound, haptics, and the floating score, each scaled by impact tier.
//
//  Exists because §12 describes feedback as a *bundle* per tier, not as three
//  independent systems — so the tier-to-feedback mapping is one decision and
//  belongs in one place. Without it the scene would hold three services, decide
//  what a milestone is, and grow eight lines of dispatch in its hottest path.
//
//  Holds no state beyond its services. Every "how loud, how big, how strong"
//  answer comes from GameConfiguration.Feedback.
//

import SpriteKit

final class FeedbackCoordinator {

    private let effects: EffectManager
    private let audio: AudioPlaying
    private let haptics: HapticPlaying

    init(effects: EffectManager, audio: AudioPlaying, haptics: HapticPlaying) {
        self.effects = effects
        self.audio = audio
        self.haptics = haptics
    }

    /// Everything one scoring collision produces.
    ///
    /// Called from the physics step, so it must stay allocation-light and never
    /// block: the collision cooldown allows roughly seven of these a second.
    func play(collision: BallCollision, score: ScoreEvent, combo: ComboEvent) {
        effects.playImpact(collision)
        effects.playScorePopup(score, at: collision.point)

        audio.playImpact(collision.intensity)
        // Low tier returns no haptic style; the service handles that.
        haptics.playImpact(collision.intensity)

        guard isMilestone(combo) else { return }
        playMilestone(combo, on: collision.playerBall)
    }

    /// GAMEPLAY §16's named escalation points.
    private func isMilestone(_ combo: ComboEvent) -> Bool {
        GameConfiguration.Combo.milestoneCounts.contains(combo.count)
    }

    private func playMilestone(_ combo: ComboEvent, on ball: BallNode) {
        effects.playComboEmphasis(combo, on: ball)
        audio.playComboMilestone()
        haptics.playComboMilestone()
    }
}
