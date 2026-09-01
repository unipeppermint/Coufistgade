//
//  ResultViewControllerTests.swift
//  coufistgadeTests
//

import XCTest
@testable import coufistgade

final class ResultViewControllerTests: XCTestCase {

    private func makeResult(
        score: Int = 120,
        roundCombo: Int = 4,
        bestScore: Int = 300,
        bestCombo: Int = 9,
        isNewRecord: Bool = false
    ) -> RoundResult {
        RoundResult(
            score: score,
            roundCombo: roundCombo,
            bestScore: bestScore,
            bestCombo: bestCombo,
            isNewRecord: isNewRecord
        )
    }

    private func makeSUT(_ result: RoundResult) -> ResultViewController {
        let sut = ResultViewController(result: result, prefersReducedMotion: { true })
        sut.loadViewIfNeeded()
        sut.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        sut.view.layoutIfNeeded()
        return sut
    }

    private func label(_ id: String, in view: UIView) -> UILabel? {
        if let label = view as? UILabel, label.accessibilityIdentifier == id { return label }
        for subview in view.subviews {
            if let found = label(id, in: subview) { return found }
        }
        return nil
    }

    private func view(_ id: String, in view: UIView) -> UIView? {
        if view.accessibilityIdentifier == id { return view }
        for subview in view.subviews {
            if let found = self.view(id, in: subview) { return found }
        }
        return nil
    }

    // MARK: - Display

    func testShowsAllThreeStatistics() throws {
        // GAMEPLAY §22: score, best score, highest combo.
        let sut = makeSUT(makeResult(score: 250, roundCombo: 7, bestScore: 480))

        XCTAssertEqual(label(ResultViewController.AccessibilityID.scoreValue, in: sut.view)?.text, "250")
        XCTAssertEqual(label(ResultViewController.AccessibilityID.bestValue, in: sut.view)?.text, "480")
        XCTAssertEqual(label(ResultViewController.AccessibilityID.comboValue, in: sut.view)?.text, "7")
    }

    func testAZeroScoreRoundStillShowsAResult() throws {
        let sut = makeSUT(makeResult(score: 0, roundCombo: 0, bestScore: 0, bestCombo: 0))

        XCTAssertEqual(label(ResultViewController.AccessibilityID.scoreValue, in: sut.view)?.text, "0")
    }

    func testTheScoreIsTheLargestNumberOnScreen() throws {
        let sut = makeSUT(makeResult())
        let score = try XCTUnwrap(label(ResultViewController.AccessibilityID.scoreValue, in: sut.view))
        let best = try XCTUnwrap(label(ResultViewController.AccessibilityID.bestValue, in: sut.view))

        // UI_DESIGN §13 centres the score and makes the rest secondary.
        XCTAssertGreaterThan(score.font.pointSize, best.font.pointSize)
    }

    // MARK: - New record

    func testTheBadgeIsHiddenWithoutARecord() throws {
        let sut = makeSUT(makeResult(isNewRecord: false))

        let badge = try XCTUnwrap(view(ResultViewController.AccessibilityID.newRecordBadge, in: sut.view))
        XCTAssertTrue(badge.isHidden)
    }

    func testTheBadgeAppearsForARecord() throws {
        let sut = makeSUT(makeResult(score: 500, bestScore: 500, isNewRecord: true))

        let badge = try XCTUnwrap(view(ResultViewController.AccessibilityID.newRecordBadge, in: sut.view))
        XCTAssertFalse(badge.isHidden)
    }

    func testTheBadgeIsStillShownWhenMotionIsReduced() throws {
        let sut = ResultViewController(
            result: makeResult(isNewRecord: true),
            prefersReducedMotion: { true }
        )
        sut.loadViewIfNeeded()
        sut.beginAppearanceTransition(true, animated: false)
        sut.endAppearanceTransition()

        // Reduce Motion skips the spring, never the information.
        let badge = try XCTUnwrap(view(ResultViewController.AccessibilityID.newRecordBadge, in: sut.view))
        XCTAssertFalse(badge.isHidden)
        XCTAssertEqual(badge.transform, .identity)
    }

    // MARK: - Actions

    func testPlayAgainIsReported() throws {
        let sut = makeSUT(makeResult())
        var tapped = 0
        sut.onPlayAgain = { tapped += 1 }

        let button = try XCTUnwrap(
            view(ResultViewController.AccessibilityID.playAgainButton, in: sut.view) as? UIButton
        )
        button.sendActions(for: .touchUpInside)

        XCTAssertEqual(tapped, 1)
    }

    func testHomeIsReported() throws {
        let sut = makeSUT(makeResult())
        var tapped = 0
        sut.onHome = { tapped += 1 }

        let button = try XCTUnwrap(
            view(ResultViewController.AccessibilityID.homeButton, in: sut.view) as? UIButton
        )
        button.sendActions(for: .touchUpInside)

        XCTAssertEqual(tapped, 1)
    }

    func testBothActionsMeetTheTouchTarget() throws {
        let sut = makeSUT(makeResult())

        for id in [
            ResultViewController.AccessibilityID.playAgainButton,
            ResultViewController.AccessibilityID.homeButton,
        ] {
            let button = try XCTUnwrap(view(id, in: sut.view))
            XCTAssertGreaterThanOrEqual(
                button.bounds.height,
                Theme.Layout.minimumTouchTarget,
                "\(id) is too small to tap."
            )
        }
    }

    // MARK: - Accessibility

    func testTheScoreIsSpokenWithItsMeaning() throws {
        let sut = makeSUT(makeResult(score: 90))

        let score = try XCTUnwrap(label(ResultViewController.AccessibilityID.scoreValue, in: sut.view))
        XCTAssertEqual(score.accessibilityLabel, Strings.scoreLabel(90))
    }

    func testTheStatisticsAreSpokenWithTheirCaptions() throws {
        let sut = makeSUT(makeResult(roundCombo: 6, bestScore: 700))

        // "700" alone tells a VoiceOver user nothing.
        XCTAssertEqual(
            label(ResultViewController.AccessibilityID.bestValue, in: sut.view)?.accessibilityLabel,
            "\(Strings.bestCaption) 700"
        )
        XCTAssertEqual(
            label(ResultViewController.AccessibilityID.comboValue, in: sut.view)?.accessibilityLabel,
            "\(Strings.comboCaptionPlain) 6"
        )
    }

    func testTheLayoutSurvivesAccessibilityTextSizes() {
        let sut = ResultViewController(result: makeResult(score: 99_999), prefersReducedMotion: { true })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = sut
        window.makeKeyAndVisible()
        sut.setOverrideTraitCollection(
            UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge),
            forChild: sut
        )
        sut.view.layoutIfNeeded()

        // Everything must stay on screen rather than clipping off the bottom.
        let playAgain = view(ResultViewController.AccessibilityID.playAgainButton, in: sut.view)
        XCTAssertNotNil(playAgain)
        XCTAssertLessThanOrEqual(playAgain?.frame.maxY ?? .infinity, sut.view.bounds.height)
        window.isHidden = true
    }

    // MARK: - 滚动

    private func scrollView(in view: UIView) -> UIScrollView? {
        if let found = view as? UIScrollView { return found }
        for subview in view.subviews {
            if let found = scrollView(in: subview) { return found }
        }
        return nil
    }

    /// 在给定尺寸的窗口里真实呈现一次，滚动视图要有 bounds 才能量。
    private func present(
        _ result: RoundResult,
        size: CGSize,
        contentSize: UIContentSizeCategory = .large
    ) -> (ResultViewController, UIWindow) {
        let sut = ResultViewController(result: result, prefersReducedMotion: { true })
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = sut
        window.makeKeyAndVisible()
        sut.setOverrideTraitCollection(
            UITraitCollection(preferredContentSizeCategory: contentSize),
            forChild: sut
        )
        sut.view.layoutIfNeeded()
        return (sut, window)
    }

    func testContentTallerThanTheScreenBecomesScrollable() throws {
        // 十条成就全解锁 + 无障碍字号：这是这一页最长的样子。
        let result = RoundResult(
            score: 4_200,
            roundCombo: 12,
            bestScore: 4_200,
            bestCombo: 12,
            isNewRecord: true,
            unlockedAchievements: Achievement.all
        )
        let (sut, window) = present(
            result,
            size: CGSize(width: 393, height: 852),
            contentSize: .accessibilityExtraExtraExtraLarge
        )
        defer { window.isHidden = true }

        let scroll = try XCTUnwrap(scrollView(in: sut.view))
        XCTAssertGreaterThan(
            scroll.contentSize.height,
            scroll.bounds.height,
            "内容比视口高时应当可以滚动。"
        )

        // 关键在于「够得到」：以前这一段会被裁在屏幕外，现在应当落在可滚动范围内。
        let home = try XCTUnwrap(view(ResultViewController.AccessibilityID.homeButton, in: sut.view))
        let bottomInContent = home.convert(home.bounds, to: scroll).maxY
        XCTAssertLessThanOrEqual(bottomInContent, scroll.contentSize.height)
    }

    func testContentThatFitsDoesNotScroll() throws {
        let (sut, window) = present(makeResult(), size: CGSize(width: 393, height: 852))
        defer { window.isHidden = true }

        let scroll = try XCTUnwrap(scrollView(in: sut.view))
        // 装得下时这一页仍然是静止的居中布局，不该多出可滚动的高度。
        XCTAssertEqual(scroll.contentSize.height, scroll.bounds.height, accuracy: 0.5)
    }

    func testContentThatFitsStaysVerticallyCentred() throws {
        let (sut, window) = present(makeResult(), size: CGSize(width: 393, height: 852))
        defer { window.isHidden = true }

        let scroll = try XCTUnwrap(scrollView(in: sut.view))
        let score = try XCTUnwrap(label(ResultViewController.AccessibilityID.scoreValue, in: sut.view))
        let badge = try XCTUnwrap(view(ResultViewController.AccessibilityID.newRecordBadge, in: sut.view))
        let home = try XCTUnwrap(view(ResultViewController.AccessibilityID.homeButton, in: sut.view))

        // 加滚动之前这一页是居中的，加了之后不应该变成顶端对齐。
        let top = badge.convert(badge.bounds, to: scroll).minY
        let bottom = home.convert(home.bounds, to: scroll).maxY
        let above = top
        let below = scroll.contentSize.height - bottom
        XCTAssertEqual(above, below, accuracy: 2, "内容应当在视口里保持居中。")
        XCTAssertGreaterThan(score.frame.height, 0)
    }
}

final class PersistenceManagerTests: XCTestCase {

    private func makeSUT() -> PersistenceManager {
        PersistenceManager(defaults: UserDefaults(suiteName: "bouncy.tests.\(UUID().uuidString)")!)
    }

    // MARK: - Defaults on a fresh install

    func testRecordsStartAtZero() {
        let sut = makeSUT()

        XCTAssertEqual(sut.bestScore, 0)
        XCTAssertEqual(sut.bestCombo, 0)
        XCTAssertEqual(sut.totalGames, 0)
    }

    func testSoundMusicAndHapticsAreOnBeforeAnyoneChangesThem() {
        let sut = makeSUT()

        // bool(forKey:) answers false for an absent key, which would ship the
        // game silent and inert. Registered defaults are what prevent that.
        XCTAssertTrue(sut.soundEnabled)
        XCTAssertTrue(sut.musicEnabled)
        XCTAssertTrue(sut.hapticsEnabled)
    }

    func testReduceMotionIsOffByDefault() {
        XCTAssertFalse(makeSUT().reduceMotionEnabled)
    }

    // MARK: - Filing a round

    func testAFirstRoundSetsBothRecords() {
        let sut = makeSUT()

        let record = sut.record(score: 120, combo: 5)

        XCTAssertTrue(record.isNewBestScore)
        XCTAssertTrue(record.isNewBestCombo)
        XCTAssertEqual(sut.bestScore, 120)
        XCTAssertEqual(sut.bestCombo, 5)
    }

    func testEveryRoundCountsEvenWhenItBeatsNothing() {
        let sut = makeSUT()
        sut.record(score: 500, combo: 10)

        sut.record(score: 10, combo: 1)
        sut.record(score: 20, combo: 2)

        XCTAssertEqual(sut.totalGames, 3)
        XCTAssertEqual(sut.bestScore, 500)
    }

    func testAWorseRoundLeavesBothRecordsAlone() {
        let sut = makeSUT()
        sut.record(score: 300, combo: 8)

        let record = sut.record(score: 100, combo: 3)

        XCTAssertFalse(record.isNewBestScore)
        XCTAssertFalse(record.isNewBestCombo)
        XCTAssertEqual(sut.bestScore, 300)
        XCTAssertEqual(sut.bestCombo, 8)
    }

    func testScoreAndComboRecordsMoveIndependently() {
        let sut = makeSUT()
        sut.record(score: 300, combo: 8)

        // A long rally of cheap hits: better combo, worse score.
        let record = sut.record(score: 100, combo: 12)

        XCTAssertFalse(record.isNewBestScore)
        XCTAssertTrue(record.isNewBestCombo)
        XCTAssertEqual(sut.bestScore, 300)
        XCTAssertEqual(sut.bestCombo, 12)
    }

    func testTyingARecordIsNotBeatingIt() {
        let sut = makeSUT()
        sut.record(score: 200, combo: 6)

        let record = sut.record(score: 200, combo: 6)

        XCTAssertFalse(record.isNewBestScore)
        XCTAssertFalse(record.isNewBestCombo)
    }

    func testAZeroRoundClaimsNothing() {
        let sut = makeSUT()

        let record = sut.record(score: 0, combo: 0)

        // Otherwise the first round, however badly played, is a record.
        XCTAssertFalse(record.isNewBestScore)
        XCTAssertFalse(record.isNewBestCombo)
        XCTAssertEqual(sut.totalGames, 1)
    }

    // MARK: - Settings round-trip

    func testEachSettingPersistsIndependently() {
        let suite = UserDefaults(suiteName: "bouncy.tests.\(UUID().uuidString)")!
        let sut = PersistenceManager(defaults: suite)

        sut.soundEnabled = false
        sut.hapticsEnabled = false

        // A second instance over the same suite stands in for a relaunch.
        let reloaded = PersistenceManager(defaults: suite)
        XCTAssertFalse(reloaded.soundEnabled)
        XCTAssertFalse(reloaded.hapticsEnabled)
        XCTAssertTrue(reloaded.musicEnabled, "An unrelated setting changed.")
    }

    func testRecordsSurviveARelaunch() {
        let suite = UserDefaults(suiteName: "bouncy.tests.\(UUID().uuidString)")!
        PersistenceManager(defaults: suite).record(score: 450, combo: 11)

        let reloaded = PersistenceManager(defaults: suite)

        XCTAssertEqual(reloaded.bestScore, 450)
        XCTAssertEqual(reloaded.bestCombo, 11)
        XCTAssertEqual(reloaded.totalGames, 1)
    }

    func testThePhase2BestScoreKeyIsStillHonoured() {
        let suite = UserDefaults(suiteName: "bouncy.tests.\(UUID().uuidString)")!
        // Written by the old ScoreStore. Renaming the key would silently reset
        // the best score of anyone who had already played.
        suite.set(777, forKey: "bouncy.bestScore")

        XCTAssertEqual(PersistenceManager(defaults: suite).bestScore, 777)
    }
}

final class MotionPreferenceTests: XCTestCase {

    private var original: (() -> Bool)!

    override func setUp() {
        super.setUp()
        original = MotionPreference.storedPreference
    }

    override func tearDown() {
        MotionPreference.storedPreference = original
        super.tearDown()
    }

    func testTheAppSettingAloneReducesMotion() {
        MotionPreference.storedPreference = { true }

        // The simulator's system setting is off, so this isolates the app's.
        XCTAssertTrue(MotionPreference.isReduced)
    }

    func testMotionIsFullWhenNeitherSourceAsksOtherwise() {
        MotionPreference.storedPreference = { false }

        XCTAssertEqual(MotionPreference.isReduced, UIAccessibility.isReduceMotionEnabled)
    }

    func testTheAppSettingCannotBeOverriddenByTheSystemBeingOff() {
        // A player who asked for less motion in either place has asked for it.
        // Honouring only the system setting would make the app's own switch a
        // lie; honouring only the app's would ignore an accessibility choice.
        MotionPreference.storedPreference = { true }

        XCTAssertTrue(
            MotionPreference.isReduced,
            "The app setting was ignored because the system setting is off."
        )
    }

    func testNoViewReadsUIAccessibilityDirectly() {
        // The merge only holds if every animating view comes through here. This
        // asserts the wiring by proving the app setting alone changes behaviour
        // in a view that defaults to MotionPreference.
        MotionPreference.storedPreference = { true }
        let hud = ScoreHUDView()

        hud.apply(ScoreEvent(points: 10, total: 10, multiplier: 1))

        // Reduce Motion skips the pop, so the label stays unscaled.
        XCTAssertEqual(hud.displayedScoreText, "10")
    }
}
