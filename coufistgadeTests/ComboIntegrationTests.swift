//
//  ComboIntegrationTests.swift
//  coufistgadeTests
//
//  Checks the parts of the combo system that only exist once the pieces are
//  wired together: the order events reach the delegate, and whether the
//  multiplier actually reaches the score.
//

import XCTest
import SpriteKit
@testable import coufistgade

final class ComboIntegrationTests: XCTestCase {


    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    private func makeLiveScene() -> (GameScene, GameSceneDelegateSpy) {
        let size = CGSize(width: 393, height: 852)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        let window = UIWindow(frame: view.frame)
        window.addSubview(view)
        window.makeKeyAndVisible()
        self.window = window

        let scene = GameScene(size: size)
        scene.scaleMode = .resizeFill
        let spy = GameSceneDelegateSpy()
        scene.gameDelegate = spy
        view.presentScene(scene)
        // Phase 11 gates scoring on a live round; an idle scene scores nothing.
        scene.startNewRound()
        return (scene, spy)
    }

    private func run(until isDone: () -> Bool, timeout: TimeInterval = 6) {
        let deadline = Date().addingTimeInterval(timeout)
        while !isDone(), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
    }

    // MARK: - Ordering

    func testComboIsReportedBeforeTheScoreItMultiplies() throws {
        let (scene, spy) = makeLiveScene()
        let player = try XCTUnwrap(
            scene.children.compactMap { $0 as? BallNode }.first { $0.kind == .player }
        )
        player.physicsBody?.velocity = CGVector(dx: 1600, dy: 1100)

        run(until: { spy.scores.count >= 2 })

        XCTAssertGreaterThanOrEqual(spy.calls.count, 2)
        // Every score must be immediately preceded by its combo: the score is
        // computed from the multiplier, and the HUD escalates the score pop
        // using the combo's emphasis.
        for (index, call) in spy.calls.enumerated() where call == "score" {
            XCTAssertGreaterThan(index, 0, "A score arrived with no combo before it.")
            XCTAssertEqual(spy.calls[index - 1], "combo", "Out of order at \\(index).")
        }
    }

    // MARK: - Multiplier reaching the score

    func testChainedHitsAreWorthMoreThanTheFirstHit() throws {
        let (scene, spy) = makeLiveScene()
        let player = try XCTUnwrap(
            scene.children.compactMap { $0 as? BallNode }.first { $0.kind == .player }
        )
        // Hard and fast, so hits land inside the 2s window.
        player.physicsBody?.velocity = CGVector(dx: 1800, dy: 1300)

        run(until: { spy.scores.count >= 4 })

        let first = try XCTUnwrap(spy.scores.first)
        XCTAssertEqual(first.points, GameConfiguration.Score.base, "First hit should pay 1x.")
        XCTAssertEqual(first.multiplier, 1)

        // Phase 8's scoring was flat; the ladder must now actually bite.
        if spy.scores.count >= 2 {
            let laterMultipliers = spy.scores.dropFirst().map(\.multiplier)
            XCTAssertTrue(
                laterMultipliers.contains { $0 > 1 },
                "No hit ever paid more than 1x: multipliers=\\(spy.scores.map(\\.multiplier))"
            )
        }
        print("MEASURED points=\(spy.scores.map(\.points)) multipliers=\(spy.scores.map(\.multiplier))")
    }

    func testSceneTotalMatchesTheSumOfMultipliedAwards() throws {
        let (scene, spy) = makeLiveScene()
        let player = try XCTUnwrap(
            scene.children.compactMap { $0 as? BallNode }.first { $0.kind == .player }
        )
        player.physicsBody?.velocity = CGVector(dx: 1700, dy: 1200)

        run(until: { spy.scores.count >= 3 })

        XCTAssertEqual(scene.score, spy.scores.map(\.points).reduce(0, +))
        XCTAssertEqual(scene.comboCount, spy.combos.last?.count)
    }

    // MARK: - Expiry through the frame loop

    func testAnIdleGapLapsesTheComboAndReportsItOnce() throws {
        let (scene, spy) = makeLiveScene()
        let player = try XCTUnwrap(
            scene.children.compactMap { $0 as? BallNode }.first { $0.kind == .player }
        )
        player.physicsBody?.velocity = CGVector(dx: 1700, dy: 1200)

        run(until: { spy.scores.count >= 2 })

        // Remove the player ball outright rather than parking it.
        //
        // Parking is not enough: a stationary player is still hit by drifting
        // normal balls, and contact reporting lives on the player's side, so
        // "idle" kept scoring. Taking it out of the world is the only way to
        // guarantee no further contacts.
        player.removeFromParent()
        let combosBeforeIdle = spy.combos.count
        let scoresBeforeIdle = spy.scores.count

        run(until: { false }, timeout: GameConfiguration.Combo.window + 1.0)

        XCTAssertEqual(spy.scores.count, scoresBeforeIdle, "The idle period was not idle.")

        XCTAssertEqual(scene.comboCount, 0, "The combo never lapsed.")
        // Exactly one lapse report, not one per frame.
        let lapses = spy.combos.suffix(from: combosBeforeIdle).filter { $0.count == 0 }
        XCTAssertEqual(lapses.count, 1, "Lapse reported \\(lapses.count) times.")
    }

    func testHighestComboOutlivesALapse() throws {
        let (scene, spy) = makeLiveScene()
        let player = try XCTUnwrap(
            scene.children.compactMap { $0 as? BallNode }.first { $0.kind == .player }
        )
        player.physicsBody?.velocity = CGVector(dx: 1700, dy: 1200)

        run(until: { spy.combos.contains { $0.count >= 2 } })
        player.removeFromParent()
        let peak = spy.combos.map(\.count).max() ?? 0
        run(until: { scene.comboCount == 0 }, timeout: GameConfiguration.Combo.window + 1.0)

        XCTAssertEqual(scene.comboCount, 0)
        XCTAssertEqual(scene.highestCombo, peak)
        XCTAssertGreaterThanOrEqual(scene.highestCombo, 2)
    }

    // MARK: - Reset

    func testResetClearsScoreAndCombo() {
        let (scene, _) = makeLiveScene()

        scene.startNewRound()

        XCTAssertEqual(scene.score, 0)
        XCTAssertEqual(scene.comboCount, 0)
        XCTAssertEqual(scene.highestCombo, 0)
    }

    // MARK: - Controller

    func testTheControllerShowsAComboThatArrivesFromTheScene() throws {
        let sut = GameViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = sut
        window.makeKeyAndVisible()
        self.window = window
        sut.view.layoutIfNeeded()

        let scene = try XCTUnwrap(
            sut.view.subviews.compactMap { ($0 as? SKView)?.scene as? GameScene }.first
        )
        sut.gameScene(
            scene,
            didUpdateCombo: ComboEvent(count: 5, multiplier: 3, emphasis: .strong, isVisible: true)
        )
        sut.gameScene(scene, didScore: ScoreEvent(points: 30, total: 130, multiplier: 3))

        let hud = try XCTUnwrap(findHUD(in: sut.view))
        XCTAssertEqual(hud.displayedScoreText, "130")
        XCTAssertEqual(hud.displayedMultiplierText, "×3")
        XCTAssertTrue(hud.isComboVisible)
    }

    private func findHUD(in view: UIView) -> GameHUDView? {
        for subview in view.subviews {
            if let hud = subview as? GameHUDView { return hud }
            if let nested = findHUD(in: subview) { return nested }
        }
        return nil
    }
}
