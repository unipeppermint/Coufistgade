//
//  HomeViewControllerTests.swift
//  coufistgadeTests
//

import XCTest
@testable import coufistgade

final class HomeViewControllerTests: XCTestCase {

    private func makeSUT(bestScore: Int? = nil) -> HomeViewController {
        let defaults = UserDefaults(suiteName: "HomeViewControllerTests.\(UUID().uuidString)")!
        if let bestScore {
            defaults.set(bestScore, forKey: "bouncy.bestScore")
        }
        let sut = HomeViewController(store: PersistenceManager(defaults: defaults))
        sut.loadViewIfNeeded()
        return sut
    }

    /// Depth-first search so tests locate controls the same way an
    /// accessibility client would, rather than via private properties.
    private func findView(id: String, in root: UIView) -> UIView? {
        if root.accessibilityIdentifier == id { return root }
        for child in root.subviews {
            if let hit = findView(id: id, in: child) { return hit }
        }
        return nil
    }

    private func layout(_ sut: UIViewController, size: CGSize = CGSize(width: 393, height: 852)) {
        sut.view.frame = CGRect(origin: .zero, size: size)
        sut.view.setNeedsLayout()
        sut.view.layoutIfNeeded()
    }

    // MARK: - Accessibility

    func testPlayButtonExposesStartGameLabel() throws {
        let sut = makeSUT()
        let play = try XCTUnwrap(
            findView(id: HomeViewController.AccessibilityID.playButton, in: sut.view)
        )

        XCTAssertEqual(play.accessibilityLabel, Strings.startGameLabel)
    }

    func testSettingsButtonExposesOpenSettingsLabel() throws {
        let sut = makeSUT()
        let settings = try XCTUnwrap(
            findView(id: HomeViewController.AccessibilityID.settingsButton, in: sut.view)
        )

        XCTAssertEqual(settings.accessibilityLabel, Strings.openSettingsLabel)
    }

    func testSettingsButtonMeetsMinimumTouchTarget() throws {
        let sut = makeSUT()
        layout(sut)
        let settings = try XCTUnwrap(
            findView(id: HomeViewController.AccessibilityID.settingsButton, in: sut.view)
        )

        XCTAssertGreaterThanOrEqual(settings.bounds.width, Theme.Layout.minimumTouchTarget)
        XCTAssertGreaterThanOrEqual(settings.bounds.height, Theme.Layout.minimumTouchTarget)
    }

    // MARK: - Best score

    func testBestScoreShowsZeroWhenNothingPersisted() throws {
        let sut = makeSUT()
        sut.beginAppearanceTransition(true, animated: false)
        sut.endAppearanceTransition()

        let label = try XCTUnwrap(
            findView(id: HomeViewController.AccessibilityID.bestScoreValue, in: sut.view) as? UILabel
        )
        XCTAssertEqual(label.text, "0")
    }

    func testBestScoreReadsPersistedValue() throws {
        let sut = makeSUT(bestScore: 1280)
        sut.beginAppearanceTransition(true, animated: false)
        sut.endAppearanceTransition()

        let label = try XCTUnwrap(
            findView(id: HomeViewController.AccessibilityID.bestScoreValue, in: sut.view) as? UILabel
        )
        XCTAssertEqual(label.text, 1280.formatted())
    }

    // MARK: - Layout

    func testLayoutIsUnambiguousAcrossScreenSizes() {
        // Smallest supported iPhone through the largest current one.
        let sizes = [
            CGSize(width: 320, height: 568),
            CGSize(width: 375, height: 667),
            CGSize(width: 393, height: 852),
            CGSize(width: 440, height: 956),
        ]

        for size in sizes {
            let sut = makeSUT()
            layout(sut, size: size)

            XCTAssertFalse(
                sut.view.hasAmbiguousLayout,
                "Ambiguous layout at \(size.width)x\(size.height)"
            )
        }
    }

    /// Regression guard: an uncapped wordmark plus an all-required vertical
    /// chain used to push past the screen, erasing the score and the PLAY
    /// title. Every element must stay on screen and stay separated.
    func testLayoutSurvivesAccessibilityTextSizes() throws {
        for size in [CGSize(width: 320, height: 568), CGSize(width: 393, height: 852)] {
            let sut = makeSUT(bestScore: 9999)
            sut.view.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
            sut.beginAppearanceTransition(true, animated: false)
            sut.endAppearanceTransition()
            layout(sut, size: size)

            let label = "at \(Int(size.width))x\(Int(size.height))"

            let play = try XCTUnwrap(
                findView(id: HomeViewController.AccessibilityID.playButton, in: sut.view)
            )
            let score = try XCTUnwrap(
                findView(id: HomeViewController.AccessibilityID.bestScoreValue, in: sut.view)
            )

            XCTAssertFalse(play.frame.isEmpty, "Play button collapsed \(label)")
            XCTAssertFalse(score.frame.isEmpty, "Score value collapsed \(label)")
            XCTAssertGreaterThanOrEqual(
                play.frame.height,
                Theme.Layout.primaryButtonHeight,
                "Play button shrank below its touch target \(label)"
            )
            XCTAssertTrue(
                sut.view.bounds.contains(play.frame),
                "Play button left the screen \(label)"
            )
            XCTAssertTrue(
                sut.view.bounds.contains(score.frame),
                "Score value left the screen \(label)"
            )
            XCTAssertFalse(
                score.frame.intersects(play.frame),
                "Score overlaps the Play button \(label)"
            )
        }
    }

    func testPlayButtonSitsBelowHeroBall() throws {
        let sut = makeSUT()
        layout(sut)

        let play = try XCTUnwrap(
            findView(id: HomeViewController.AccessibilityID.playButton, in: sut.view)
        )
        let hero = try XCTUnwrap(sut.view.subviews.compactMap { $0 as? HeroBallView }.first)

        XCTAssertGreaterThan(play.frame.minY, hero.frame.maxY, "Play must not overlap the hero ball.")
    }
}
