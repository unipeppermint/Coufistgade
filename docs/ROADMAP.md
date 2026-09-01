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
- Haptics
- Reduce Motion

Music was implemented as a row and then removed before submission — see
`UI_DESIGN.md` §15.

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

Shipping languages:
- English

Use String Catalog / modern localization infrastructure.

Simplified Chinese was implemented and then removed before submission: the app
ships English only. The string catalogs, `knownRegions`, and the tests that
compared the two languages were all reverted to a single language. The
infrastructure is unchanged, so adding a language back is a catalog edit rather
than a rebuild — see the note in `LocalizationTests` about what a single-language
catalog can and cannot prove.

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
- Dark appearance (the only one: the window forces
  `overrideUserInterfaceStyle = .dark`, so a light-mode device still gets the dark
  palette. `QATests` asserts this rather than testing a light variant that cannot
  occur.)
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

## Phase 20a — Achievements
Status: Completed

Built after Phase 20, which is why it sits out of numeric order: the App Store
metadata had already been drafted and had to be revised afterwards to stop saying
there was nothing to unlock.

Implement:
- Ten achievements across four metrics (round score, round combo, round hits,
  cumulative rounds)
- Achievements screen, reached from Home
- Newly unlocked achievements on the result screen
- One unlock cue per round (sound + haptic)

See `PRD.md` §10a for the design constraints and `UI_DESIGN.md` §15a for the
screen.

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
