//
//  GameScene.swift
//  coufistgade
//
//  Owns the SpriteKit world: physics, boundaries, background (ARCHITECTURE §7).
//  Contains no UIKit controls — the HUD belongs to GameViewController.
//
//  Deliberately an assembler, not an implementer: it wires subsystems together
//  and holds almost no algorithms of its own. Anything here longer than ~15
//  lines belongs in its own type (ARCHITECTURE §27).
//
//  Through Phase 11: a complete 60-second round — throw the ball, score off
//  collisions, chain combos, and the round starts, pauses, and ends.
//  The Result screen is Phase 12.
//

import SpriteKit

final class GameScene: SKScene {

    /// Receives game events. Weak: the view controller owns the scene.
    weak var gameDelegate: GameSceneDelegate?

    #if DEBUG
    /// Frame hook, so tests can measure the render loop without SKView's debug
    /// overlay. Nothing in the app sets this.
    weak var frameObserver: GameSceneFrameObserver?
    #endif

    /// Region balls are allowed to occupy, in scene coordinates. Driven by the
    /// view controller's safe area because the scene itself spans the full
    /// screen for the background to bleed edge to edge.
    private var playableInsets: UIEdgeInsets = .zero

    private let backgroundNode = BackgroundNode()
    private let boundaryNode = BoundaryNode()
    private let playerBall = BallNode(kind: .player)
    private lazy var dragController = BallDragController(ball: playerBall)
    private lazy var ballManager = BallManager(container: self)
    /// Strongly held: `physicsWorld.contactDelegate` is a weak reference.
    private let collisionManager = CollisionManager()
    /// Score and combo, which are wired to each other rather than independent.
    private let round = RoundState()
    let gameManager = GameManager()

    /// Game time, not SpriteKit's absolute `currentTime`. Feeding the latter to
    /// the combo window would lapse a combo while the game sat paused.
    private var gameTime: TimeInterval { gameManager.elapsedTime }
    private let debugInstruments = DebugInstruments()

    private lazy var feedback = FeedbackCoordinator(
        effects: EffectManager(container: self),
        audio: services.audio,
        haptics: services.haptics
    )

    /// Injected, so tests run silently and Phase 14's settings have one place
    /// to reach. Defaults to silent: a scene built with no services behaves
    /// identically apart from sound and vibration.
    private let services: GameServices

    init(size: CGSize, services: GameServices = .silent) {
        self.services = services
        super.init(size: size)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("GameScene is code-only; this app uses no storyboards or nibs.")
    }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        super.didMove(to: view)

        // Cheap guard against didMove firing twice for one scene instance.
        guard backgroundNode.parent == nil else { return }

        physicsWorld.gravity = GameConfiguration.Physics.gravity
        physicsWorld.contactDelegate = collisionManager
        gameManager.delegate = self
        collisionManager.onBallCollision = { [weak self] in self?.handle($0) }

        addChild(backgroundNode)
        addChild(boundaryNode)
        addChild(playerBall)
        debugInstruments.attach(to: self)

        backgroundNode.fill(sceneSize: size)
        rebuildBoundary()
        // Built but idle — GameViewController starts the round once the screen is
        // actually visible.
        resetPlayerBall()
        ballManager.spawnInitialBalls(in: playableRect, avoiding: playerBall)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        // resizeFill keeps scene size == view size, so a resize must re-derive
        // the artwork, the physics edge, and the ball's containment.
        backgroundNode.fill(sceneSize: size)
        rebuildBoundary()
        playerBall.contain(in: playableRect)
        ballManager.containAll(in: playableRect)
    }

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        // Dispatch only. The round advances first so everything downstream sees
        // the same game time, and so the frame that ends the round cannot score.
        gameManager.tick(to: currentTime)
        guard gameManager.isPlaying else { return }

        dragController.update()
        // Physics, and so contacts, run after this — same frame, same clock.
        collisionManager.currentTime = gameTime
        expireComboIfNeeded()
        debugInstruments.sample(body: playerBall.physicsBody, at: currentTime)
        #if DEBUG
        frameObserver?.gameSceneDidUpdate()
        #endif
    }

    // MARK: - Collision

    /// The single place a graded collision arrives.
    ///
    /// Stays a router: score is computed by ScoreManager and reported outward,
    /// and Phase 10's particles and audio will hang off the same call. The
    /// scene decides nothing about what a hit is worth or how it looks.
    private func handle(_ collision: BallCollision) {
        // Contacts can still land on the frame the timer expires (GAMEPLAY §21).
        guard gameManager.isPlaying else { return }

        debugInstruments.report(collision)

        let (combo, score) = round.registerHit(at: gameTime)
        gameDelegate?.gameScene(self, didUpdateCombo: combo)
        gameDelegate?.gameScene(self, didScore: score)

        // Last, so a slow feedback path can never delay the score itself.
        feedback.play(collision: collision, score: score, combo: combo)
    }

    /// Reports a lapse once, on the frame it happens.
    private func expireComboIfNeeded() {
        guard let lapsed = round.expireCombo(at: gameTime) else { return }
        gameDelegate?.gameScene(self, didUpdateCombo: lapsed)
    }

    // MARK: - Score and combo

    var score: Int { round.total }
    var comboCount: Int { round.comboCount }
    var highestCombo: Int { round.highestCombo }
    /// 本局有效碰撞次数。成就判定要用，此前只有 RoundState 内部可见。
    var roundHits: Int { round.scoringCollisionCount }


    // MARK: - Round lifecycle

    /// Play Again is this same call (GAMEPLAY §23).
    func startNewRound() {
        round.reset()
        resetPlayerBall()
        ballManager.spawnInitialBalls(in: playableRect, avoiding: playerBall)
        isPaused = false
        gameManager.start()
    }

    /// GAMEPLAY §24. `isPaused` covers physics and running actions; the timers
    /// stop because they run on game time, which GameManager has halted.
    func pauseRound() {
        guard gameManager.isPlaying else { return }
        gameManager.pause()
        isPaused = true
    }

    func resumeRound() {
        guard gameManager.state == .paused else { return }
        isPaused = false
        gameManager.resume()
    }

    /// Ends the round without waiting for the timer.
    func finishRound() {
        gameManager.finish()
    }

    #if DEBUG
    /// Tops the field up to `Ball.maximumNormalCount`.
    ///
    /// Nothing in the game reaches the maximum — initial spawn is 5–8 and no rule
    /// adds more — so ROADMAP Phase 16's "maximum ball count" test would have
    /// nothing to measure without this.
    func debugFillToMaximumBalls() {
        while ballManager.count < GameConfiguration.Ball.maximumNormalCount {
            guard ballManager.spawnOne(in: playableRect, avoiding: playerBall) != nil else { return }
        }
    }
    #endif

    // MARK: - Touch

    // These four only unwrap the touch and hand off; the gesture logic lives in
    // BallDragController. UITouch cannot be constructed in a test, so keeping
    // this layer trivial is what makes the drag behaviour testable at all.

    /// Everything the drag controller needs from a UITouch, so the four
    /// overrides below stay one line each.
    private func resolve(_ touch: UITouch) -> (ObjectIdentifier, CGPoint, TimeInterval) {
        (ObjectIdentifier(touch), touch.location(in: self), touch.timestamp)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Stop at the first touch that takes the ball; the rest are bystanders.
        for touch in touches {
            let (id, point, time) = resolve(touch)
            if dragController.begin(touch: id, at: point, time: time) { break }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let (id, point, time) = resolve(touch)
            dragController.move(touch: id, to: point, time: time)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let (id, point, time) = resolve(touch)
            dragController.end(touch: id, at: point, time: time)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            dragController.cancel(touch: ObjectIdentifier(touch))
        }
    }

    // MARK: - Playable area

    /// Called by GameViewController whenever the safe area changes.
    func updatePlayableInsets(_ insets: UIEdgeInsets) {
        guard insets != playableInsets else { return }
        playableInsets = insets
        rebuildBoundary()
        playerBall.contain(in: playableRect)
        ballManager.containAll(in: playableRect)
    }

    /// The rect enclosed by the physics boundary.
    var playableRect: CGRect {
        let inset = GameConfiguration.World.boundaryInset
        return CGRect(
            x: playableInsets.left + inset,
            y: playableInsets.bottom + inset,
            width: max(0, size.width - playableInsets.left - playableInsets.right - inset * 2),
            height: max(0, size.height - playableInsets.top - playableInsets.bottom - inset * 2)
        )
    }

    // MARK: - Player ball

    /// Places the ball at rest in the centre of the playable area.
    func resetPlayerBall() {
        let rect = playableRect
        guard rect.width > 0, rect.height > 0 else { return }

        playerBall.position = CGPoint(x: rect.midX, y: rect.midY)
        playerBall.zRotation = 0
        playerBall.physicsBody?.velocity = .zero
        playerBall.physicsBody?.angularVelocity = 0

        debugInstruments.launchIfRequested(playerBall)
    }


    private func rebuildBoundary() {
        boundaryNode.enclose(playableRect)
    }
}

// MARK: - GameManagerDelegate

extension GameScene: GameManagerDelegate {

    func gameManager(_ manager: GameManager, didChangeState state: GameState) {
        gameDelegate?.gameScene(self, didChangeState: state)
    }

    func gameManager(_ manager: GameManager, didUpdateRemainingTime seconds: Int) {
        gameDelegate?.gameScene(self, didUpdateRemainingTime: seconds)
    }

    func gameManagerDidFinishRound(_ manager: GameManager) {
        isPaused = true
        gameDelegate?.gameSceneDidFinishRound(self)
    }
}
