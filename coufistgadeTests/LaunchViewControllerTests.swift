//
//  LaunchViewControllerTests.swift
//  coufistgadeTests
//
//  启动页的三件事：**交班只发生一次**、点击可跳过、Reduce Motion 走另一条路。
//
//  「只发生一次」是这里唯一真会出错的地方：动画自然结束与用户点击跳过会抢同一个
//  onFinish，而 SceneDelegate 用它换根控制器 —— 调两次就是换两次，第二次会把已经
//  盖上的东西（比如启动链接的网页）连带销毁。
//
//  动画本身不去等真实时长：那会让每条用例慢一秒，而且 UIView.animate 在测试进程
//  里的时序并不可靠。这些用例验证的是状态机，不是秒表。
//

import XCTest
@testable import coufistgade

final class LaunchViewControllerTests: XCTestCase {

    private func makeSUT(reducedMotion: Bool = false) -> LaunchViewController {
        let sut = LaunchViewController(prefersReducedMotion: { reducedMotion })
        sut.loadViewIfNeeded()
        sut.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        sut.view.setNeedsLayout()
        sut.view.layoutIfNeeded()
        return sut
    }

    private func findView(id: String, in root: UIView) -> UIView? {
        if root.accessibilityIdentifier == id { return root }
        for child in root.subviews {
            if let hit = findView(id: id, in: child) { return hit }
        }
        return nil
    }

    // MARK: - 构成

    func testTheBallAndWordmarkAreBothPresent() throws {
        let sut = makeSUT()
        XCTAssertNotNil(findView(id: LaunchViewController.AccessibilityID.ball, in: sut.view))
        XCTAssertNotNil(findView(id: LaunchViewController.AccessibilityID.wordmark, in: sut.view))
    }

    func testTheBackgroundMatchesTheStaticLaunchScreen() {
        // 这一条挡的是「启动图切到第一帧时闪一下」：Info.plist 的 UILaunchScreen
        // 用 AppBackground，这里必须是同一个 asset 而不是另写一个近似色。
        let sut = makeSUT()
        XCTAssertEqual(sut.view.backgroundColor, UIColor(resource: .appBackground))
    }

    func testTheWholeScreenReadsAsOneVoiceOverElement() {
        // 球和字标各自念一遍是噪音；整屏一句话才是有用的。
        let sut = makeSUT()
        XCTAssertTrue(sut.view.isAccessibilityElement)
        XCTAssertEqual(sut.view.accessibilityLabel, Strings.launchLabel)

        let ball = findView(id: LaunchViewController.AccessibilityID.ball, in: sut.view)
        let wordmark = findView(id: LaunchViewController.AccessibilityID.wordmark, in: sut.view)
        XCTAssertEqual(ball?.isAccessibilityElement, false)
        XCTAssertEqual(wordmark?.isAccessibilityElement, false)
    }
}

// MARK: - 交班

extension LaunchViewControllerTests {

    func testFinishingCallsBackExactlyOnce() {
        // 状态机的核心约束。SceneDelegate 拿这个回调换根控制器，调两次就换两次，
        // 第二次会把已经盖上的东西连带销毁。
        let sut = makeSUT()
        var calls = 0
        let done = expectation(description: "onFinish")
        sut.onFinish = {
            calls += 1
            if calls == 1 { done.fulfill() }
        }

        sut.beginAppearanceTransition(true, animated: false)
        sut.endAppearanceTransition()
        wait(for: [done], timeout: 5)

        // 动画已经自然结束过一次，再跳过一次不该再交班。
        sut.skip()
        XCTAssertEqual(calls, 1, "onFinish 被调了 \(calls) 次")
    }

    func testTappingSkipsStraightToTheHandoff() {
        // 回头客不该被这一秒挡住。
        let sut = makeSUT()
        let done = expectation(description: "onFinish")
        sut.onFinish = { done.fulfill() }

        sut.beginAppearanceTransition(true, animated: false)
        sut.endAppearanceTransition()
        // 不等动画，直接跳过。
        sut.skip()

        wait(for: [done], timeout: 1)
        XCTAssertFalse(sut.isAnimating, "跳过之后动画标志应当已经落下")
    }

    func testThereIsATapGestureToSkipWith() {
        let sut = makeSUT()
        let taps = sut.view.gestureRecognizers?.compactMap { $0 as? UITapGestureRecognizer } ?? []
        XCTAssertEqual(taps.count, 1, "整屏应当恰好有一个用于跳过的点击手势")
    }
}

// MARK: - Reduce Motion

extension LaunchViewControllerTests {

    func testReducedMotionStillShowsBothElements() {
        // UI_DESIGN §20：减少动画，但不能把东西拿掉。落体没了，球和字标必须还在。
        let sut = makeSUT(reducedMotion: true)
        let done = expectation(description: "onFinish")
        sut.onFinish = { done.fulfill() }

        sut.beginAppearanceTransition(true, animated: false)
        sut.endAppearanceTransition()
        wait(for: [done], timeout: 5)

        let ball = findView(id: LaunchViewController.AccessibilityID.ball, in: sut.view)
        let wordmark = findView(id: LaunchViewController.AccessibilityID.wordmark, in: sut.view)
        XCTAssertEqual(ball?.alpha, 1, "Reduce Motion 下球应当可见")
        XCTAssertEqual(wordmark?.alpha, 1, "Reduce Motion 下字标应当可见")
    }

    func testReducedMotionStillHandsOff() {
        // 最要紧的一条：如果这条路径忘了调 onFinish，开了 Reduce Motion 的用户会
        // 永久卡在启动页上 —— 一个只在辅助功能开启时出现的死锁。
        let sut = makeSUT(reducedMotion: true)
        let done = expectation(description: "onFinish")
        sut.onFinish = { done.fulfill() }

        sut.beginAppearanceTransition(true, animated: false)
        sut.endAppearanceTransition()

        wait(for: [done], timeout: 5)
    }

    func testTheBallDoesNotBreatheOnTheLaunchScreen() throws {
        // 启动页的球在做落体，呼吸叠上去会互相干扰。首页那个才呼吸。
        let sut = makeSUT()
        let ball = try XCTUnwrap(
            findView(id: LaunchViewController.AccessibilityID.ball, in: sut.view) as? HeroBallView
        )
        sut.beginAppearanceTransition(true, animated: false)
        sut.endAppearanceTransition()
        XCTAssertFalse(ball.isFloating)
    }
}
