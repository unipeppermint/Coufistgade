# Bouncy Development Roadmap

## Phase 0 — Product Definition
Status: Completed

Completed:
- PRD
- Gameplay
- UI Design
- Architecture
- Development rules

## Phase 1 — Xcode Project Setup
Status: Completed

Create:
- iPhone app
- iOS 18+
- Swift
- UIKit
- Programmatic UI
- No Storyboard
- No SwiftUI
- SpriteKit dependency / framework usage

Implement:
- AppDelegate
- SceneDelegate
- UINavigationController
- Basic project structure

## Phase 2 — Home
Status: Completed

Implement:
- HomeViewController
- HeroBallView
- Best Score
- Play button
- Settings button

Goal:
A polished first Home screen.

## Phase 3 — SpriteKit Game Container
Status: Completed

Implement:
- GameViewController
- SKView
- GameScene
- Physics world
- Boundaries
- Background

Goal:
Game screen runs with a stable SpriteKit scene.

## Phase 4 — First Ball
Status: Completed

Implement:
- Player ball
- Physics body
- Visual treatment
- Collision with boundaries

Goal:
One ball feels physical.

## Phase 5 — Touch Interaction
Status: Completed

Implement:
- Touch down
- Drag
- Release
- Throw velocity
- Velocity clamping

Goal:
User can drag and throw the ball naturally.

## Phase 6 — Multiple Balls
Status: Completed

Implement:
- Normal balls
- 5–8 initial balls
- Safe spawn positions
- Ball removal / respawn

Goal:
A playable physical playground exists.

## Phase 7 — Collision
Status: Completed

Implement:
- Player vs normal ball collision
- Collision event
- Impact intensity

Goal:
Collisions become meaningful events.

## Phase 8 — Score
Status: Completed

Implement:
- ScoreManager
- Base score
- HUD score

Goal:
Valid collisions produce visible score.

## Phase 9 — Combo
Status: Completed

Implement:
- ComboManager
- 2-second combo window
- Multipliers
- HUD feedback

Goal:
The player is motivated to chain collisions.

## Phase 10 — Feedback
Status: Completed

Implement:
- Particles
- Audio
- Haptics
- Score animation
- Combo animation

Goal:
Make the core loop satisfying.

## Phase 11 — Game Timer
Status: Completed

Implement:
- 60-second game
- Game-state transitions
- End-of-round handling

Goal:
A complete round exists.

## Phase 12 — Result
Status: Completed

Implement:
- ResultViewController
- Score
- Best Score
- Highest Combo
- New Record
- Play Again
- Home

## Phase 13 — Persistence
Status: Completed

Use UserDefaults.

Persist:
- Best Score
- Highest Combo
- Total Games
- Settings

## Phase 14 — Settings
Status: Completed

Implement:
- Sound
- Music
- Haptics
- Reduce Motion

## Phase 15 — Game Feel
Status: Completed

Do not add major features.

Tune:
- Ball weight
- Elasticity
- Drag responsiveness
- Throw velocity
- Collision
- Particles
- Audio
- Haptics
- Combo feedback

This is one of the highest-priority phases.

## Phase 16 — Performance
Status: Completed

Target:
- Stable 60 FPS
- Smooth physics
- Controlled memory usage
- No obvious frame drops

Test:
- Repeated collisions
- Maximum ball count
- Particle bursts
- Long sessions

## Phase 17 — Accessibility
Status: Completed

Implement:
- VoiceOver labels
- Dynamic Type where appropriate
- Reduce Motion
- Contrast checks

## Phase 18 — Localization
Status: Completed

Initial languages:
- English
- Simplified Chinese

Use String Catalog / modern localization infrastructure.

## Phase 19 — QA
Status: Completed

Test:
- Normal gameplay
- Fast drags
- Repeated taps
- Multi-touch
- Edge dragging
- Background / foreground
- Lock / unlock
- Restart
- Quit
- Dark mode
- Light mode
- Different iPhone sizes
- Performance
- Accessibility

## Phase 20 — App Store Preparation
Status: Completed

Prepare:
- App icon
- Screenshots
- Description
- Keywords
- Privacy
- Terms if required
- Age rating

## Phase 21 — Release Candidate
Status: TODO

Requirements:
- No critical bugs
- No obvious crashes
- Stable FPS
- Polished core gameplay
- Polished UI
- Polished audio
- Polished haptics

## Definition of Done

A phase can be marked Completed only when:
1. Feature is implemented.
2. Project builds.
3. Feature runs on device/simulator as appropriate.
4. Manual testing passes.
5. No obvious UI bugs remain.
6. No obvious performance issues remain.
7. Architecture remains consistent with CLAUDE.md.
