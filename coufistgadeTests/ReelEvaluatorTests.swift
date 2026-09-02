//
//  ReelEvaluatorTests.swift
//  coufistgadeTests
//
//  判定逻辑不碰 SpriteKit、不碰 UIKit、不读时钟，所以整套转轴规则可以直接测。
//
//  这里最重要的一组是「确定性」那几条：转轴无随机数既是玩法设计的核心（同一局
//  成绩永远转出同一个结果，于是它是个可以学会的目标），也是这个功能能在分级问卷
//  里把 Chance-Based Activities 全答 No 的前提。这条性质必须由测试守住，不能只
//  靠注释声明。
//

import XCTest
@testable import coufistgade

final class ReelEvaluatorTests: XCTestCase {

    private func summary(score: Int = 0, combo: Int = 0, hits: Int = 0) -> RoundSummary {
        RoundSummary(score: score, highestCombo: combo, hits: hits)
    }

    private func slot(_ outcome: ReelOutcome, _ dimension: ReelDimension) -> ReelSlot {
        outcome.slots.first { $0.dimension == dimension }!
    }

    // MARK: - 确定性（这一组是这个功能的地基，见文件头）

    func testTheSameRoundAlwaysProducesTheSameOutcome() {
        let sut = ReelEvaluator()
        let round = summary(score: 640, combo: 5, hits: 17)

        let first = sut.evaluate(round)
        // 同一个判定器反复评同一局：转轴不该有任何内部状态。
        for iteration in 1...200 {
            XCTAssertEqual(sut.evaluate(round), first, "第 \(iteration) 次评出了不同结果")
        }
    }

    func testTwoSeparateEvaluatorsAgreeOnTheSameRound() {
        // 若哪天有人塞进一个随机源，两个实例各自播种就会分叉——这条会抓到它。
        let round = summary(score: 210, combo: 3, hits: 9)
        XCTAssertEqual(ReelEvaluator().evaluate(round), ReelEvaluator().evaluate(round))
    }

    func testOutcomeDependsOnlyOnTheRoundValues() {
        // 三个维度全等的两个 summary 必须给出全等的结果。
        let a = ReelEvaluator().evaluate(summary(score: 1_000, combo: 7, hits: 25))
        let b = ReelEvaluator().evaluate(summary(score: 1_000, combo: 7, hits: 25))
        XCTAssertEqual(a, b)
    }

    // MARK: - 阈值表本身

    func testEveryDimensionHasAThresholdTable() {
        // 缺表的维度会静默落到最低档，玩家看到的轮子就永远是樱桃。
        for dimension in ReelDimension.allCases {
            XCTAssertNotNil(
                GameConfiguration.Reels.thresholds[dimension],
                "\(dimension) 没有阈值表"
            )
        }
    }

    func testEveryThresholdTableIsStrictlyDescending() {
        // 查表取「第一条够到的」，所以表必须由高到低。顺序错了会让高分落到低档。
        for (dimension, ladder) in GameConfiguration.Reels.thresholds {
            let values = ladder.map(\.minimumValue)
            XCTAssertEqual(values, values.sorted(by: >), "\(dimension) 的阈值未降序：\(values)")
            XCTAssertEqual(Set(values).count, values.count, "\(dimension) 有重复阈值")
        }
    }

    func testEveryThresholdTableReachesZero() {
        // 最低一档必须是 0，否则 0 分那一局落不到任何档上。
        for (dimension, ladder) in GameConfiguration.Reels.thresholds {
            XCTAssertEqual(ladder.last?.minimumValue, 0, "\(dimension) 的最低档不是 0")
        }
    }

    func testSymbolTiersRiseWithThresholds() {
        // 阈值越高的档，符号也必须越高——否则打得越好反而拿到更低的符号。
        for (dimension, ladder) in GameConfiguration.Reels.thresholds {
            let tiers = ladder.map(\.symbol.tier)
            XCTAssertEqual(tiers, tiers.sorted(by: >), "\(dimension) 的符号档位与阈值不同向")
        }
    }

    // MARK: - 落档

    func testAnEmptyRoundLandsOnTheLowestSymbolEverywhere() {
        // 一局什么都没干：三个轮子都该落在最低档，而不是空着。
        let outcome = ReelEvaluator().evaluate(summary())

        XCTAssertEqual(outcome.slots.count, ReelDimension.allCases.count)
        for slot in outcome.slots {
            XCTAssertEqual(slot.symbol, .cherry, "\(slot.dimension) 没落到最低档")
        }
    }

    func testEachReelReadsItsOwnDimension() {
        // 三个轮子读三件不同的事。接错线的话这条会抓到：只有 hits 够到 seven。
        let outcome = ReelEvaluator().evaluate(summary(score: 0, combo: 0, hits: 25))

        XCTAssertEqual(slot(outcome, .hits).symbol, .seven)
        XCTAssertEqual(slot(outcome, .combo).symbol, .cherry)
        XCTAssertEqual(slot(outcome, .score).symbol, .cherry)
    }

    func testSlotsCarryTheirRawValue() {
        // 无障碍标签要读出「命中 12，星」，所以原始数值必须随符号一起带出来。
        let outcome = ReelEvaluator().evaluate(summary(score: 640, combo: 5, hits: 17))

        XCTAssertEqual(slot(outcome, .hits).value, 17)
        XCTAssertEqual(slot(outcome, .combo).value, 5)
        XCTAssertEqual(slot(outcome, .score).value, 640)
    }

    func testSlotOrderMatchesTheDimensionOrder() {
        // 屏幕上从左到右的排列由这个顺序决定，面板直接 zip 它。
        let outcome = ReelEvaluator().evaluate(summary(score: 100, combo: 2, hits: 5))
        XCTAssertEqual(outcome.slots.map(\.dimension), ReelDimension.allCases)
    }

    // MARK: - 边界

    func testAValueExactlyOnAThresholdTakesTheHigherSymbol() throws {
        // 「>= 阈值」而不是「> 阈值」：成就 busyRound 的目标是 25 次命中，
        // 打满 25 次却拿不到对应档位会说不通。
        let ladder = try XCTUnwrap(GameConfiguration.Reels.thresholds[.hits])
        for rung in ladder where rung.minimumValue > 0 {
            let outcome = ReelEvaluator().evaluate(summary(hits: rung.minimumValue))
            XCTAssertEqual(
                slot(outcome, .hits).symbol,
                rung.symbol,
                "命中 \(rung.minimumValue) 应当正好落在 \(rung.symbol)"
            )
        }
    }

    func testOneBelowAThresholdTakesTheLowerSymbol() throws {
        let ladder = try XCTUnwrap(GameConfiguration.Reels.thresholds[.hits])
        for rung in ladder where rung.minimumValue > 0 {
            let outcome = ReelEvaluator().evaluate(summary(hits: rung.minimumValue - 1))
            XCTAssertLessThan(
                slot(outcome, .hits).symbol.tier,
                rung.symbol.tier,
                "命中 \(rung.minimumValue - 1) 不该够到 \(rung.symbol)"
            )
        }
    }

    func testValuesFarAboveTheTopStillLandOnTheTopSymbol() {
        // 分数没有上限，远超顶档时不能溢出到别处。
        let outcome = ReelEvaluator().evaluate(
            summary(score: 999_999, combo: 999, hits: 999)
        )
        for slot in outcome.slots {
            XCTAssertEqual(slot.symbol, .seven, "\(slot.dimension) 在极大值下没落到顶档")
        }
    }

    func testNegativeValuesStillLandOnASymbol() {
        // 分数不该为负，但判定器不能因此崩掉或返回空轮子。
        let outcome = ReelEvaluator().evaluate(summary(score: -50, combo: -1, hits: -3))
        XCTAssertEqual(outcome.slots.count, ReelDimension.allCases.count)
        for slot in outcome.slots {
            XCTAssertEqual(slot.symbol, .cherry)
        }
    }

    // MARK: - 按最低档赔付

    func testAnEmptyRoundPaysNothing() {
        // 三轮全落樱桃。樱桃档赔 0——回合开始时三个轮子就都是樱桃，若它给分，
        // 奖励行会在第一秒亮起来并一直亮着，那时它就不再是个可争的东西。
        let outcome = ReelEvaluator().evaluate(summary())

        XCTAssertEqual(outcome.floorSymbol, .cherry)
        XCTAssertEqual(outcome.bonus, 0)
        XCTAssertTrue(outcome.isBlank)
        // 三轮确实同档，只是这一档不给钱。
        XCTAssertTrue(outcome.isAligned)
    }

    func testTheBonusComesFromTheLowestReel() {
        // 这条是新规则的核心：命中 5（bell）、连击 7（seven）、得分 500（star），
        // 最低是 bell，所以赔 bell 的钱——不是最高的 seven，也不是中间的 star。
        let outcome = ReelEvaluator().evaluate(summary(score: 500, combo: 7, hits: 5))

        XCTAssertEqual(outcome.floorSymbol, .bell)
        XCTAssertEqual(outcome.bonus, GameConfiguration.Reels.bonus(for: .bell))
        XCTAssertFalse(outcome.isAligned)
    }

    func testRaisingAnyDimensionNeverLowersTheBonus() {
        // 这是按最低档赔付存在的全部理由：推高任何一个维度都不该亏。
        //
        // 旧规则（三轮必须同档）在这里会失败——得分从 990 跨到 1000 会打破
        // star 线，奖励从 150 掉到 0，于是终局最优解变成停手。
        let sut = ReelEvaluator()
        let base = summary(score: 900, combo: 4, hits: 12)
        let baseBonus = sut.evaluate(base).bonus

        // 逐个维度各加一点，都不能让奖励下降。
        let raised = [
            summary(score: 900 + 200, combo: 4, hits: 12),
            summary(score: 900, combo: 4 + 5, hits: 12),
            summary(score: 900, combo: 4, hits: 12 + 20),
        ]
        for round in raised {
            XCTAssertGreaterThanOrEqual(
                sut.evaluate(round).bonus,
                baseBonus,
                "推高一个维度让奖励下降了 — \(round)"
            )
        }
    }

    func testBonusIsMonotonicAcrossAWholeRound() {
        // 更强的版本：模拟一局里三个维度一路增长，奖励必须单调不减。
        //
        // 用固定的增长序列而不是随机采样——这套逻辑本身不含随机数，测试也不该引入。
        let sut = ReelEvaluator()
        var previous = 0

        for step in 0...40 {
            // 三个维度按不同速率增长，刻意让它们错开跨档，正是旧规则会断线的形状。
            let round = summary(score: step * 40, combo: step / 5, hits: step)
            let bonus = sut.evaluate(round).bonus
            XCTAssertGreaterThanOrEqual(
                bonus,
                previous,
                "第 \(step) 步奖励下降了：\(previous) → \(bonus)"
            )
            previous = bonus
        }
    }

    func testTheTopBonusNeedsAllThreeDimensionsMaxed() throws {
        // 这是整套设计的意图所在：777 不是运气，是三个维度同时打满。
        // 按最低档赔付之后这条更直接了——最低档要到 seven，三个都得到 seven。
        let hits = try XCTUnwrap(GameConfiguration.Reels.thresholds[.hits]?.first)
        let combo = try XCTUnwrap(GameConfiguration.Reels.thresholds[.combo]?.first)
        let score = try XCTUnwrap(GameConfiguration.Reels.thresholds[.score]?.first)

        let outcome = ReelEvaluator().evaluate(
            summary(score: score.minimumValue, combo: combo.minimumValue, hits: hits.minimumValue)
        )
        XCTAssertEqual(outcome.floorSymbol, .seven)
        XCTAssertTrue(outcome.isAligned)
        XCTAssertEqual(outcome.bonus, GameConfiguration.Reels.bonus(for: .seven))
    }

    func testFallingShortOnOneDimensionCapsTheBonus() throws {
        // 偏科拿不到顶档——这条是「不能只堆一项」的直接断言。
        let hits = try XCTUnwrap(GameConfiguration.Reels.thresholds[.hits]?.first)
        let combo = try XCTUnwrap(GameConfiguration.Reels.thresholds[.combo]?.first)
        let score = try XCTUnwrap(GameConfiguration.Reels.thresholds[.score]?.first)

        let outcome = ReelEvaluator().evaluate(
            summary(
                score: score.minimumValue,
                combo: combo.minimumValue,
                // 只差一次命中。
                hits: hits.minimumValue - 1
            )
        )
        XCTAssertNotEqual(outcome.floorSymbol, .seven, "有个维度没满却拿到了顶档")
        XCTAssertLessThan(outcome.bonus, GameConfiguration.Reels.bonus(for: .seven))
        // 拖住的正是那个差一点的维度，界面要靠这个给出「往哪推」的指引。
        XCTAssertEqual(outcome.laggingDimensions, [.hits])
    }

    func testHigherFloorsPayMore() {
        // 奖励必须随档位单调递增：低档给得更多会让玩家宁愿打差一点。
        let bonuses = ReelSymbol.allCases.map(GameConfiguration.Reels.bonus(for:))
        XCTAssertEqual(bonuses, bonuses.sorted(), "奖励未随档位递增：\(bonuses)")
    }

    func testOnlyCherryPaysNothing() {
        // 樱桃档赔 0 是有意的（回合开始就成立）；其余每一档都必须给钱，
        // 否则那一档在玩家看来就是个没有回报的台阶。
        XCTAssertEqual(GameConfiguration.Reels.bonus(for: .cherry), 0)
        for symbol in ReelSymbol.allCases where symbol != .cherry {
            XCTAssertGreaterThan(
                GameConfiguration.Reels.bonus(for: symbol),
                0,
                "\(symbol) 档没有奖励"
            )
        }
    }

    func testAlignmentDoesNotPayExtra() {
        // 齐平只给反馈，不加钱。加钱会把「保住齐平」重新变成停手的理由——
        // 那正是按最低档赔付要消除的东西。
        let aligned = ReelEvaluator().evaluate(summary(score: 500, combo: 4, hits: 12))
        XCTAssertTrue(aligned.isAligned)

        // 同样是 star 最低档，但不齐平（得分冲到了 seven）。
        let lopsided = ReelEvaluator().evaluate(summary(score: 1_200, combo: 4, hits: 12))
        XCTAssertFalse(lopsided.isAligned)
        XCTAssertEqual(lopsided.floorSymbol, .star)

        XCTAssertEqual(aligned.bonus, lopsided.bonus, "齐平不该比不齐平多给钱")
    }

    // MARK: - 拖住赔付的那几个轮子

    func testTheLaggingDimensionIsTheLowestOne() {
        // 命中 5（bell）、连击 7（seven）、得分 500（star）：bell 最低。
        let outcome = ReelEvaluator().evaluate(summary(score: 500, combo: 7, hits: 5))
        XCTAssertEqual(outcome.laggingDimensions, [.hits])
    }

    func testSeveralDimensionsCanLagTogether() {
        // 命中 5（bell）、连击 2（bell）、得分 1000（seven）：两个都在 bell。
        // 界面要把这两个都标出来，玩家才知道推一个还不够。
        let outcome = ReelEvaluator().evaluate(summary(score: 1_000, combo: 2, hits: 5))
        XCTAssertEqual(Set(outcome.laggingDimensions), [.hits, .combo])
    }

    func testEveryDimensionLagsWhenAligned() {
        let outcome = ReelEvaluator().evaluate(summary(score: 500, combo: 4, hits: 12))
        XCTAssertTrue(outcome.isAligned)
        XCTAssertEqual(Set(outcome.laggingDimensions), Set(ReelDimension.allCases))
    }

    // MARK: - 对局中的进度

    func testProgressTargetsTheTierAboveTheFloor() {
        // 目标是比最低档高一级：只有把最低的推上去才能提高奖励。
        let progress = ReelEvaluator().progress(summary(score: 500, combo: 7, hits: 5))

        XCTAssertEqual(progress.outcome.floorSymbol, .bell)
        XCTAssertEqual(progress.target, .star)
    }

    func testProgressReportsHowMuchIsMissing() throws {
        // 命中 5，star 档要 12，所以还差 7。这个数字就是 HUD 上写的那个。
        let progress = ReelEvaluator().progress(summary(score: 500, combo: 7, hits: 5))

        XCTAssertEqual(progress.shortfall(for: .hits), 7)
        // 连击已经是 seven，早就够到 star 了，所以不在表里。
        XCTAssertNil(progress.shortfall(for: .combo))
        // 得分正好在 star 档上，也算够到。
        XCTAssertNil(progress.shortfall(for: .score))
    }

    func testProgressAtTheTopHasNoTarget() {
        // 三轮全 seven：没有下一档可争了，HUD 不该再显示「还差多少」。
        let progress = ReelEvaluator().progress(summary(score: 1_000, combo: 7, hits: 25))

        XCTAssertEqual(progress.outcome.floorSymbol, .seven)
        XCTAssertNil(progress.target)
        XCTAssertTrue(progress.shortfalls.isEmpty)
    }

    func testProgressAtTheStartOfARoundPointsAtTheFirstPayingTier() throws {
        // 一局刚开始（0/0/0）：目标是 bell，也就是第一个给钱的档。
        // 三个维度各差多少，正是玩家开局时该知道的事。
        let sut = ReelEvaluator()
        let progress = sut.progress(summary())

        XCTAssertEqual(progress.target, .bell)
        for dimension in ReelDimension.allCases {
            let required = try XCTUnwrap(sut.minimumValue(for: .bell, in: dimension))
            XCTAssertEqual(
                progress.shortfall(for: dimension),
                required,
                "\(dimension) 开局时的差额应当等于 bell 档的门槛"
            )
        }
    }

    func testShortfallNeverGoesNegative() {
        // 数值远超目标档时差额是 0，不是负数——「还差 -5 次」是个 bug 的样子。
        let progress = ReelEvaluator().progress(summary(score: 999_999, combo: 3, hits: 999))

        for dimension in ReelDimension.allCases {
            if let shortfall = progress.shortfall(for: dimension) {
                XCTAssertGreaterThanOrEqual(shortfall, 0, "\(dimension) 的差额是负数")
            }
        }
    }

    func testProgressIsDeterministicToo() {
        // 对局中的进度同样不含随机数。
        let sut = ReelEvaluator()
        let round = summary(score: 640, combo: 5, hits: 17)
        let first = sut.progress(round)

        for _ in 1...50 {
            XCTAssertEqual(sut.progress(round), first)
        }
    }

    func testMinimumValueReversesTheThresholdTable() throws {
        // 反查必须和正查一致：拿 minimumValue 得到的数值，落档后应当正好是那一档。
        let sut = ReelEvaluator()
        for dimension in ReelDimension.allCases {
            for symbol in ReelSymbol.allCases {
                let required = try XCTUnwrap(
                    sut.minimumValue(for: symbol, in: dimension),
                    "\(dimension) 缺 \(symbol) 档"
                )
                let round: RoundSummary = switch dimension {
                case .hits: summary(hits: required)
                case .combo: summary(combo: required)
                case .score: summary(score: required)
                }
                let landed = sut.evaluate(round).slots.first { $0.dimension == dimension }?.symbol
                XCTAssertEqual(landed, symbol, "\(dimension) 的 \(symbol) 档反查不一致")
            }
        }
    }

    // MARK: - 奖励的注入

    func testTheBonusTableIsInjectable() {
        // 阈值与奖励都可注入，让调优不必改测试，也让测试不必迁就正式数值。
        let sut = ReelEvaluator(bonus: { symbol in symbol == .cherry ? 7 : 7_777 })

        // 空局最低档是 cherry。
        XCTAssertEqual(sut.evaluate(summary()).bonus, 7, "应当用注入的表")
        // 命中 5（bell）、连击 2（bell）、得分 1000（seven）：最低是 bell。
        XCTAssertEqual(sut.evaluate(summary(score: 1_000, combo: 2, hits: 5)).bonus, 7_777)
    }

    func testAMissingThresholdTableFallsBackInsteadOfCrashing() {
        // 表缺失只可能来自测试自造的配置，但轮子必须转出一个符号——空着比给个
        // 偏低的符号更糟。
        let sut = ReelEvaluator(thresholds: [.hits: [(0, .cherry)]])
        let outcome = sut.evaluate(summary(score: 1_000, combo: 7, hits: 25))

        XCTAssertEqual(outcome.slots.count, ReelDimension.allCases.count)
        XCTAssertEqual(slot(outcome, .score).symbol, .cherry)
        XCTAssertEqual(slot(outcome, .combo).symbol, .cherry)
    }
}
