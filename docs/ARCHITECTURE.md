# Bouncy Architecture

## 1. Architecture Philosophy

Principles:
- Simple
- Native
- Maintainable
- Performant

Technology:
- Swift
- UIKit
- SpriteKit

Do not use SwiftUI.
Do not use Storyboard.
Do not use XIB unless explicitly requested.

## 2. High-Level Architecture

AppDelegate
↓
SceneDelegate
↓
UINavigationController
↓
ViewControllers
↓
GameViewController
↓
SKView
↓
GameScene
↓
Game Systems

## 3. App Layer

AppDelegate:
- Application lifecycle

SceneDelegate:
- Window setup
- Root view controller

Use a UINavigationController as the primary navigation container.

## 4. View Controllers

Primary screens:
- HomeViewController
- GameViewController
- ResultViewController
- SettingsViewController
- AchievementsViewController

Each ViewController should have one clear responsibility.

## 5. HomeViewController

Owns:
- Home UI
- Hero ball presentation
- Play button
- Best score
- Settings action

Does not own game physics.

## 6. GameViewController

Owns:
- SKView
- UIKit HUD
- Score label
- Combo label
- Pause button
- Navigation
- Game lifecycle at the screen level

Does not own:
- Physics calculations
- Ball movement
- Collision logic

## 7. SpriteKit

GameScene owns:
- Physics world
- Balls
- Boundaries
- Collision contacts
- Game touch interaction
- Real-time game logic
- SpriteKit particles

## 8. UIKit / SpriteKit Boundary

GameViewController contains SKView and UIKit HUD.

GameScene contains SpriteKit objects.

Communication should use:
- Delegate
- Closure
- Lightweight state object

Avoid NotificationCenter as a general-purpose communication mechanism.

Example:

GameScene
→ Game Event
→ GameViewController
→ HUD update

## 9. GameManager

Responsible for:
- Start
- Pause
- Resume
- Finish
- Restart

## 10. PhysicsManager

Responsible for:
- Gravity
- Friction
- Restitution
- Mass
- Damping
- Physics category configuration

## 11. BallEntity

Represents a ball and its SpriteKit representation.

Should encapsulate:
- Node
- Physics body
- Visual configuration

## 12. BallManager

Responsible for:
- Spawn
- Remove
- Respawn
- Keeping ball counts within configured limits

## 13. CollisionManager

Responsible for:
- Interpreting collision events
- Determining collision intensity
- Triggering game events

## 14. ScoreManager

Responsible for:
- Score
- Base score
- Score calculation
- Reset

## 15. ComboManager

Responsible for:
- Combo count
- Combo window
- Multiplier
- Reset

## 16. EffectManager

Responsible for:
- Impact particles
- Combo effects
- Visual feedback

## 17. AudioManager

Centralized audio service.

Use:
- AVAudioPlayer
- AVAudioEngine

Choose the simplest appropriate implementation.

Reuse loaded audio resources where appropriate.

## 18. HapticManager

Centralized haptic service.

Use:
- Core Haptics when advanced control is needed
- UIKit feedback generators for simple feedback

Do not trigger haptics every frame.

## 19. PersistenceManager

MVP:
UserDefaults

Persist (names as they appear in `PersistenceManager.Key`, all prefixed
`bouncy.`):
- bestScore
- bestCombo
- totalGames
- soundEnabled
- musicEnabled — stored but not shown; see `UI_DESIGN.md` §15
- hapticsEnabled
- reduceMotionEnabled
- unlockedAchievements

These strings are a storage schema, not labels: renaming one silently resets that
value for everyone who already played.

## 19a. AchievementTracker

Pure logic over `PersistenceManager`. Owns no UI and no state of its own: it reads
the round summary plus the store, and answers two questions — what unlocked just
now, and how far along a career achievement is.

Ordering constraint: evaluation must run **after** `store.record(...)`. Career
metrics have to include the round that just ended, or "10 rounds played" stays one
round short forever. The call site carries a comment saying so.

`Achievement.all` is a table, not a switch: the whole difficulty curve is
reviewable in one place, and changing a target touches no logic. Same approach as
`GameConfiguration.Combo.multiplierLadder`.

## 20. Configuration

Use a centralized configuration structure.

Example categories:
- Game duration
- Base score
- Combo window
- Minimum / maximum ball count
- Maximum throw velocity
- Physics values

Do not scatter magic numbers.

## 21. UIKit Layout

All UIKit UI is programmatic.

Use Auto Layout.

Prefer:
- NSLayoutConstraint
- safeAreaLayoutGuide
- UIStackView
- UIButton.Configuration

Avoid frame-based layout as the primary layout mechanism.

## 22. View Lifecycle

Use standard UIViewController lifecycle methods.

Do not access self.view from init.

Typical setup:

viewDidLoad
→ setupUI
→ setupConstraints
→ setupActions

## 23. Game Loop

SpriteKit update() is for real-time game logic.

Do not:
- Perform disk I/O
- Create unnecessary objects
- Make network calls
- Refresh UIKit every frame

Update HUD only when values actually change.

## 24. Threading

SpriteKit node manipulation should occur on the appropriate SpriteKit / main execution context.

Use Swift Concurrency for non-real-time tasks when useful.

Do not introduce concurrency merely for style.

## 25. Performance

Target:
- Stable 60 FPS minimum
- Smooth interaction
- Controlled particle count
- Maximum 10 normal balls in MVP

Avoid:
- Excessive allocations
- Excessive particles
- Repeated audio initialization
- Heavy work in update()

## 26. Testing

Unit-test where practical:
- Score
- Combo
- Game state
- Persistence

Manually test:
- Physics
- Touch
- Collision
- Animation
- Audio
- Haptics
- Performance

## 27. Architecture Rule

Do not create abstractions without a real need.

If a feature requires many protocols, factories, managers, and coordinators without clear value, simplify it.

Simple is better.
