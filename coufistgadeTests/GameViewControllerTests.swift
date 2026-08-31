//
//  GameViewControllerTests.swift
//  coufistgadeTests
//

import XCTest
import SpriteKit
@testable import coufistgade

final class GameViewControllerTests: XCTestCase {

    private func makeSUT(
        size: CGSize = CGSize(width: 393, height: 852)
    ) -> GameViewController {
        let sut = GameViewController()
        sut.loadViewIfNeeded()
        sut.view.frame = CGRect(origin: .zero, size: size)
        sut.view.setNeedsLayout()
        sut.view.layoutIfNeeded()
        return sut
    }

    private func skView(in sut: GameViewController) -> SKView? {
        sut.view.subviews.compactMap { $0 as? SKView }.first
    }

    private func findView(id: String, in root: UIView) -> UIView? {
        if root.accessibilityIdentifier == id { return root }
        for child in root.subviews {
            if let hit = findView(id: id, in: child) { return hit }
        }
        return nil
    }

    // MARK: - Scene hosting

    func testPresentsGameSceneAfterLayout() throws {
        let sut = makeSUT()
        let view = try XCTUnwrap(skView(in: sut))

        XCTAssertTrue(view.scene is GameScene)
    }

    func testSceneMatchesViewSizeOneToOne() throws {
        let size = CGSize(width: 393, height: 852)
        let sut = makeSUT(size: size)
        let scene = try XCTUnwrap(skView(in: sut)?.scene)

        // Anything other than 1:1 would desync touch points from node
        // positions once Phase 5 adds dragging.
        XCTAssertEqual(scene.scaleMode, .resizeFill)
        XCTAssertEqual(scene.size, size)
    }

    func testSKViewFillsTheScreenIncludingUnsafeArea() throws {
        let sut = makeSUT()
        let view = try XCTUnwrap(skView(in: sut))

        // The gradient must bleed edge to edge; only the physics boundary is
        // inset to the safe area.
        XCTAssertEqual(view.frame, sut.view.bounds)
    }

    func testPresentsSceneOnlyOnceAcrossRepeatedLayouts() throws {
        let sut = makeSUT()
        let first = try XCTUnwrap(skView(in: sut)?.scene)

        sut.view.setNeedsLayout()
        sut.view.layoutIfNeeded()
        sut.viewDidLayoutSubviews()

        XCTAssertIdentical(first, skView(in: sut)?.scene, "Layout passes must not re-present.")
    }

    func testDoesNotPresentSceneWithZeroBounds() {
        let sut = GameViewController()
        sut.loadViewIfNeeded()
        sut.view.frame = .zero
        sut.view.layoutIfNeeded()

        XCTAssertNil(skView(in: sut)?.scene)
    }

    // MARK: - Render loop lifecycle

    func testSceneRunsWhileVisibleAndPausesOffscreen() throws {
        let sut = makeSUT()
        let view = try XCTUnwrap(skView(in: sut))

        sut.beginAppearanceTransition(true, animated: false)
        sut.endAppearanceTransition()
        XCTAssertFalse(view.isPaused)

        sut.beginAppearanceTransition(false, animated: false)
        sut.endAppearanceTransition()
        XCTAssertTrue(view.isPaused, "An offscreen scene must not drive the render loop.")
    }

    // MARK: - Navigation

    func testPauseButtonIsLabelledAndMeetsTouchTarget() throws {
        let sut = makeSUT()
        let pause = try XCTUnwrap(
            findView(id: GameViewController.AccessibilityID.pauseButton, in: sut.view)
        )

        // UI_DESIGN §21 names this label explicitly.
        XCTAssertEqual(pause.accessibilityLabel, Strings.pauseGameLabel)
        XCTAssertGreaterThanOrEqual(pause.bounds.width, Theme.Layout.minimumTouchTarget)
        XCTAssertGreaterThanOrEqual(pause.bounds.height, Theme.Layout.minimumTouchTarget)
    }

    func testHomeCanReachGameAndGameCanPopBack() throws {
        let home = HomeViewController()
        let nav = UINavigationController(rootViewController: home)
        home.loadViewIfNeeded()

        nav.pushViewController(GameViewController(), animated: false)
        XCTAssertTrue(nav.topViewController is GameViewController)

        nav.popViewController(animated: false)
        XCTAssertTrue(nav.topViewController is HomeViewController, "The player must not be trapped.")
    }

    func testInteractivePopIsDisabledOnlyWhileGameIsVisible() throws {
        let nav = UINavigationController(rootViewController: HomeViewController())
        let sut = makeSUT()
        nav.pushViewController(sut, animated: false)

        sut.beginAppearanceTransition(true, animated: false)
        sut.endAppearanceTransition()
        // An edge swipe would otherwise be misread as a throw drag in Phase 5.
        XCTAssertEqual(nav.interactivePopGestureRecognizer?.isEnabled, false)

        sut.beginAppearanceTransition(false, animated: false)
        sut.endAppearanceTransition()
        XCTAssertEqual(nav.interactivePopGestureRecognizer?.isEnabled, true)
    }

    // MARK: - UIKit / SpriteKit boundary

    func testHUDControlsLiveInUIKitNotInTheScene() throws {
        let sut = makeSUT()
        let scene = try XCTUnwrap(skView(in: sut)?.scene)

        // ARCHITECTURE §8: no UIKit controls inside GameScene.
        XCTAssertNotNil(findView(id: GameViewController.AccessibilityID.pauseButton, in: sut.view))
        XCTAssertFalse(scene.children.contains { $0.name == "pauseButton" })
    }

    // MARK: - Playable area vs HUD

    func testPlayableAreaStartsBelowTheHUD() throws {
        let sut = GameViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = sut
        window.makeKeyAndVisible()
        sut.view.layoutIfNeeded()

        let scene = try XCTUnwrap(
            sut.view.subviews.compactMap { ($0 as? SKView)?.scene as? GameScene }.first
        )
        let hud = try XCTUnwrap(findScoreHUD(in: sut.view))

        // Scene y is flipped relative to UIKit, so the playable ceiling is
        // measured down from the top of the view.
        let ceilingFromTop = sut.view.bounds.height - scene.playableRect.maxY

        XCTAssertGreaterThanOrEqual(
            ceilingFromTop, hud.frame.maxY,
            "Balls can drift behind the score readout."
        )
        window.isHidden = true
    }

    func testPlayableAreaClearsTheHUDAtAccessibilityTextSizes() throws {
        let sut = GameViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = sut
        window.makeKeyAndVisible()
        sut.view.layoutIfNeeded()

        // The HUD grows with Dynamic Type; the boundary must follow it rather
        // than sit at a hardcoded offset.
        sut.setOverrideTraitCollection(
            UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge),
            forChild: sut
        )
        sut.view.layoutIfNeeded()

        let scene = try XCTUnwrap(
            sut.view.subviews.compactMap { ($0 as? SKView)?.scene as? GameScene }.first
        )
        let hud = try XCTUnwrap(findScoreHUD(in: sut.view))
        let ceilingFromTop = sut.view.bounds.height - scene.playableRect.maxY

        XCTAssertGreaterThanOrEqual(ceilingFromTop, hud.frame.maxY)
        window.isHidden = true
    }

    private func findScoreHUD(in view: UIView) -> ScoreHUDView? {
        for subview in view.subviews {
            if let hud = subview as? ScoreHUDView { return hud }
            if let nested = findScoreHUD(in: subview) { return nested }
        }
        return nil
    }
}
