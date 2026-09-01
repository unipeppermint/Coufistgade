//
//  AchievementTrackerTests.swift
//  coufistgadeTests
//
//  判定逻辑不碰 SpriteKit、不读时钟，所以整套成就规则可以直接测。
//

import XCTest
@testable import coufistgade

final class AchievementTrackerTests: XCTestCase {

    private func makeStore() -> PersistenceManager {
        PersistenceManager(defaults: UserDefaults(suiteName: "bouncy.tests.\(UUID().uuidString)")!)
    }

    private func summary(score: Int = 0, combo: Int = 0, hits: Int = 0) -> RoundSummary {
        RoundSummary(score: score, highestCombo: combo, hits: hits)
    }

    private func achievement(_ id: String) -> Achievement {
        Achievement.all.first { $0.id == id }!
    }

    // MARK: - 目录本身

    func testEveryIDIsUnique() {
        // id 是持久化键。重复的 id 会让两条成就互相解锁。
        let ids = Achievement.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "成就 id 重复：\(ids)")
    }

    func testEveryTargetIsPositive() {
        for achievement in Achievement.all {
            XCTAssertGreaterThan(achievement.target, 0, "\(achievement.id) 的目标值无意义")
        }
    }

    func testTheFirstAchievementIsReachableInOneRound() {
        // 第一条刻意做得几乎必然达成：第一局结束就该解锁，让玩家知道有这套系统。
        let first = achievement("firstPoints")
        XCTAssertEqual(first.target, GameConfiguration.Score.base)
    }

    func testComboTargetsStayWithinTheLadder() {
        // 目标值超过连击阶梯顶端就永远无法达成。
        let top = GameConfiguration.Combo.multiplierLadder.map(\.minimumCount).max() ?? 0
        for achievement in Achievement.all where achievement.metric == .roundCombo {
            XCTAssertLessThanOrEqual(achievement.target, top, "\(achievement.id) 无法达成")
        }
    }

    func testTargetsWithinAMetricIncrease() {
        // 同一指标下若目标值不递增，玩家会先解锁难的再解锁简单的，读起来是乱的。
        for metric in AchievementMetric.allCases {
            let targets = Achievement.all.filter { $0.metric == metric }.map(\.target)
            XCTAssertEqual(targets, targets.sorted(), "\(metric) 的目标值未递增：\(targets)")
        }
    }

    // MARK: - 解锁

    func testNothingIsUnlockedOnAFreshInstall() {
        let sut = AchievementTracker(store: makeStore())

        XCTAssertEqual(sut.unlockedCount, 0)
        XCTAssertFalse(sut.isUnlocked(achievement("firstPoints")))
    }

    func testScoringUnlocksTheFirstAchievement() {
        let sut = AchievementTracker(store: makeStore())

        let unlocked = sut.evaluate(summary(score: GameConfiguration.Score.base))

        XCTAssertTrue(unlocked.contains(achievement("firstPoints")))
        XCTAssertTrue(sut.isUnlocked(achievement("firstPoints")))
    }

    func testAnAchievementIsReportedOnlyOnce() {
        let sut = AchievementTracker(store: makeStore())
        _ = sut.evaluate(summary(score: 100))

        // 第二局同样的成绩不该再报一次——结算页要显示的是"刚达成了什么"。
        let second = sut.evaluate(summary(score: 100))

        XCTAssertTrue(second.isEmpty, "重复上报：\(second.map(\.id))")
    }

    func testOneRoundCanUnlockSeveralAtOnce() {
        let sut = AchievementTracker(store: makeStore())

        // 一局 500 分同时越过 10 / 100 / 500 三档。
        let unlocked = sut.evaluate(summary(score: 500))

        XCTAssertEqual(
            Set(unlocked.map(\.id)),
            ["firstPoints", "century", "fiveHundred"]
        )
    }

    func testAWeakRoundUnlocksNothingAlreadyEarned() {
        let sut = AchievementTracker(store: makeStore())
        _ = sut.evaluate(summary(score: 500))
        let before = sut.unlockedCount

        _ = sut.evaluate(summary(score: 10))

        XCTAssertEqual(sut.unlockedCount, before)
    }

    func testUnlockingSurvivesANewTrackerOnTheSameStore() {
        let store = makeStore()
        _ = AchievementTracker(store: store).evaluate(summary(score: 100))

        // 换一个 tracker，数据应当还在——持久化的意义就在这里。
        XCTAssertTrue(AchievementTracker(store: store).isUnlocked(achievement("century")))
    }

    // MARK: - 单局与生涯的区别

    func testRoundMetricsComeFromTheRoundNotTheStore() {
        let sut = AchievementTracker(store: makeStore())

        // 生涯累计是 0，但本局连击 10 应当解锁单局类成就。
        let unlocked = sut.evaluate(summary(score: 10, combo: 10))

        XCTAssertTrue(unlocked.contains(achievement("chainTen")))
    }

    func testCareerMetricsComeFromTheStore() {
        var store = makeStore()
        // 模拟已经打过 10 局。
        for _ in 0..<10 { _ = store.record(score: 10, combo: 1) }
        let sut = AchievementTracker(store: store)

        let unlocked = sut.evaluate(summary(score: 10))

        XCTAssertTrue(
            unlocked.contains(achievement("tenRounds")),
            "生涯类成就没有从 store 取值"
        )
    }

    func testHitsAreTrackedSeparatelyFromScore() {
        let sut = AchievementTracker(store: makeStore())

        // 25 次命中但只有基础分——高连击下 25 次命中的分数远高于 250，
        // 所以这两个指标必须分开取，不能互相推导。
        let unlocked = sut.evaluate(summary(score: 250, combo: 1, hits: 25))

        XCTAssertTrue(unlocked.contains(achievement("busyRound")))
    }

    // MARK: - 进度

    func testRoundAchievementsHaveNoProgressBar() {
        let sut = AchievementTracker(store: makeStore())

        // 上一局得 300 分不代表离"单局 500 分"更近，画进度条是误导。
        XCTAssertNil(sut.progress(for: achievement("fiveHundred")))
        XCTAssertNil(sut.progress(for: achievement("chainTen")))
    }

    func testCareerAchievementsReportProgress() throws {
        var store = makeStore()
        for _ in 0..<5 { _ = store.record(score: 10, combo: 1) }
        let sut = AchievementTracker(store: store)

        let progress = try XCTUnwrap(sut.progress(for: achievement("tenRounds")))

        XCTAssertEqual(progress, 0.5, accuracy: 0.001)
    }

    func testProgressIsClampedToOne() throws {
        var store = makeStore()
        for _ in 0..<30 { _ = store.record(score: 10, combo: 1) }
        let sut = AchievementTracker(store: store)

        let progress = try XCTUnwrap(sut.progress(for: achievement("tenRounds")))

        XCTAssertEqual(progress, 1.0, accuracy: 0.001)
    }

    // MARK: - 文案

    func testEveryAchievementHasBothStrings() {
        // key 拼错会原样显示成 key 本身，在英文下看着还算像话，中文下就露馅。
        for achievement in Achievement.all {
            let title = AchievementStrings.title(achievement)
            let detail = AchievementStrings.detail(achievement)

            XCTAssertFalse(title.isEmpty, "\(achievement.id) 缺标题")
            XCTAssertNotEqual(title, achievement.titleKey, "\(achievement.id) 标题未翻译")
            XCTAssertFalse(detail.isEmpty, "\(achievement.id) 缺说明")
            XCTAssertNotEqual(detail, achievement.detailKey, "\(achievement.id) 说明未翻译")
        }
    }

    func testEveryDeclaredKeyResolves() {
        for key in AchievementStrings.allKeys {
            let value = NSLocalizedString(key, tableName: "Achievements", bundle: .main, value: "", comment: "")
            XCTAssertFalse(value.isEmpty, "\(key) 不在 Achievements 表里")
            XCTAssertNotEqual(value, key, "\(key) 原样返回，说明查表失败")
        }
    }

    func testEnglishCarriesEveryAchievementString() throws {
        // 只剩英文一种语言。英文的值等于 key，所以 NSLocalizedString 的返回值看不出
        // 「查到了」和「没这条」的区别——必须去编译产物里查。
        let path = try XCTUnwrap(
            Bundle.main.path(forResource: "en", ofType: "lproj"),
            "en.lproj 不在 bundle 里"
        )
        let bundle = try XCTUnwrap(Bundle(path: path))

        guard let url = bundle.url(forResource: "Achievements", withExtension: "strings"),
              let data = try? Data(contentsOf: url),
              let table = try? PropertyListSerialization.propertyList(
                  from: data, options: [], format: nil
              ) as? [String: String]
        else {
            throw XCTSkip("这个工具链输出的是二进制 .strings，读不到条目")
        }

        for key in AchievementStrings.allKeys {
            XCTAssertNotNil(table[key], "Achievements 表里没有 \(key)")
        }
    }
}
