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
