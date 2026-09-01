//
//  AchievementsViewControllerTests.swift
//  coufistgadeTests
//
//  这一页第一版有两处布局错误：滚动视图的底部约束方向错了（内容被裁），横向尺寸
//  绑到了 content guide（宽度由内容决定，形成循环）。下面的测试针对这两点。
//

import XCTest
@testable import coufistgade

final class AchievementsViewControllerTests: XCTestCase {

    private let screen = CGSize(width: 393, height: 852)
    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    private func makeSUT(
        unlocked: [String] = [],
        size: CGSize? = nil
    ) -> AchievementsViewController {
        let defaults = UserDefaults(suiteName: "bouncy.tests.\(UUID().uuidString)")!
        var store = PersistenceManager(defaults: defaults)
        store.unlockAchievements(unlocked)

        let sut = AchievementsViewController(tracker: AchievementTracker(store: store))
        let window = UIWindow(frame: CGRect(origin: .zero, size: size ?? screen))
        window.rootViewController = sut
        window.makeKeyAndVisible()
        self.window = window
        sut.view.layoutIfNeeded()
        return sut
    }

    private func scrollView(in sut: AchievementsViewController) -> UIScrollView? {
        func search(_ view: UIView) -> UIScrollView? {
            if let found = view as? UIScrollView { return found }
            for subview in view.subviews {
                if let found = search(subview) { return found }
            }
            return nil
        }
        return search(sut.view)
    }

    private func rows(in sut: AchievementsViewController) -> [AchievementRowView] {
        func search(_ view: UIView) -> [AchievementRowView] {
            var found: [AchievementRowView] = []
            for subview in view.subviews {
                if let row = subview as? AchievementRowView { found.append(row) }
                found.append(contentsOf: search(subview))
            }
            return found
        }
        return search(sut.view)
    }

    // MARK: - 行

    func testEveryAchievementGetsARow() {
        let sut = makeSUT()

        XCTAssertEqual(rows(in: sut).count, Achievement.all.count)
    }

    // MARK: - 滚动内容
    //
    // 「显示不全」的起因：底部约束用了负常量。滚动视图的裸 bottomAnchor 指向
    // content guide，负值会把内容高度压得比实际行高更短，最后一行被裁掉。

    func testTheContentIsTallEnoughToHoldEveryRow() throws {
        let sut = makeSUT()
        let scroll = try XCTUnwrap(scrollView(in: sut))
        let allRows = rows(in: sut)

        let rowsHeight = allRows.reduce(0) { $0 + $1.bounds.height }

        // 内容高度必须覆盖所有行的总高。压缩即为裁切。
        XCTAssertGreaterThanOrEqual(
            scroll.contentSize.height,
            rowsHeight,
            "内容高度 \(scroll.contentSize.height) 小于行高总和 \(rowsHeight)，最后一行会被裁掉。"
        )
    }

    func testTheLastRowCanBeScrolledFullyIntoView() throws {
        let sut = makeSUT()
        let scroll = try XCTUnwrap(scrollView(in: sut))
        let lastRow = try XCTUnwrap(rows(in: sut).last)

        // 滚到底，再问最后一行是否完整落在可视区内。
        let maximumOffset = max(0, scroll.contentSize.height - scroll.bounds.height)
        scroll.contentOffset = CGPoint(x: 0, y: maximumOffset)
        sut.view.layoutIfNeeded()

        let rowInScroll = lastRow.convert(lastRow.bounds, to: scroll)
        let visible = CGRect(
            origin: scroll.contentOffset,
            size: scroll.bounds.size
        )

        XCTAssertTrue(
            visible.contains(rowInScroll),
            "滚到底后最后一行仍未完整可见：行 \(rowInScroll)，可视区 \(visible)。"
        )
    }

    func testTheContentIsScrollableRatherThanClipped() throws {
        let sut = makeSUT()
        let scroll = try XCTUnwrap(scrollView(in: sut))

        // 十条成就在任何 iPhone 上都装不下一屏，所以内容必须比可视区高 —— 否则
        // 说明内容高度算错了。
        XCTAssertGreaterThan(
            scroll.contentSize.height,
            scroll.bounds.height,
            "内容不比可视区高，说明高度被压缩了。"
        )
    }

    // MARK: - 横向尺寸
    //
    // 第二处错误：五条约束全指向裸 anchor（content guide），宽度由内容决定，而
    // 标签换行又依赖宽度 —— 循环。横向必须绑 frameLayoutGuide。

    func testRowsMatchTheScreenWidthNotTheirContent() throws {
        let sut = makeSUT()
        let scroll = try XCTUnwrap(scrollView(in: sut))
        let allRows = rows(in: sut)

        for row in allRows {
            XCTAssertEqual(
                row.bounds.width,
                scroll.bounds.width - Theme.Spacing.m * 2,
                accuracy: 1,
                "行宽来自内容而非屏幕：\(row.bounds.width)"
            )
        }
    }

    func testEveryRowIsTheSameWidth() {
        let sut = makeSUT()

        // 宽度若来自各行内容，文案长的行会更宽 —— 这正是循环约束的表征。
        let widths = Set(rows(in: sut).map { ($0.bounds.width * 10).rounded() / 10 })
        XCTAssertEqual(widths.count, 1, "各行宽度不一致：\(widths)")
    }

    func testTheLayoutHoldsOnTheSmallestPhone() throws {
        // SE 尺寸：横向空间最紧，中文标题最可能被压。
        let sut = makeSUT(size: CGSize(width: 375, height: 667))
        let scroll = try XCTUnwrap(scrollView(in: sut))

        XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.height)
        for row in rows(in: sut) {
            XCTAssertGreaterThan(row.bounds.height, 0, "行高塌成 0")
            XCTAssertEqual(
                row.bounds.width,
                scroll.bounds.width - Theme.Spacing.m * 2,
                accuracy: 1
            )
        }
    }

    func testNoRowClipsItsText() {
        let sut = makeSUT()

        // 行高必须容纳换行后的文字。标签设了 numberOfLines = 0，行高由它们撑开，
        // 塌到接近图标高度就说明约束没连上。
        for row in rows(in: sut) {
            XCTAssertGreaterThan(row.bounds.height, 44, "行高 \(row.bounds.height) 容不下两行文字")
        }
    }

    // MARK: - 状态

    func testUnlockedAndLockedRowsBothRender() {
        let sut = makeSUT(unlocked: ["firstPoints"])

        // 未解锁的行也要显示目标：藏起来玩家就不知道该追什么。
        XCTAssertEqual(rows(in: sut).count, Achievement.all.count)
    }

    func testTheProgressCountReflectsWhatIsUnlocked() {
        let sut = makeSUT(unlocked: ["firstPoints", "century"])

        func label(_ id: String, in view: UIView) -> UILabel? {
            if let found = view as? UILabel, found.accessibilityIdentifier == id { return found }
            for subview in view.subviews {
                if let found = label(id, in: subview) { return found }
            }
            return nil
        }

        let text = label(
            AchievementsViewController.AccessibilityID.progressLabel,
            in: sut.view
        )?.text
        XCTAssertNotNil(text)
        XCTAssertTrue(text?.contains("2") == true, "进度文案未反映已解锁数量：\(text ?? "nil")")
    }

    // MARK: - 无障碍

    func testEachRowReadsAsOneElement() {
        let sut = makeSUT(unlocked: ["firstPoints"])

        // VoiceOver 应当读出「名称，说明，已解锁」整句，而不是三段碎片。
        for row in rows(in: sut) {
            XCTAssertTrue(row.isAccessibilityElement)
            let label = row.accessibilityLabel ?? ""
            XCTAssertFalse(label.isEmpty)
            XCTAssertTrue(label.contains(","), "无障碍标签未合并三段信息：\(label)")
        }
    }
}
