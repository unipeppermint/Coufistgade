# Bouncy Product Requirements Document

## 1. Product Overview

Product name: Bouncy
Platform: iPhone
Minimum OS: iOS 18+
Language: Swift
UI: UIKit
Game / Physics: SpriteKit
Category: Entertainment / Casual / Relaxation / Physics

Bouncy is a casual entertainment iPhone app centered around satisfying ball physics interactions.

It is not intended to be a traditional sports game. It is closer to a physics playground: easy to understand, quick to play, visually satisfying, and relaxing.

## 2. Product Positioning

Core idea:

> Make touching the ball feel good.

The user should immediately understand:
- See the ball.
- Touch the ball.
- Drag it.
- Release it.
- Watch it move and collide.
- Receive satisfying feedback.
- Try for a higher score.

## 3. Target Users

Primary audience:
- Adults roughly 18–40
- Casual game users
- People who enjoy relaxing or satisfying interactions
- Users looking for short entertainment sessions

Typical contexts:
- Commute
- Waiting
- Breaks
- Before sleep
- Short free moments

## 4. Core Value Proposition

> A satisfying physics playground in your pocket.

The user should be able to open the app and start interacting almost immediately.

## 5. Core Experience

Home
→ Play
→ Drag the ball
→ Release
→ Physics
→ Collision
→ Particle / audio / haptic feedback
→ Score
→ Combo
→ Continue
→ Game Over
→ Result
→ Play Again

No mandatory tutorial is required for MVP.

## 6. MVP Features

### Home
- Hero ball
- Play button
- Best score
- Settings
- Achievements

### Game
- Player ball
- Normal balls
- Physics
- Drag / release
- Collision
- Score
- Combo
- Particles
- Sound
- Haptic
- Pause

### Result
- Score
- Best score
- Highest combo
- Newly unlocked achievements
- Play Again
- Home
- New Record feedback

### Settings
- Sound
- Haptics
- Reduce Motion

## 7. MVP Non-Goals

Do not implement in MVP:
- Login / registration
- Backend
- Multiplayer
- Social features
- Online leaderboard
- Cloud sync
- Complex achievements
- Daily missions
- Shops
- Ball collection systems
- Complex skins
- Networking
- Complex monetization

## 8. Session Length

Target session:
30 seconds–3 minutes.

MVP game duration:
60 seconds.

The player should be able to restart within about one second after the result screen is shown.

## 9. Retention

MVP relies on:
- High score
- Highest combo
- Better physical control
- Better game feel
- Replayability

The main motivation is:
"I can do better this time."

## 10. Future Features

Potential future versions:
- New balls
- New themes
- More particles
- New sounds
- Daily challenges
- Ball collection
- Theme collection
- Challenge mode
- Game Center leaderboard

## 10a. Achievements

Shipped, not future. Ten achievements across four metrics.

Purpose: give a player who has beaten their best score a second thing to aim at.
The best score alone answers "can I do better"; achievements answer "what else is
there", which is what keeps a sixty-second game open for a second session.

Design constraints that came out of building it:

- **Ten, fixed.** Not a growing list. The screen is a scroll view over a stack,
  not a table, because there is nothing to recycle.
- **The first one is nearly unmissable.** `firstPoints` (10 points in a round)
  unlocks at the end of a player's first round, so the system announces itself
  rather than staying hidden behind a threshold.
- **Only career metrics show progress.** Scoring 300 last round does not bring
  you closer to "500 in one round", so a progress bar there would be a lie. Only
  cumulative rounds played has real progress.
- **Unlock ids are persisted, never indices.** Inserting an achievement later
  would shift every index and silently convert one player's unlock into another.
- **One cue per round, not per unlock.** Three unlocks in a round play a single
  sound; three in a row sounds like a fault.

Metrics in use: round score, round combo, round hits, cumulative rounds. Best
score and best combo were defined as metrics and then removed — no achievement
used them, and an unused enum case reads as an oversight.

## 11. Monetization

MVP may be completely free.

Future:
- Remove Ads
- Exclusive balls
- Exclusive themes
- Exclusive effects

Avoid disruptive advertising.
Do not place ads during core interaction.

## 12. Success Criteria

MVP success is not measured by feature count.

The first important signal is:

> The user enjoys the physical feel of the ball and wants to play another round.

## 13. Product Priority

1. Interaction
2. Physics
3. Feedback
4. Animation
5. Audio
6. UI
7. Progression
8. Monetization
