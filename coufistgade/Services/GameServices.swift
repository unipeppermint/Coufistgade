//
//  GameServices.swift
//  coufistgade
//
//  The services a scene needs from outside itself.
//
//  One value instead of a growing parameter list: audio and haptics arrived
//  together in Phase 10, Phase 14 will want settings alongside them, and every
//  addition would otherwise mean a new initialiser on GameScene and a new
//  argument at every construction site.
//
//  `.silent` is what makes the plain `GameScene(size:)` viable — tests get a
//  fully working scene with no audio graph and no Taptic Engine.
//

import Foundation

struct GameServices {
    let audio: AudioPlaying
    let haptics: HapticPlaying

    /// No sound, no vibration, identical gameplay.
    static var silent: GameServices {
        GameServices(audio: SilentAudio(), haptics: SilentHaptics())
    }
}
