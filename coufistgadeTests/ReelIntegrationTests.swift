//
//  ReelIntegrationTests.swift
//  coufistgadeTests
//
//  转轴接进回合结算之后是否成立：奖励分有没有真的进总分、进最高分、进成就判定，
//  以及结算页那个大号数字有没有从对局分爬到总分。
//
//  这里守的是 GameViewController.gameSceneDidFinishRound 里那四步的顺序
//  （GAMEPLAY §27）。顺序错了单元测试全都还是绿的，只有把几件事放在一起跑才看得出来。
//

import XCTest
@testable import coufistgade

final class ReelIntegrationTests: XCTestCase {

    private func makeStore() -> PersistenceManager {
        PersistenceManager(defaults: UserDefaults(suiteName: "bouncy.tests.\(UUID().uuidString)")!)
    }

    private func summary(score: Int, combo: Int, hits: Int) -> RoundSummary {
        RoundSummary(score: score, highestCombo: combo, hits: hits)
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

    // MARK: - 顺序不变量（见文件头）

    func testReelsReadTheScoreBeforeTheBonusIsAdded() {
        // 这是整套机制的核心不变量：若转轴读的是已含奖励的分数，它就在读自己的
        // 输出，成环——一条 star 线会把分数推过 1000，下一次评定就变成 seven 线。
        //
        // 复现那个环：先按对局分评一次，再按「已加过奖励」的分数评一次，两者
        // 落档必须不同，这样才证明这条断言是有意义的（而不是恒真）。
        let evaluator = ReelEvaluator()
        let baseScore = 900

        // 命中 12、连击 4、得分 900 三者都落 star 档，是一条 star 线，奖励 150。
        // 900 + 150 = 1050 越过了 seven 的门槛（1000）——所以这一局正是能暴露成环
        // 的那种局：按对局分评是 star 线，按含奖励的分数再评就变成两个 star 加
        // 一个 seven。
        let correct = evaluator.evaluate(summary(score: baseScore, combo: 4, hits: 12))
        let looped = evaluator.evaluate(
            summary(score: baseScore + correct.bonus, combo: 4, hits: 12)
        )

        XCTAssertNotEqual(
            correct.slots.first { $0.dimension == .score }?.symbol,
            looped.slots.first { $0.dimension == .score }?.symbol,
            "这一局的分数正好跨在门槛上，是用来暴露成环的——若两者相同则这条测试失去意义"
        )
        // 正确的那个必须是按对局分评出来的。
        XCTAssertEqual(correct.floorSymbol, .star)
    }

    func testTheBonusLandsInTheScoreThatGetsRecorded() {
        // 奖励分不是装饰：它计入总分，所以也计入最高分。
        let store = makeStore()
        let baseScore = 640
        let outcome = ReelEvaluator().evaluate(summary(score: baseScore, combo: 5, hits: 17))
        let finalScore = baseScore + outcome.bonus

        store.record(score: finalScore, combo: 5)

        XCTAssertEqual(store.bestScore, finalScore)
        XCTAssertGreaterThan(
            store.bestScore,
            baseScore,
            "奖励分没有进最高分"
        )
    }

    func testTheBonusCountsTowardAchievements() {
        // 玩家看到的分数是含奖励的总分。成就却按另一个数算的话，结算页显示 520 分
        // 而「单局 500 分」不解锁，那是个说不通的界面。
        let store = makeStore()
        let tracker = AchievementTracker(store: store)

        // 对局本身 480 分，差 20 分到成就 fiveHundred。
        let baseScore = 480
        let outcome = ReelEvaluator().evaluate(summary(score: baseScore, combo: 4, hits: 12))
        let finalScore = baseScore + outcome.bonus
        XCTAssertGreaterThanOrEqual(finalScore, 500, "这一局的奖励应当刚好补过 500 分门槛")

        store.record(score: finalScore, combo: 4)
        let unlocked = tracker.evaluate(summary(score: finalScore, combo: 4, hits: 12))

        XCTAssertTrue(
            unlocked.contains { $0.id == "fiveHundred" },
            "含奖励的总分够到 500 分，成就应当解锁 — 实际解锁 \(unlocked.map(\.id))"
        )
    }

    // MARK: - 结算页

    private func makeResultViewController(
        _ result: RoundResult,
        reducedMotion: Bool = true
    ) -> ResultViewController {
        let sut = ResultViewController(
            result: result,
            prefersReducedMotion: { reducedMotion }
        )
        sut.loadViewIfNeeded()
        sut.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        sut.view.layoutIfNeeded()
        return sut
    }

    private func result(
        baseScore: Int,
        outcome: ReelOutcome?
    ) -> RoundResult {
        let bonus = outcome?.bonus ?? 0
        return RoundResult(
            score: baseScore + bonus,
            roundCombo: 5,
            bestScore: baseScore + bonus,
            bestCombo: 9,
            isNewRecord: false,
            baseScore: baseScore,
            reelOutcome: outcome
        )
    }

    func testTheReelPanelIsAbsentWithoutAnOutcome() {
        // 旧的 RoundResult（reelOutcome 默认为 nil）在这一页上应当和加转轴之前
        // 一模一样，而不是多出一个空面板。
        let sut = makeResultViewController(result(baseScore: 300, outcome: nil))

        XCTAssertNil(
            view(ReelPanelView.AccessibilityID.panel, in: sut.view),
            "没有转轴结果时不该插入面板"
        )
    }

    func testTheReelPanelIsPresentWithAnOutcome() {
        let outcome = ReelEvaluator().evaluate(summary(score: 300, combo: 5, hits: 12))
        let sut = makeResultViewController(result(baseScore: 300, outcome: outcome))

        XCTAssertNotNil(
            view(ReelPanelView.AccessibilityID.panel, in: sut.view),
            "有转轴结果时应当插入面板"
        )
    }

    func testTheScoreStartsAtTheRoundScoreBeforeTheBonusIsRevealed() throws {
        // 大号总分的起点是对局分，奖励分揭晓后才爬上去。这一下就是奖励的兑现——
        // 起点直接写终值的话，玩家看不出那笔奖励是自己的。
        let outcome = ReelEvaluator().evaluate(summary(score: 640, combo: 5, hits: 17))
        XCTAssertGreaterThan(outcome.bonus, 0, "这一局应当有奖励，否则测不出爬分")

        let sut = makeResultViewController(result(baseScore: 640, outcome: outcome))

        // viewDidAppear 还没跑，此时应当停在对局分。
        let score = try XCTUnwrap(
            label(ResultViewController.AccessibilityID.scoreValue, in: sut.view)
        )
        XCTAssertEqual(score.text, "640", "揭晓之前应当显示对局分")
    }

    func testTheScoreReachesTheTotalAfterTheReveal() throws {
        let outcome = ReelEvaluator().evaluate(summary(score: 640, combo: 5, hits: 17))
        let round = result(baseScore: 640, outcome: outcome)
        // Reduce Motion：揭晓与爬分都同步完成，不必等计时器。
        let sut = makeResultViewController(round, reducedMotion: true)

        sut.beginAppearanceTransition(true, animated: false)
        sut.endAppearanceTransition()

        let score = try XCTUnwrap(
            label(ResultViewController.AccessibilityID.scoreValue, in: sut.view)
        )
        XCTAssertEqual(
            score.text,
            "\(round.score)",
            "揭晓之后应当显示含奖励的总分"
        )
    }

    func testABlankOutcomeShowsTheTotalImmediately() throws {
        // 奖励为 0 时没有可爬的，起点就该是终值——否则会白跑一趟计时器。
        //
        // 最低档是 cherry 才会赔 0（bell 及以上都给钱），所以这里得有一个轮子
        // 落在 cherry 上。
        let blank = ReelOutcome(
            slots: [
                ReelSlot(dimension: .hits, symbol: .cherry, value: 3),
                ReelSlot(dimension: .combo, symbol: .seven, value: 7),
                ReelSlot(dimension: .score, symbol: .star, value: 500),
            ],
            floorSymbol: .cherry,
            bonus: 0
        )
        let sut = makeResultViewController(result(baseScore: 500, outcome: blank))

        let score = try XCTUnwrap(
            label(ResultViewController.AccessibilityID.scoreValue, in: sut.view)
        )
        XCTAssertEqual(score.text, "500")
    }

    func testTheScoreAccessibilityLabelKeepsUpWithTheCountUp() throws {
        // 爬分改的是同一个标签，无障碍标签必须跟着走，否则 VoiceOver 会读出一个
        // 过时的分数。
        let outcome = ReelEvaluator().evaluate(summary(score: 640, combo: 5, hits: 17))
        let round = result(baseScore: 640, outcome: outcome)
        let sut = makeResultViewController(round, reducedMotion: true)

        sut.beginAppearanceTransition(true, animated: false)
        sut.endAppearanceTransition()

        let score = try XCTUnwrap(
            label(ResultViewController.AccessibilityID.scoreValue, in: sut.view)
        )
        XCTAssertEqual(score.accessibilityLabel, Strings.scoreLabel(round.score))
    }

    func testLeavingTheScreenMidCountUpDoesNotCrash() {
        // 玩家可能在爬分途中就点了「再来一局」。计时器必须停，否则它会继续改写
        // 一个已经离场的标签。
        let outcome = ReelEvaluator().evaluate(summary(score: 640, combo: 5, hits: 17))
        let sut = makeResultViewController(
            result(baseScore: 640, outcome: outcome),
            reducedMotion: false
        )

        sut.beginAppearanceTransition(true, animated: false)
        sut.endAppearanceTransition()
        // 揭晓刚开始就离场。
        sut.beginAppearanceTransition(false, animated: false)
        sut.endAppearanceTransition()

        // 跑一小段 run loop，让还活着的计时器有机会开火。
        let deadline = Date().addingTimeInterval(0.4)
        while Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
        // 没崩就算过。
    }

    // MARK: - 最长的那一页

    private func scrollView(in view: UIView) -> UIScrollView? {
        if let found = view as? UIScrollView { return found }
        for subview in view.subviews {
            if let found = scrollView(in: subview) { return found }
        }
        return nil
    }

    /// 在给定尺寸的窗口里真实呈现一次——滚动视图要有 bounds 才量得出来。
    private func present(
        _ result: RoundResult,
        size: CGSize = CGSize(width: 393, height: 852),
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

    /// 转轴 + 十条成就 + 无障碍字号：这一页现在最长的样子。
    ///
    /// 加转轴之前的最长情形已有测试覆盖（ResultViewControllerTests 里那条），但面板
    /// 又往里塞了三列加两行文字。这一页此前被滚动视图的约束咬过两次，都是内容被裁
    /// 在屏幕外（见 docs/ACHIEVEMENTS_HANDOFF.md），所以新增高度必须重新验一遍。
    private func tallestResult() -> RoundResult {
        let outcome = ReelEvaluator().evaluate(summary(score: 4_200, combo: 12, hits: 40))
        return RoundResult(
            score: 4_200 + outcome.bonus,
            roundCombo: 12,
            bestScore: 4_200 + outcome.bonus,
            bestCombo: 12,
            isNewRecord: true,
            unlockedAchievements: Achievement.all,
            baseScore: 4_200,
            reelOutcome: outcome
        )
    }

    func testTheTallestPageWithReelsStaysReachable() throws {
        let (sut, window) = present(
            tallestResult(),
            contentSize: .accessibilityExtraExtraExtraLarge
        )
        defer { window.isHidden = true }

        let scroll = try XCTUnwrap(scrollView(in: sut.view))
        XCTAssertGreaterThan(
            scroll.contentSize.height,
            scroll.bounds.height,
            "这一页应当比视口高，否则这条测试没在测想测的东西"
        )

        // 关键在于「够得到」：底部的按钮必须落在可滚动范围内，而不是被裁在外面。
        let home = try XCTUnwrap(view(ResultViewController.AccessibilityID.homeButton, in: sut.view))
        let bottomInContent = home.convert(home.bounds, to: scroll).maxY
        XCTAssertLessThanOrEqual(
            bottomInContent,
            scroll.contentSize.height,
            "「回主页」被裁在可滚动范围外了"
        )
    }

    func testTheReelPanelItselfIsReachableOnTheTallestPage() throws {
        let (sut, window) = present(
            tallestResult(),
            contentSize: .accessibilityExtraExtraExtraLarge
        )
        defer { window.isHidden = true }

        let scroll = try XCTUnwrap(scrollView(in: sut.view))
        let panel = try XCTUnwrap(view(ReelPanelView.AccessibilityID.panel, in: sut.view))

        // 面板自己也不能被裁：它在总分下面，是这一页最容易被挤出去的一段。
        let frameInContent = panel.convert(panel.bounds, to: scroll)
        XCTAssertGreaterThanOrEqual(frameInContent.minY, 0, "面板顶部被裁到内容之上")
        XCTAssertLessThanOrEqual(
            frameInContent.maxY,
            scroll.contentSize.height,
            "面板底部被裁在可滚动范围外"
        )
        XCTAssertGreaterThan(panel.bounds.height, 0, "面板没有高度")
    }

    func testTheReelColumnsKeepEqualWidths() throws {
        // 三列等宽：轮子该是三个一样的格子，宽度不能随标题长短变化。
        // CHAIN 比 HITS 长，若 distribution 写错就会看出来。
        let (sut, window) = present(tallestResult())
        defer { window.isHidden = true }

        let widths = try ReelDimension.allCases.indices.map { index in
            try XCTUnwrap(
                view(ReelPanelView.AccessibilityID.slot(index), in: sut.view)
            ).bounds.width
        }
        for width in widths {
            XCTAssertEqual(width, widths[0], accuracy: 1, "三列宽度不等：\(widths)")
            XCTAssertGreaterThan(width, 0)
        }
    }

    // MARK: - RoundResult 的默认值

    func testAResultWithoutAReelOutcomeHasBaseScoreEqualToScore() {
        // 既有调用点（与大量既有测试）不传 baseScore。默认必须等于总分，
        // 否则那些页面会显示一个不存在的起始分。
        let round = RoundResult(
            score: 250,
            roundCombo: 4,
            bestScore: 300,
            bestCombo: 9,
            isNewRecord: false
        )
        XCTAssertEqual(round.baseScore, round.score)
        XCTAssertNil(round.reelOutcome)
    }
}
