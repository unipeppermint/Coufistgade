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

## 10b. Result Reels

Shipped. A slot-style readout of the finished round, on the result screen.

Purpose: give the end of a round a payoff moment, and give the player a target
that is not simply "a bigger number". The best score rewards one dimension;
the reels reward three at once.

Design constraints, in order of how much they matter:

- **No randomness, ever.** The reels read the round that was just played — hits,
  best combo, score — and land by threshold. The same round always produces the
  same result. This is the whole design: matching all three requires pushing all
  three dimensions in one round, so a lopsided round cannot line up. The player
  learns it instead of waiting for it.
- **No bet, no currency, no purchase.** Nothing is staked to spin, nothing
  accumulates, nothing is bought. See below for why this is load-bearing.
- **The bonus is real score.** It counts toward the total, the best score, and
  achievements. A bonus that did not count would be decoration, and the player
  would learn to ignore it.
- **Thresholds reuse numbers already taught.** They are the achievement targets
  and the combo ladder's own steps, not a second scale to learn.
- **Nothing matched shows the rule, not "+0".** The round that missed is the right
  moment to explain what matching is.

### Why the no-chance property is load-bearing

The App Store age-rating questionnaire's Chance-Based Activities section defines
Simulated Gambling as "betting or wagering without using real money or in-game
currency that can be exchanged for real money". With no bet, no currency, and no
chance, every item in that section stays answered No.

The cost of answering otherwise is not small: one "infrequent simulated gambling"
answer means 13+ globally and R 18+ in Australia. Guideline 5.1.1(ix) separately
requires apps in highly regulated fields, gambling among them, to be submitted by
a legal entity rather than an individual developer — see `APP_STORE.md`, where the
signing team is still unset.

So the constraint is: **reel behaviour may be tuned freely, but a random source
must never be introduced.** Doing so would change the app's rating, its
submission requirements, and possibly its eligibility. `ReelEvaluatorTests`
asserts determinism directly for this reason.

## 11. Monetization

MVP may be completely free.

Reels are **not** a monetization surface. No spin is bought, no bonus is sold, and
no currency exists to sell. Introducing any of those would move the app into
simulated gambling — see §10b.

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
