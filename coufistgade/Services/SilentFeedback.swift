//
//  SilentFeedback.swift
//  coufistgade
//
//  Null implementations, so a GameScene can be constructed without an audio
//  engine or a Taptic Engine.
//
//  Not test-only scaffolding: it is what makes `GameScene(size:)` usable
//  anywhere the real services would be wrong — unit tests, and any future
//  preview or capture path. The alternative, optional services checked at every
//  call site, spreads nil handling through the hot path.
//

import Foundation

final class SilentAudio: AudioPlaying {
    var isEnabled = false
    func playImpact(_ intensity: ImpactIntensity) {}
    func playComboMilestone() {}
    func playAchievementUnlock() {}
}

final class SilentHaptics: HapticPlaying {
    var isEnabled = false
    func playImpact(_ intensity: ImpactIntensity) {}
    func playComboMilestone() {}
    func playAchievementUnlock() {}
}
