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

## 28. 远程推送 / Firebase（CocoaPods）

项目唯一的第三方依赖。CLAUDE.md 的默认是不引第三方，这里是显式例外：远程推送
要走 FCM。

**打开项目用 `coufistgade.xcworkspace`，不是 `.xcodeproj`。**
命令行同理：`xcodebuild -workspace coufistgade.xcworkspace -scheme coufistgade`。
用 `.xcodeproj` 会因为找不到 Pods 而链接失败。

依赖只有 `FirebaseMessaging`，装进来 8 个 pod（Core / Installations /
GoogleUtilities / GoogleDataTransport / nanopb / PromisesObjC 都是它的传递依赖）。
Analytics 没装：FCM 不需要它，装了反而多一份数据收集要在 App Privacy 里申报。

### 代码边界

`PushNotificationService`（Services/）是唯一 import Firebase 的文件。AppDelegate
只做两件事：调 `configure()`，以及把系统给的 APNs token 转发进去。其余代码完全
不知道 Firebase 存在 —— 将来换服务商，或按 Firebase 的 CocoaPods 弃用公告迁到
SPM，改动都收在那一个文件里。

两处刻意做成显式而非依赖框架魔法：

1. Info.plist 里 `FirebaseAppDelegateProxyEnabled = false`。Firebase 默认会在
   运行时 swizzle AppDelegate 的推送回调；关掉之后必须由 AppDelegate 手动把
   token 交给 Messaging。漏掉那一步不会报错，只是永远拿不到 FCM token。
2. `configure()` 在缺 `GoogleService-Info.plist` 时安静返回 false。
   `FirebaseApp.configure()` 缺文件时是 fatalError，会让整个 app 起不来；推送
   是附加功能，不该阻断游戏。

### 三处非默认的构建设置

都是接 CocoaPods 时被迫改的，不是偏好：

- `ENABLE_USER_SCRIPT_SANDBOXING = NO`。CocoaPods 嵌入 framework 的那一步是
  shell 脚本调 rsync，Xcode 15 起默认开启的脚本沙盒会拒绝它写进
  `.app/Frameworks/`。同时写进 Podfile 的 `post_install`，避免以后被复原。
- `IPHONEOS_DEPLOYMENT_TARGET` 手动改回 `18.0`。首次 `pod install` 把 app
  target 从 18.0 压到了 16.6，与本项目的 iOS 18+ 冲突。二次 `pod install` 不再
  重写，所以只需修一次。
- `CODE_SIGN_ENTITLEMENTS = coufistgade/coufistgade.entitlements`，两个
  configuration 都加。entitlements 文件同时加进了同步文件夹的
  `membershipExceptions`（跟 Info.plist 一样），否则它会作为资源被打进 .app。

### 还需要人做的事

1. Firebase 控制台建一个 bundle id 为 `com.cclv.coufistgade` 的 iOS App，下载
   `GoogleService-Info.plist` 放进 `coufistgade/`。文件夹是 synchronized root
   group，放进去就自动进 target，不需要在 Xcode 里手动添加。
2. Apple Developer 后台建 APNs Auth Key（.p8），上传到 Firebase 控制台的
   Cloud Messaging 设置里。没有这一步，Firebase 发不出推送。
3. 设 `DEVELOPMENT_TEAM` 并开 Push Notifications capability。目前签名是
   Automatic 且没有 team，模拟器能编译，但真机拿不到 APNs token。
4. **推送只能在真机验证。** 模拟器可以用
   `xcrun simctl push <device> com.cclv.coufistgade payload.json` 测通知的显示与
   点击，但拿不到真的 APNs/FCM token。

`aps-environment` 写的是 `development`，覆盖真机调试与 TestFlight；App Store
分发时签名会按发布描述文件换成 production，不需要另开一份 Release entitlements。

### 一个到期时间

`pod install` 会打印：Firebase 在 **2026 年 10 月**之后不再向 CocoaPods 发布新
版本，官方方向是 SPM。当前锁定的 12.18.0 会一直可用，但之后拿不到更新，含安全
修复。迁移时机是个决定，不是紧急项。
