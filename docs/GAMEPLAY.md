# Bouncy Gameplay Design

## 1. Game Mode

MVP uses:
- Infinite Casual Mode concept
- 60-second round
- Score-driven replay

There are no traditional levels in MVP.

## 2. Game Start

Player taps PLAY.

The game creates:
- 1 Player Ball
- 5–8 Normal Balls

Balls should spawn without severe overlap.

## 3. Game Area

The physics world occupies most of the screen.

HUD:
- Score at the top
- Combo when active
- Pause button

Keep the lower and central game area visually clear.

## 4. Player Ball

The Player Ball:
- Is slightly larger than normal balls.
- Has a distinctive visual treatment.
- Produces stronger feedback.
- Is directly controlled by the user.

Suggested initial diameter:
50–70 pt, tuned on device.

## 5. Normal Balls

Normal balls:
- Suggested diameter: 35–55 pt
- Spawn at safe random positions
- Participate in physics
- Can collide with the player ball
- May participate in chain reactions in future versions

Initial count:
5–8

Maximum:
10

Minimum:
4

## 6. Input

Primary interaction:
Drag + Release.

Tap and swipe may be supported naturally by the same interaction model.

When the player touches the Player Ball:
- Enter dragging state.
- Follow the finger with slight physical lag.

When released:
- Apply velocity based on drag direction and speed.

## 7. Throw Velocity

Conceptual calculation:

velocity ≈ dragDistance / dragDuration

Clamp velocity to:
- Minimum velocity
- Maximum velocity

Do not allow unrealistic velocities.

The exact values must be tuned on a physical device.

## 8. Physics

Initial tuning values are starting points only:

gravity: 0 or very small
friction: 0.15
restitution: 0.82
linearDamping: 0.15
angularDamping: 0.2

All values should be centralized in GameConfiguration / PhysicsConfiguration.

## 9. Boundaries

The player ball should remain inside the playable world.

Use SpriteKit physics boundaries.

Avoid visible clipping or tunneling at high velocities.

## 10. Collision

When Player Ball hits a valid Normal Ball:
- Award score.
- Increase combo.
- Trigger impact particles.
- Play collision sound.
- Trigger appropriate haptic feedback.

## 11. Impact Intensity

Calculate collision intensity from impact velocity.

Suggested tiers:
- Low
- Medium
- High

Feedback should scale with impact intensity.

## 12. Feedback

### Low
- Small particle burst
- Light sound

### Medium
- Larger particle burst
- Stronger sound
- Light / medium haptic

### High
- Larger particle burst
- Strong sound
- Stronger haptic
- Additional visual emphasis

Never trigger haptics every frame.

## 13. Score

Base score:
10 points.

Conceptually:

score = baseScore × comboMultiplier

Keep scoring configuration centralized.

## 14. Combo

A valid scoring collision increments combo.

Combo window:
approximately 2 seconds.

If no valid collision occurs within the window:
- Combo resets.

## 15. Combo Multipliers

Initial proposal:
- Combo 0–1: 1x
- Combo 2–3: 2x
- Combo 4–6: 3x
- Combo 7–9: 5x
- Combo 10+: 10x

These values should be play-tested and tuned.

## 16. Combo Feedback

Combo 2:
- Small UI emphasis

Combo 4:
- Stronger score animation

Combo 7:
- Special particle treatment

Combo 10:
- Major but tasteful feedback

Do not overwhelm the player.

## 17. Chain Reactions

Future feature.

Example:
Player Ball
→ Normal Ball
→ Normal Ball
→ Normal Ball

If the next collision happens within a short window, it may contribute to the combo.

Do not implement until the basic loop is polished.

## 18. Ball Respawn

When normal ball count falls below the minimum:
- Spawn new balls.

Do not instantly respawn directly on top of the player.

## 19. Difficulty

MVP should keep difficulty simple.

Future difficulty can vary:
- Ball count
- Ball speed
- Ball size
- Spawn position
- Obstacles

Do not add obstacles to MVP unless play-testing proves the basic loop needs them.

## 20. Game Duration

Round duration:
60 seconds.

The timer must be based on game time, not a UI animation.

## 21. Game End

When 60 seconds expires:
- Stop gameplay.
- Stop scoring.
- Stop combo progression.
- Present Result screen.

## 22. Result

Display:
- Score
- Best Score
- Highest Combo

If current score exceeds previous best:
- Show NEW RECORD.

## 23. Replay

Primary action:
Play Again

Secondary:
Home

The user should be able to start another round immediately.

## 24. Pause

Pause should:
- Stop physics
- Stop game timer
- Stop combo timer
- Pause relevant effects

Resume returns the game to the previous state.

Quit returns to Home or Result as appropriate.

## 25. Game State

Use an enum such as:

idle
playing
paused
finished

Avoid multiple Boolean flags representing mutually exclusive states.

## 26. Game Feel

Highest priority:
- Input responsiveness
- Ball weight
- Ball elasticity
- Predictable physics
- Collision impact
- Visual feedback
- Audio feedback
- Haptic feedback

If a feature harms these qualities, postpone the feature.

## 27. Result Reels

### Purpose

A slot-style readout of the round the player just finished, shown on the result
screen.

### The one invariant

**No randomness.** Three reels each read one dimension of the finished round and
land on a symbol by threshold. The same round always spins the same result.

This is not a compromise made to satisfy App Store review — it is the better
design. Matching all three requires pushing all three dimensions at once, so a
lopsided round cannot line up. The player can learn it rather than wait for it.

It does also settle the review question. The age-rating questionnaire's
Chance-Based Activities section defines Simulated Gambling as "betting or
wagering without using real money or in-game currency that can be exchanged for
real money". There is no bet here, no currency, and no chance — so every item in
that section stays answered No, and the app keeps its rating. A single
"infrequent simulated gambling" answer would mean 13+ globally and R 18+ in
Australia.

### Reels

| Reel | Reads | Meaning |
|---|---|---|
| Left | Round hits | Volume |
| Middle | Round best combo | Chaining |
| Right | Round score, **before bonus** | Result |

### Symbols

Ascending: Cherry, Bell, Star, Seven.

Thresholds reuse numbers the player has already been taught, rather than
introducing a second standard:

| Reel | Cherry | Bell | Star | Seven |
|---|---|---|---|---|
| Hits | 0 | 5 | 12 | 25 |
| Chain | 0 | 2 | 4 | 7 |
| Score | 0 | 100 | 500 | 1000 |

Hits 25 is the `busyRound` achievement. Chain 2 / 4 / 7 are the combo ladder's
own steps (§15) and the counts that already earn a milestone cue (§16). Score
100 / 500 / 1000 are the `century` / `fiveHundred` / `thousand` achievements.

### Payouts

Three matching (a line):

| Line | Bonus |
|---|---|
| Cherry | 20 |
| Bell | 60 |
| Star | 150 |
| Seven | 400 |

Two matching pays only at the top tiers — 30 for Star, 80 for Seven, nothing
below. "Exactly two alike" is a common shape with four symbols across three
reels; paying every instance would leave the bonus row lit almost every round,
and a line would stop being an event.

The Cherry line pays despite marking a poor round. It is deliberate: it happens
on the first round, which teaches the matching rule without a tutorial — the same
tactic as the achievement list opening with one that is near-certain. 20 points
is negligible in any round.

### Ordering

Four steps at the end of a round, none interchangeable:

1. Evaluate the reels against the **pre-bonus** score. Reading the bonused score
   would make the reels read their own output — a Star line pushes 900 to 1050,
   which re-evaluates as Seven.
2. Total = round score + bonus.
3. Record the total. The bonus is earned score, so it counts toward the best
   score.
4. Judge achievements on the total, after recording (§20a's rule). Judging on
   the pre-bonus score would show 520 on screen while "score 500 in a round"
   stayed locked.

### Presentation

Reels settle left to right, staggered, then the bonus appears and the large total
climbs from the round score to the total. That climb is where the bonus becomes
the player's own — without it, the bonus is just another line of text.

Reduce Motion skips the spin and the climb but **keeps** the sound and haptics: it
is a preference about motion, not about feedback.

Nothing matched shows the rule instead of "+0" — the round that did not match is
the right moment to explain what matching is.
