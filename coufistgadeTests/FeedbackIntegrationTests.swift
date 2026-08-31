//
//  FeedbackIntegrationTests.swift
//  coufistgadeTests
//
//  The question no unit test answers: does a real rally leave nodes behind?
//

import XCTest
import SpriteKit
@testable import coufistgade

final class FeedbackIntegrationTests: XCTestCase {

    private final class AudioSpy: AudioPlaying {
        var isEnabled = true
        var impacts = 0
        func playImpact(_ intensity: ImpactIntensity) { impacts += 1 }
        func playComboMilestone() {}
    }

    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    private func makeLiveScene() -> (GameScene, AudioSpy) {
        let size = CGSize(width: 393, height: 852)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        let window = UIWindow(frame: view.frame)
        window.addSubview(view)
        window.makeKeyAndVisible()
        self.window = window

        let audio = AudioSpy()
        let scene = GameScene(size: size, services: GameServices(audio: audio, haptics: SilentHaptics()))
        scene.scaleMode = .resizeFill
        view.presentScene(scene)
        scene.startNewRound()
        return (scene, audio)
    }

    private func run(for duration: TimeInterval) {
        let deadline = Date().addingTimeInterval(duration)
        while Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
    }

    private func playerBall(in scene: SKScene) -> BallNode? {
        scene.children.compactMap { $0 as? BallNode }.first { $0.kind == .player }
    }

    // MARK: - Node accumulation

    func testEffectNodesDoNotAccumulateAcrossARally() throws {
        let (scene, audio) = makeLiveScene()
        let player = try XCTUnwrap(playerBall(in: scene))

        let baseline = scene.children.count
        // Keep the ball moving hard for several seconds so hits keep landing.
        for _ in 0..<6 {
            player.physicsBody?.velocity = CGVector(dx: 1700, dy: 1200)
            run(for: 0.7)
        }
        let peak = scene.children.count

        // Let every effect finish and remove itself.
        player.removeFromParent()
        run(for: 2.0)
        let settled = scene.children.count

        XCTAssertGreaterThan(audio.impacts, 0, "No collisions happened; test is vacuous.")
        // baseline minus the player ball, which was removed above.
        XCTAssertEqual(settled, baseline - 1, "Effect nodes leaked: \(settled) vs \(baseline - 1)")
        print("MEASURED baseline=\(baseline) peak=\(peak) settled=\(settled) hits=\(audio.impacts)")
    }

    func testConcurrentEffectNodesStayBounded() throws {
        let (scene, audio) = makeLiveScene()
        let player = try XCTUnwrap(playerBall(in: scene))
        var peakEffects = 0

        for _ in 0..<8 {
            player.physicsBody?.velocity = CGVector(dx: 1800, dy: 1300)
            run(for: 0.4)
            let effects = scene.children.filter { $0 is SKEmitterNode || $0 is SKLabelNode }.count
            peakEffects = max(peakEffects, effects)
        }

        XCTAssertGreaterThan(audio.impacts, 0)
        // The collision cooldown caps hits at ~7/s and effects live under 1s,
        // so a handful is expected. A large number would mean they are not
        // clearing and the frame budget is at risk.
        XCTAssertLessThan(peakEffects, 24, "Too many concurrent effect nodes: \(peakEffects)")
        print("MEASURED peakConcurrentEffects=\(peakEffects) hits=\(audio.impacts)")
    }

    // MARK: - Frame rate

    func testTheSceneKeepsUpWhileEffectsAreFiring() throws {
        let (scene, audio) = makeLiveScene()
        let player = try XCTUnwrap(playerBall(in: scene))

        var frames = 0
        let observer = FrameCounter { frames += 1 }
        scene.frameObserver = observer

        player.physicsBody?.velocity = CGVector(dx: 1800, dy: 1300)
        let start = Date()
        run(for: 2.0)
        let elapsed = Date().timeIntervalSince(start)

        let fps = Double(frames) / elapsed
        XCTAssertGreaterThan(audio.impacts, 0)
        // The simulator caps at 60. Anything above 50 means effects are not
        // starving the render loop; a device check is still needed for 120Hz.
        XCTAssertGreaterThan(fps, 50, "Frame rate fell to \(fps) with effects running.")
        print("MEASURED fps=\(fps) frames=\(frames) hits=\(audio.impacts)")
    }

    func testTheSceneKeepsUpWithTheRealAudioEngineRunning() throws {
        let size = CGSize(width: 393, height: 852)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        let window = UIWindow(frame: view.frame)
        window.addSubview(view)
        window.makeKeyAndVisible()
        self.window = window

        // The other frame-rate test uses a spy. This one runs the real engine,
        // because synthesis, an audio graph, and six voices are exactly the
        // work a spy hides.
        let scene = GameScene(
            size: size,
            services: GameServices(audio: AudioService(), haptics: HapticService())
        )
        scene.scaleMode = .resizeFill
        view.presentScene(scene)
        scene.startNewRound()

        var frames = 0
        let observer = FrameCounter { frames += 1 }
        scene.frameObserver = observer

        let player = try XCTUnwrap(playerBall(in: scene))
        player.physicsBody?.velocity = CGVector(dx: 1800, dy: 1300)
        let start = Date()
        run(for: 3.0)
        let fps = Double(frames) / Date().timeIntervalSince(start)

        XCTAssertGreaterThan(fps, 50, "Real audio dragged the frame rate to \(fps).")
        print("MEASURED fpsWithRealAudio=\(fps) score=\(scene.score)")
    }

    // MARK: - Silent services

    func testASceneBuiltWithoutServicesStillScores() {
        let size = CGSize(width: 393, height: 852)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        let scene = GameScene(size: size)
        view.presentScene(scene)

        // The silent path must be a real fallback, not a crash waiting to happen.
        XCTAssertEqual(scene.score, 0)
        XCTAssertNotNil(playerBall(in: scene))
    }
}

/// Counts update(_:) calls, so frame rate can be measured without SKView's
/// debug overlay.
private final class FrameCounter: GameSceneFrameObserver {
    private let onFrame: () -> Void
    init(_ onFrame: @escaping () -> Void) { self.onFrame = onFrame }
    func gameSceneDidUpdate() { onFrame() }
}
