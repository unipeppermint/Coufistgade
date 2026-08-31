//
//  GameSceneDelegate.swift
//  coufistgade
//
//  The one channel out of the SpriteKit world (ARCHITECTURE §8:
//  GameScene → Game Event → GameViewController → HUD update).
//
//  A protocol rather than closures because the set of events grows every phase
//  from here (combo, timer, round end), and because it keeps the direction of
//  the dependency explicit: the scene knows it reports events, and knows
//  nothing about labels, view controllers, or navigation.
//
//  Deliberately named for game events, not for HUD updates. If a method here
//  ever mentions a view, the boundary has been crossed.
//

import Foundation

protocol GameSceneDelegate: AnyObject {

    /// A valid collision scored. Called on the physics step, so at most a
    /// handful of times per second (CollisionManager's cooldown guarantees it)
    /// — never per frame, per ARCHITECTURE §23.
    func gameScene(_ scene: GameScene, didScore event: ScoreEvent)

    /// The combo changed: extended by a hit, or lapsed.
    ///
    /// Always called *before* `didScore` for the same collision, because the
    /// score is computed from the combo's multiplier and the HUD's score
    /// animation escalates with the combo's emphasis (GAMEPLAY §16).
    ///
    /// Fires only on change, not every frame — a lapse is one call, not a
    /// stream of zeroes.
    func gameScene(_ scene: GameScene, didUpdateCombo event: ComboEvent)

    func gameScene(_ scene: GameScene, didChangeState state: GameState)

    /// Once per second at most, never per frame (ARCHITECTURE §23).
    func gameScene(_ scene: GameScene, didUpdateRemainingTime seconds: Int)

    /// The scene has already stopped itself; what to present is the
    /// controller's call.
    func gameSceneDidFinishRound(_ scene: GameScene)
}
