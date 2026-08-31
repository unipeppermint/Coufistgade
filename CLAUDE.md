# Bouncy iOS Project

## Project
- Platform: iPhone
- Minimum iOS: iOS 18+
- Language: Swift
- UI: UIKit
- Game / Physics: SpriteKit

## Critical Technology Rules
- Use Swift only.
- Use UIKit for all application UI.
- Use SpriteKit for real-time game physics, balls, collisions, particles, and game-world animation.
- Do NOT use SwiftUI.
- Do NOT use Objective-C.
- Do NOT use Storyboard.
- Do NOT use XIB unless explicitly requested.
- Build UIKit UI programmatically with Auto Layout.
- Prefer native Apple frameworks and avoid third-party dependencies unless explicitly requested.

## Architecture
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

Main ViewControllers:
- HomeViewController
- GameViewController
- ResultViewController
- SettingsViewController

UIKit responsibilities:
- Screens
- Navigation
- HUD
- Buttons
- Labels
- Settings
- Result UI
- App lifecycle

SpriteKit responsibilities:
- Physics
- Ball movement
- Collision
- Game world
- Touch interaction inside the game
- Particles
- Real-time game animation

## Project Structure
Bouncy/
├── App/
├── Core/
├── Models/
├── Views/
├── Components/
├── Game/
├── Services/
└── Resources/

Recommended Game structure:
Game/
├── GameScene.swift
├── GameManager.swift
├── BallEntity.swift
├── BallManager.swift
├── PhysicsManager.swift
├── CollisionManager.swift
├── ScoreManager.swift
├── ComboManager.swift
└── EffectManager.swift

## UIKit Rules
- Use UIViewController and UIView subclasses.
- Use Auto Layout programmatically.
- Prefer NSLayoutConstraint and modern UIKit APIs.
- Prefer UIButton.Configuration for buttons.
- Respect safeAreaLayoutGuide.
- Support Dynamic Type where appropriate.
- Keep each ViewController focused on one responsibility.
- Do not put physics logic inside ViewControllers.
- Do not put UIKit controls inside GameScene.

## UIKit / SpriteKit Boundary
GameViewController owns the SKView and UIKit HUD.
GameScene owns the SpriteKit world and physics.
Communication should use clear delegates, closures, or lightweight state objects.
Avoid using NotificationCenter everywhere.

Do not update UIKit every SpriteKit frame. Update HUD only when relevant values change.

## Game Rules
- MVP mode: 60-second Infinite Casual Mode.
- Player controls one primary ball.
- Normal balls are spawned into the physics world.
- Drag + release controls the primary ball.
- Valid collisions award score and combo.
- Combo window: approximately 2 seconds.
- Base score: 10.
- Initial combo multipliers: 1x, 2x, 3x, 5x, 10x.
- Initial normal ball count: 5–8.
- Maximum normal balls: 10.
- All gameplay constants should live in configuration, not scattered magic numbers.

## Game Feel
Prioritize:
1. Input responsiveness
2. Physics
3. Collision feedback
4. Animation
5. Particles
6. Audio
7. Haptics
8. Score feedback

The ball should feel physical, responsive, elastic, and satisfying.

## Code Quality
- Prefer small types and functions.
- Avoid massive ViewControllers and GameScenes.
- Avoid global mutable state.
- Avoid unnecessary singletons.
- Avoid premature abstractions.
- Avoid force unwraps unless an invariant is truly guaranteed.
- Avoid magic numbers.
- Use modern Swift and APIs compatible with the deployment target.
- Use Swift Concurrency only where it adds value.
- Keep changes focused and avoid unrelated refactoring.

## Development Process
Before coding:
1. Inspect the existing project.
2. Understand current files and architecture.
3. Check deployment target and project settings.
4. Read the docs in /docs.

Implement one roadmap phase at a time.
Do not implement future phases without being asked.

After each phase:
1. Summarize changes.
2. List added and modified files.
3. Explain architecture decisions.
4. Explain how to test.
5. Identify possible issues.
6. Stop.

## Error Handling
When fixing an Xcode error:
1. Identify the exact error.
2. Locate the affected code.
3. Explain the cause.
4. Make the minimal fix.
5. Avoid unrelated refactoring.

## Current Goal
Build a polished, responsive, satisfying core interaction.

Priority:
Ball
→ Physics
→ Touch
→ Collision
→ Feedback
→ Score
→ Combo
→ Replay
