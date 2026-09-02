//
//  ReelStrings.swift
//  coufistgade
//
//  转轴相关的文案，来自 Reels.xcstrings。
//
//  为什么又是单独一张表：理由同 AchievementStrings——转轴的档位与文案会在调优中
//  增减，让它独立成表，主表那 32 条已验证过的字符串就不会被牵动。
//
//  和 Strings / AchievementStrings 一样是有类型的访问器：key 集中在一处，
//  插值参数写进签名，调用方无法传错个数。
//

import Foundation

enum ReelStrings {

    private static let table = "Reels"

    // MARK: - 符号与维度

    static func symbolName(_ symbol: ReelSymbol) -> String {
        localized(symbol.localizationKey)
    }

    static func dimensionCaption(_ dimension: ReelDimension) -> String {
        localized(dimension.localizationKey)
    }

    // MARK: - 面板

    static var bonusCaption: String { localized("reel.bonusCaption") }
    static var hint: String { localized("reel.hint") }
    static var panelLabel: String { localized("reel.panelLabel") }

    static func bonusValue(_ points: Int) -> String {
        String(format: localized("reel.bonusValue"), locale: .current, points)
    }

    /// 三轮同档时的文案，例如「STAR LINE」。
    ///
    /// 整句大写，而不是只把 "LINE" 写成大写：这一页所有的说明性标签都是全大写
    /// （SCORE、BEST、COMBO、HITS、CHAIN），而符号名在表里是 "Star" 这样的自然
    /// 写法——直接插进去会得到「Star LINE」，看起来像漏了处理。
    ///
    /// 用 localizedUppercase 而不是 uppercased()：大写规则是分语言的（土耳其语的
    /// i 就不一样）。对没有大小写的语言它是空操作，不会造成破坏。
    static func lineCaption(_ symbol: ReelSymbol) -> String {
        String(format: localized("reel.lineCaption"), locale: .current, symbolName(symbol))
            .localizedUppercase
    }

    /// 三轮不同档但仍有奖励时的文案，例如「BELL BONUS」。
    ///
    /// 和 lineCaption 分开，因为这两件事不一样：同档是三个维度齐平的那一刻，
    /// 值得叫「LINE」；不同档时赔付由最低那一档决定，叫「BONUS」，说的是钱从哪
    /// 来的。两者赔付相同（见 ReelOutcome 顶部），但混用一个词会让玩家以为同档
    /// 没有额外意义。
    static func floorCaption(_ symbol: ReelSymbol) -> String {
        String(format: localized("reel.floorCaption"), locale: .current, symbolName(symbol))
            .localizedUppercase
    }

    // MARK: - 对局中的 HUD

    /// 「还差多少」，例如「+13」。
    static func shortfall(_ amount: Int) -> String {
        String(format: localized("reel.shortfall"), locale: .current, amount)
    }

    /// 已经够到目标档。
    static var shortfallMet: String { localized("reel.shortfallMet") }

    /// 对局中单个轮子的无障碍标签。
    ///
    /// 比结算页那个多带一段「还差多少」：对局中这才是有用的信息，VoiceOver 用户
    /// 需要知道往哪推，而不只是当前落在哪一档。
    static func hudSlotLabel(_ slot: ReelSlot, shortfall: Int?) -> String {
        guard let shortfall, shortfall > 0 else {
            return String(
                format: localized("reel.hudSlotLabelMet"),
                locale: .current,
                dimensionCaption(slot.dimension),
                slot.value,
                symbolName(slot.symbol)
            )
        }
        return String(
            format: localized("reel.hudSlotLabel"),
            locale: .current,
            dimensionCaption(slot.dimension),
            slot.value,
            symbolName(slot.symbol),
            shortfall
        )
    }

    // MARK: - 无障碍

    /// 单个轮子读作「命中 12，星」——把数值也读出来，玩家才能反推阈值，
    /// 而不是只知道落了个符号。
    static func slotLabel(_ slot: ReelSlot) -> String {
        String(
            format: localized("reel.slotLabel"),
            locale: .current,
            dimensionCaption(slot.dimension),
            slot.value,
            symbolName(slot.symbol)
        )
    }

    static func lineAnnouncement(symbol: ReelSymbol, bonus: Int) -> String {
        String(
            format: localized("reel.lineAnnouncement"),
            locale: .current,
            symbolName(symbol),
            bonus
        )
    }

    static func bonusAnnouncement(_ points: Int) -> String {
        String(format: localized("reel.bonusAnnouncement"), locale: .current, points)
    }

    // MARK: - 查表

    private static func localized(_ key: String) -> String {
        NSLocalizedString(key, tableName: table, bundle: .main, value: "", comment: "")
    }

    #if DEBUG
    /// 本类型会解析的全部 key。测试用它逐条核对表里确实有对应条目——拼错的 key
    /// 会原样显示成 key 本身，在英文下看着还算像话，其他语言下就露馅。
    static var allKeys: [String] {
        var keys = [
            "reel.bonusCaption",
            "reel.bonusValue",
            "reel.hint",
            "reel.panelLabel",
            "reel.lineCaption",
            "reel.floorCaption",
            "reel.shortfall",
            "reel.shortfallMet",
            "reel.hudSlotLabel",
            "reel.hudSlotLabelMet",
            "reel.lineAnnouncement",
            "reel.bonusAnnouncement",
            "reel.slotLabel",
        ]
        keys.append(contentsOf: ReelSymbol.allCases.map(\.localizationKey))
        keys.append(contentsOf: ReelDimension.allCases.map(\.localizationKey))
        return keys
    }
    #endif
}
