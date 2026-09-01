//
//  GameViewController.swift
//  coufistgade
//
//  Drives the round at the screen level (ARCHITECTURE §6): presents the scene,
//  owns the audio and haptic services' lifecycle, routes game events to the HUD,
//  and navigates to the result.
//
//  Owns no physics, no ball movement, no collision logic — and, since the view
//  layer moved to GameScreenView, no layout either.
//
//  The overlay is the pause panel only; the round ends on ResultViewController.
//

import UIKit
import SpriteKit

final class GameViewController: UIViewController {

    enum AccessibilityID {
        static let pauseButton = "game.pauseButton"
    }

    private var scene: GameScene?

    /// The view hierarchy, installed in `loadView`. Typed rather than reached
    /// through `view` so the HUD and overlay need no casting.
    private lazy var screenView = GameScreenView(
        pauseButtonAccessibilityID: AccessibilityID.pauseButton
    )

    /// Owned here, not by the scene, because their lifecycle is the screen's:
    /// the engine should not run while the game is offscreen, and Phase 14's
    /// settings will be applied at this level.
    private let audio: AudioService
    private let haptics: HapticService
    private let store: PersistenceManager
    private let announcer: Announcer
    private let achievements: AchievementTracker

    init(
        audio: AudioService = AudioService(),
        haptics: HapticService = HapticService(),
        store: PersistenceManager = PersistenceManager(),
        announcer: Announcer = Announcer(),
        achievements: AchievementTracker? = nil
    ) {
        self.audio = audio
        self.haptics = haptics
        self.store = store
        self.announcer = announcer
        // 默认与本控制器共用同一个 store，否则成就判定读到的是另一份数据。
        self.achievements = achievements ?? AchievementTracker(store: store)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("GameViewController is code-only; this app uses no storyboards or nibs.")
    }

    // MARK: - Lifecycle

    override func loadView() {
        view = screenView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupActions()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Presenting before the view has real bounds would hand the scene a
        // zero or wrong size, which resizeFill would then bake into the
        // physics boundary.
        presentSceneIfNeeded()
        // The HUD's height is only known once it has laid out, and it grows
        // with Dynamic Type, so the playable area is re-derived here rather
        // than fixed at setup.
        updateScenePlayableArea()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateScenePlayableArea()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Not in didMove: the push animation would eat the first second.
        if scene?.gameManager.state == .idle {
            startRound()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        screenView.skView.isPaused = false
        // Read on each appearance, so a change made in Settings takes effect on
        // the next round without this screen having to be rebuilt.
        audio.isEnabled = store.soundEnabled
        haptics.isEnabled = store.hapticsEnabled
        // Warms the Taptic Engine now rather than on the first collision, where
        // the warm-up latency would break the link between seeing and feeling.
        haptics.prepare()
        // An edge swipe would otherwise be read as a throw drag once Phase 5
        // lands. Input responsiveness outranks the system back gesture here.
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Restore it for the rest of the app on the way out.
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Never let an offscreen scene keep driving the render loop.
        screenView.skView.isPaused = true
        // Nor the audio engine burn power with nothing to play.
        audio.suspend()
    }

    private func setupActions() {
        screenView.onPauseTapped = { [weak self] in self?.handlePauseTapped() }
        screenView.overlay.onPrimaryTapped = { [weak self] in self?.handleOverlayPrimary() }
        screenView.overlay.onSecondaryTapped = { [weak self] in self?.handleOverlaySecondary() }

        // An interruption the player didn't choose must not cost them the round.
        // Covers backgrounding, the app switcher, and an incoming call.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }

    // MARK: - Scene

    private func presentSceneIfNeeded() {
        let skView = screenView.skView
        guard scene == nil, skView.bounds.width > 0, skView.bounds.height > 0 else { return }

        let scene = GameScene(
            size: skView.bounds.size,
            services: GameServices(audio: audio, haptics: haptics)
        )
        scene.gameDelegate = self
        // 1:1 point mapping between scene and view: touch coordinates and the
        // physics boundary both depend on it, so no other mode is safe here.
        scene.scaleMode = .resizeFill
        scene.updatePlayableInsets(screenView.playableInsets)

        skView.presentScene(scene)
        self.scene = scene
    }

    private func updateScenePlayableArea() {
        scene?.updatePlayableInsets(screenView.playableInsets)
    }

    // MARK: - Actions

    private func handlePauseTapped() {
        guard scene?.gameManager.isPlaying == true else { return }
        scene?.pauseRound()
    }

    /// The overlay is the pause panel only now, so Resume is its one action.
    private func handleOverlayPrimary() {
        screenView.overlay.hide()
        scene?.resumeRound()
    }

    /// GAMEPLAY §24: "Quit returns to Home".
    private func handleOverlaySecondary() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func handleWillResignActive() {
        // Pausing a finished round would swap the result panel for a pause panel.
        guard scene?.gameManager.isPlaying == true else { return }
        scene?.pauseRound()
    }

    // MARK: - Round

    private func startRound() {
        screenView.hud.reset()
        scene?.startNewRound()
        #if DEBUG
        if DebugOptions.maxBalls { scene?.debugFillToMaximumBalls() }
        scheduleAutoPauseIfRequested()
        #endif
    }

    #if DEBUG
    private func scheduleAutoPauseIfRequested() {
        guard DebugOptions.autoPause else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + DebugOptions.autoPauseDelay) { [weak self] in
            self?.scene?.pauseRound()
        }
    }
    #endif
}

// MARK: - GameSceneDelegate

extension GameViewController: GameSceneDelegate {

    /// Arrives on a scoring collision, never per frame (ARCHITECTURE §23).
    func gameScene(_ scene: GameScene, didScore event: ScoreEvent) {
        screenView.hud.apply(score: event)
    }

    /// Arrives when the combo advances or lapses — the scene reports this
    /// before the score, so the HUD already has the emphasis it needs.
    func gameScene(_ scene: GameScene, didUpdateCombo event: ComboEvent) {
        screenView.hud.apply(combo: event)

        // Milestones only. Announcing every hit would queue faster than
        // VoiceOver can speak, and the user would still be hearing hit four when
        // the round ended.
        guard GameConfiguration.Combo.milestoneCounts.contains(event.count) else { return }
        announcer.announce(Strings.comboAnnouncement(count: event.count, multiplier: event.multiplier))
    }

    func gameScene(_ scene: GameScene, didUpdateRemainingTime seconds: Int) {
        screenView.hud.apply(remainingSeconds: seconds)
    }

    /// Driven from state, not from each action, so what's on screen always
    /// follows what the game actually is.
    func gameScene(_ scene: GameScene, didChangeState state: GameState) {
        switch state {
        case .paused:
            screenView.overlay.show(Self.pausedContent)
            announcer.announceImmediately(Strings.paused)
        case .playing:
            screenView.overlay.hide()
        case .idle, .finished:
            // .finished is handled in gameSceneDidFinishRound, which has the
            // score to show.
            break
        }
        // No throwing through the overlay.
        screenView.setGameInteractionEnabled(state == .playing)
    }

    func gameSceneDidFinishRound(_ scene: GameScene) {
        // Bypasses the rate limit: the round ending is the one thing the user
        // must hear, even if a combo was announced a moment ago.
        announcer.announceImmediately(Strings.roundEndAnnouncement(score: scene.score))

        // Filed before the result is built, so the badge comes from the write
        // itself rather than a second comparison that could disagree with it.
        let record = store.record(score: scene.score, combo: scene.highestCombo)

        // 必须在 store.record 之后：生涯类成就（累计局数、历史最高）要把刚结束
        // 这一局算进去，否则"累计 10 局"永远差一局才解锁。
        let unlocked = achievements.evaluate(
            RoundSummary(
                score: scene.score,
                highestCombo: scene.highestCombo,
                hits: scene.roundHits
            )
        )
        presentResult(
            RoundResult(
                score: scene.score,
                roundCombo: scene.highestCombo,
                bestScore: store.bestScore,
                bestCombo: store.bestCombo,
                isNewRecord: record.isNewBestScore,
                unlockedAchievements: unlocked
            )
        )
    }

    private func presentResult(_ result: RoundResult) {
        let resultViewController = ResultViewController(
            result: result,
            audio: audio,
            haptics: haptics
        )
        resultViewController.onPlayAgain = { [weak self] in
            // Pops back to this screen, which is still beneath, rather than
            // building a second game screen on top of the first.
            self?.navigationController?.popViewController(animated: true)
            self?.startRound()
        }
        resultViewController.onHome = { [weak self] in
            self?.navigationController?.popToRootViewController(animated: true)
        }
        navigationController?.pushViewController(resultViewController, animated: true)
    }

    private static let pausedContent = GameOverlayView.Content(
        title: Strings.paused,
        detail: nil,
        primaryTitle: Strings.resume,
        secondaryTitle: Strings.quit
    )

}
