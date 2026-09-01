# Bouncy UI Design

## 1. Design Direction

Keywords:
- Minimal
- Premium
- Playful
- Physical
- Modern

The ball is the visual hero.

UI should support the interaction rather than compete with it.

## 2. Design Philosophy

The UI should recede.

The physical object should stand out.

Avoid traditional sports-game UI and cheap mobile-game aesthetics.

## 3. Color

Primary visual mode:
Dark.

Suggested:
- Near-black background, not necessarily pure black
- Deep gray surfaces
- White primary text
- One high-saturation accent color

The accent can be tied to the active ball theme.

Light mode should also be supported eventually, but it should not simply invert dark-mode colors.

## 4. Home Layout

Programmatic UIKit layout.

Suggested hierarchy:

HomeViewController
- Background
- HeroBallView
- Logo / title
- Best Score
- Primary Play Button
- Settings Button

## 5. Home Hierarchy

Priority:
1. Hero ball
2. Play
3. Best score
4. Settings

The primary action must be obvious immediately.

## 6. Hero Ball

Use:
- Gradient
- Highlight
- Shadow / glow
- Subtle depth cues

Animation:
- Gentle floating / breathing
- Approximately 2–4 seconds per cycle
- No aggressive constant bouncing

## 7. Play Button

Use a rounded capsule or circular treatment.

Avoid generic oversized gradient buttons.

Pressed state:
- Slight scale down
- Spring back

Target duration:
0.15–0.25 sec.

Use UIKit's modern UIButton.Configuration where appropriate.

## 8. Game HUD

Top:
- Score
- Pause

Combo:
- Hidden when inactive
- Appears only when combo > 1

HUD must not obstruct the physics world.

## 9. Score

Normal state:
- Compact and readable

On score:
- Short scale-up animation
- Return to normal size

Example:
1.0 → 1.2 → 1.0

## 10. Combo

Combo should appear only when relevant.

On increase:
- Short scale emphasis
- Optional subtle glow
- Avoid persistent oversized text

## 11. Background

Keep it simple:
- Subtle gradient
- Very light motion if useful

Avoid complex images and busy textures.

## 12. Particles

Particle color should match the ball / theme.

Particles should enhance impact, not cover the screen.

## 13. Result Screen

Center:
- Score

Secondary:
- Best Score
- Highest Combo

Actions:
- Play Again
- Home

Play Again is the primary action.

## 14. New Record

Show:
NEW RECORD

Use:
- Scale
- Glow
- Small particle burst

Keep it premium and restrained.

## 15. Settings

Use native UIKit settings patterns.

Options:
- Sound
- Haptics
- Reduce Motion

Music is intentionally not shown. It was specified here and built as a row, but
no music exists in the app, so the switch stored a preference that nothing read
and carried a "no music in this build" caption. A non-functional control plus
build-language copy is what App Review 2.1 (App Completeness) looks for, so the
row was removed before submission.

`PersistenceManager.musicEnabled` is still stored and still registers a default
of `true`, so restoring the row when music ships costs one enum case and two
catalog strings — no schema change, and existing installs keep their value.

## 15a. Achievements Screen

Reached from a 44pt icon button on Home, beside Settings. Pushed, not presented:
it is a short one-way trip, and the navigation stack already handles the back
gesture.

Layout:
- Title and unlocked count in the header (`3 of 10`), so progress is legible
  before any scrolling
- One row per achievement, ten rows, in the catalog's difficulty order
- Scroll view over a vertical stack, not a table view — ten fixed rows have
  nothing to recycle, and cell reuse is what broke a screen once already
  (`prepareForReuse` clearing a closure)

Row anatomy:
- Locked: dimmed title, detail line, lock glyph
- Unlocked: full-contrast title, detail line, accent check
- Career achievements add a progress bar; round achievements do not

Constraint rule this screen exists to demonstrate: in a scroll view, the vertical
axis binds to `contentLayoutGuide` (it decides how tall the content is) and the
horizontal axis binds to `frameLayoutGuide` (width must come from the screen).
Binding width to the content guide makes label wrapping and content width
mutually dependent, and Auto Layout resolves it to something arbitrary.

The result screen lists only what unlocked this round, using the same row view
with the lock and progress bar suppressed. An empty list renders nothing at all —
no heading, no gap — because most rounds unlock nothing.

## 16. Typography

Prefer system fonts.

Use:
- Semibold / Bold for key numbers
- Regular for supporting text
- Rounded numeric presentation where appropriate

Support Dynamic Type for normal UI text.

## 17. Spacing

Use an 8pt spacing system where practical:
8
16
24
32
48

## 18. Corner Radius

Buttons:
16–24 pt

Cards:
20–28 pt

Tune based on actual visual results.

## 19. Animation

UI transitions:
0.25–0.4 sec

Button feedback:
0.15–0.25 sec

Gameplay feedback:
0.1–0.3 sec

Animations should feel quick and intentional.

## 20. Reduce Motion

When Reduce Motion is enabled:
- Reduce floating motion
- Reduce large scale animations
- Reduce complex transitions
- Reduce excessive particles

Do not disable essential interaction feedback.

## 21. Accessibility

Provide accessibility labels for important controls.

Examples:
- Play Button → "Start Game"
- Pause Button → "Pause Game"
- Settings Button → "Open Settings"

Ensure adequate contrast.

## 22. UIKit Implementation

UI is code-based UIKit.

Do not use Storyboard or SwiftUI.

Use:
- UIView
- UILabel
- UIButton
- UIStackView
- UIImageView
- Auto Layout

Create reusable views only when they provide real value.

## 23. UI Principle

Every UI element should answer:

"Why is this needed?"

If there is no clear answer, remove it.
