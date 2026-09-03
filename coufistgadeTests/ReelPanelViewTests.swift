//
//  ReelPanelViewTests.swift
//  coufistgadeTests
//
//  面板有两条入口：configure 直接呈现终态，reveal 播揭晓动画。绝大多数断言走
//  前者，于是不必等计时器；动画那几条各自用 expectation。
//

import XCTest
@testable import coufistgade

final class ReelPanelViewTests: XCTestCase {

    private final class AudioSpy: AudioPlaying {
        var isEnabled = true
        var settles: [ReelSymbol] = []
        var lines = 0
        func playImpact(_ intensity: ImpactIntensity) {}
        func playComboMilestone() {}
        func playAchievementUnlock() {}
        func playReelSettle(_ symbol: ReelSymbol) { settles.append(symbol) }
        func playReelLine() { lines += 1 }
    }

    private final class HapticSpy: HapticPlaying {
        var isEnabled = true
        var settles = 0
        var lines = 0
        func playImpact(_ intensity: ImpactIntensity) {}
        func playComboMilestone() {}
        func playAchievementUnlock() {}
        func playReelSettle() { settles += 1 }
        func playReelLine() { lines += 1 }
    }

    private func makeSUT() -> ReelPanelView {
        let sut = ReelPanelView()
        sut.frame = CGRect(x: 0, y: 0, width: 320, height: 160)
        sut.layoutIfNeeded()
        return sut
    }

    /// 最低档由符号自己推出来，不作为参数传入。
    ///
    /// 刻意如此：`floorSymbol` 在真实结果里永远等于三个符号里最低的那个，让工厂
    /// 也守这条规则，测试就写不出「三个 star 但最低档是 bell」这种不可能的输入。
    private func outcome(_ symbols: [ReelSymbol], bonus: Int = 0) -> ReelOutcome {
        let slots = zip(ReelDimension.allCases, symbols).map { dimension, symbol in
            ReelSlot(dimension: dimension, symbol: symbol, value: 0)
        }
        let floor = symbols.min { $0.tier < $1.tier } ?? .cherry
        return ReelOutcome(slots: slots, floorSymbol: floor, bonus: bonus)
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

    // MARK: - 终态

    func testShowsOneColumnPerDimension() throws {
        let sut = makeSUT()
        for index in ReelDimension.allCases.indices {
            XCTAssertNotNil(
                view(ReelPanelView.AccessibilityID.slot(index), in: sut),
                "第 \(index) 个轮子不在视图树里"
            )
        }
    }

    func testEachColumnIsASingleAccessibilityElement() throws {
        // VoiceOver 应当把一列读作一句「命中 12，星」，而不是把标题与符号拆成两段。
        let sut = makeSUT()
        let column = try XCTUnwrap(view(ReelPanelView.AccessibilityID.slot(0), in: sut))
        XCTAssertTrue(column.isAccessibilityElement)
    }

    func testTheAccessibilityLabelCarriesTheValueAndSymbol() throws {
        let sut = makeSUT()
        let slots = [
            ReelSlot(dimension: .hits, symbol: .star, value: 17),
            ReelSlot(dimension: .combo, symbol: .bell, value: 3),
            ReelSlot(dimension: .score, symbol: .seven, value: 1_200),
        ]
        sut.configure(ReelOutcome(slots: slots, floorSymbol: .bell, bonus: 60))

        let column = try XCTUnwrap(view(ReelPanelView.AccessibilityID.slot(0), in: sut))
        let spoken = try XCTUnwrap(column.accessibilityLabel)
        // 数值必须读出来，玩家才能反推阈值。
        XCTAssertTrue(spoken.contains("17"), "没读出数值 — \(spoken)")
        XCTAssertTrue(
            spoken.contains(ReelStrings.symbolName(.star)),
            "没读出符号名 — \(spoken)"
        )
    }

    // MARK: - 奖励行

    func testAPayingOutcomeShowsItsCaptionAndBonus() throws {
        let sut = makeSUT()
        sut.configure(outcome([.star, .star, .star], bonus: 150))

        let caption = try XCTUnwrap(label(ReelPanelView.AccessibilityID.lineCaption, in: sut))
        let value = try XCTUnwrap(label(ReelPanelView.AccessibilityID.bonusValue, in: sut))
        XCTAssertFalse(caption.isHidden)
        XCTAssertFalse(value.isHidden)
        XCTAssertTrue(
            try XCTUnwrap(value.text).contains("150"),
            "奖励分没显示 — \(value.text ?? "nil")"
        )
    }

    func testABlankOutcomeShowsNoBonusRow() throws {
        // 「+0」读起来像个 bug，而且每局都亮着奖励行会让成线不再是个事件。
        let sut = makeSUT()
        sut.configure(outcome([.cherry, .bell, .star]))

        let value = try XCTUnwrap(label(ReelPanelView.AccessibilityID.bonusValue, in: sut))
        let caption = try XCTUnwrap(label(ReelPanelView.AccessibilityID.lineCaption, in: sut))
        XCTAssertTrue(value.isHidden, "什么都没中时不该显示奖励分")
        XCTAssertTrue(caption.isHidden)
    }

    func testAnUnalignedOutcomeNamesItsFloorInsteadOfALine() throws {
        // 7️⃣7️⃣🔔：最低是 bell，所以赔 bell 的钱，文案报的也是 bell。
        //
        // 文案必须出现——按最低档赔付之后「不同档但仍有奖励」是常态，不是例外。
        // 但它不能叫「LINE」，那个词留给三轮齐平。
        let sut = makeSUT()
        sut.configure(outcome([.seven, .seven, .bell], bonus: 60))

        let value = try XCTUnwrap(label(ReelPanelView.AccessibilityID.bonusValue, in: sut))
        let caption = try XCTUnwrap(label(ReelPanelView.AccessibilityID.lineCaption, in: sut))
        XCTAssertFalse(value.isHidden, "有奖励就该显示奖励分")
        XCTAssertFalse(caption.isHidden, "有奖励就该说明钱是哪一档给的")
        XCTAssertEqual(caption.text, ReelStrings.floorCaption(.bell))
        XCTAssertNotEqual(
            caption.text,
            ReelStrings.lineCaption(.bell),
            "不齐平不该用 LINE 那个词"
        )
    }

    func testAnAlignedOutcomeUsesTheLineWording() throws {
        let sut = makeSUT()
        sut.configure(outcome([.star, .star, .star], bonus: 150))

        let caption = try XCTUnwrap(label(ReelPanelView.AccessibilityID.lineCaption, in: sut))
        XCTAssertEqual(caption.text, ReelStrings.lineCaption(.star))
    }

    func testConfigureCanBeCalledRepeatedlyWithoutStackingState() throws {
        // 先成线再换成空结果：成线时设过的强调与文案必须被收回。
        let sut = makeSUT()
        sut.configure(outcome([.seven, .seven, .seven], bonus: 400))
        sut.configure(outcome([.cherry, .bell, .star]))

        let caption = try XCTUnwrap(label(ReelPanelView.AccessibilityID.lineCaption, in: sut))
        let value = try XCTUnwrap(label(ReelPanelView.AccessibilityID.bonusValue, in: sut))
        XCTAssertTrue(caption.isHidden)
        XCTAssertTrue(value.isHidden)
    }

    // MARK: - Reduce Motion

    func testReducedMotionSettlesImmediatelyWithoutSpinning() throws {
        let sut = makeSUT()
        let audio = AudioSpy()
        let haptics = HapticSpy()
        var completed = false

        sut.reveal(
            outcome([.star, .star, .star], bonus: 150),
            audio: audio,
            haptics: haptics,
            reducedMotion: true
        ) { completed = true }

        // 同步完成：没有计时器要等。
        XCTAssertTrue(completed, "降级路径应当同步完成")
        XCTAssertFalse(sut.debugIsRevealing, "降级路径应当同步完成，不留下进行中的揭晓")

        let value = try XCTUnwrap(label(ReelPanelView.AccessibilityID.bonusValue, in: sut))
        XCTAssertFalse(value.isHidden, "降级也要显示结果")
    }

    func testReducedMotionKeepsTheAlignmentFeedback() {
        // Reduce Motion 是对动效的偏好，不是对反馈的偏好。把提示音一起去掉会让
        // 这一页在无障碍设置下变得毫无回应。
        let sut = makeSUT()
        let audio = AudioSpy()
        let haptics = HapticSpy()

        sut.reveal(
            outcome([.seven, .seven, .seven], bonus: 400),
            audio: audio,
            haptics: haptics,
            reducedMotion: true
        )

        XCTAssertEqual(audio.lines, 1, "降级仍应播齐平音")
        XCTAssertEqual(haptics.lines, 1, "降级仍应给齐平触感")
        // 但没有逐列定住的那几声——没有逐列定住这件事。
        XCTAssertTrue(audio.settles.isEmpty, "降级不该有逐列定住音")
    }

    func testALowAlignmentIsNotCelebrated() {
        // 樱桃齐平在回合开始时（0/0/0）就成立。若它也放大反馈，「齐平」的分量
        // 会在第一秒就被花掉。
        let sut = makeSUT()
        let audio = AudioSpy()
        let haptics = HapticSpy()

        sut.reveal(
            outcome([.cherry, .cherry, .cherry], bonus: 0),
            audio: audio,
            haptics: haptics,
            reducedMotion: true
        )

        XCTAssertEqual(audio.lines, 0, "低档成线不该播庆祝音")
        XCTAssertEqual(haptics.lines, 0)
    }

    // MARK: - 揭晓动画

    func testTheFullRevealEndsOnTheGivenOutcome() throws {
        let sut = makeSUT()
        let audio = AudioSpy()
        let haptics = HapticSpy()
        let target = outcome([.star, .bell, .seven], bonus: 30)
        let finished = expectation(description: "揭晓完毕")

        sut.reveal(target, audio: audio, haptics: haptics, reducedMotion: false) {
            finished.fulfill()
        }

        // 三列依次定住 + 奖励揭晓的停顿，留足余量。
        wait(for: [finished], timeout: 6)

        // 动画不改变结果：终态必须正是传进去的那个。
        let column = try XCTUnwrap(view(ReelPanelView.AccessibilityID.slot(0), in: sut))
        XCTAssertEqual(
            column.accessibilityLabel,
            ReelStrings.slotLabel(target.slots[0])
        )
        XCTAssertFalse(sut.debugIsRevealing, "揭晓完毕后不该还在进行中")
    }

    func testEveryColumnSettlesExactlyOnce() {
        // 定住音每列一声。若判断「是否已定住」的逻辑写错，会每帧重播一声。
        let sut = makeSUT()
        let audio = AudioSpy()
        let haptics = HapticSpy()
        let finished = expectation(description: "揭晓完毕")

        sut.reveal(
            outcome([.star, .bell, .seven], bonus: 30),
            audio: audio,
            haptics: haptics,
            reducedMotion: false
        ) { finished.fulfill() }

        wait(for: [finished], timeout: 6)

        XCTAssertEqual(
            audio.settles.count,
            ReelDimension.allCases.count,
            "定住音的次数应当正好等于列数 — 实际 \(audio.settles)"
        )
        XCTAssertEqual(audio.settles, [.star, .bell, .seven], "定住音应当按列序播出终值")
    }

    func testTheAccessibilityLabelIsFinalBeforeTheSpinEnds() throws {
        // VoiceOver 用户不该被滚动过程中的中间态干扰——他们要的是结果。
        let sut = makeSUT()
        let target = outcome([.seven, .star, .bell], bonus: 30)

        sut.reveal(target, audio: AudioSpy(), haptics: HapticSpy(), reducedMotion: false)

        // 立刻检查，此时轮子还在滚。
        let column = try XCTUnwrap(view(ReelPanelView.AccessibilityID.slot(0), in: sut))
        XCTAssertEqual(
            column.accessibilityLabel,
            ReelStrings.slotLabel(target.slots[0]),
            "滚动中读到的应当已是终值"
        )
    }

    func testTheSpinningSymbolSequenceIsNotRandom() {
        // 滚动只是动画，同样不该有随机数（见 ReelOutcome 顶部）。两次揭晓同一个
        // 结果，定住音的序列必须一致——若滚动过程掺了随机，定住时机与音序会漂。
        let target = outcome([.star, .bell, .seven], bonus: 30)

        func revealAndCollect() -> [ReelSymbol] {
            let sut = makeSUT()
            let audio = AudioSpy()
            let finished = expectation(description: "揭晓完毕")
            sut.reveal(target, audio: audio, haptics: HapticSpy(), reducedMotion: false) {
                finished.fulfill()
            }
            wait(for: [finished], timeout: 6)
            return audio.settles
        }

        XCTAssertEqual(revealAndCollect(), revealAndCollect())
    }

    func testConfigureDuringARevealStopsTheSpin() {
        // 玩家可能在揭晓途中就点了「再来一局」，页面会被换掉。计时器不能继续跑。
        let sut = makeSUT()
        sut.reveal(
            outcome([.star, .bell, .seven], bonus: 30),
            audio: AudioSpy(),
            haptics: HapticSpy(),
            reducedMotion: false
        )
        XCTAssertTrue(sut.debugIsRevealing, "揭晓应当正在进行")

        sut.configure(outcome([.cherry, .cherry, .cherry], bonus: 20))
        XCTAssertFalse(sut.debugIsRevealing, "configure 必须作废正在跑的揭晓")
    }
}
