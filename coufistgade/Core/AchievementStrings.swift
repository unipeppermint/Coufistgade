//
//  AchievementStrings.swift
//  coufistgade
//
//  成就相关的文案，来自 Achievements.xcstrings。
//
//  为什么单独一张表而不是并入 Localizable.xcstrings：成就条目会随版本增加，
//  一次加两条（title + detail）。让它们独立成表，主表那 32 条已验证过的字符串
//  就不会在每次加成就时被牵动。
//
//  和 Strings 一样是有类型的访问器：key 集中在一处，插值参数写进签名，
//  调用方无法传错个数。
//

import Foundation

enum AchievementStrings {

    private static let table = "Achievements"

    // MARK: - 单条成就

    static func title(_ achievement: Achievement) -> String {
        localized(achievement.titleKey)
    }

    static func detail(_ achievement: Achievement) -> String {
        localized(achievement.detailKey)
    }

    // MARK: - 成就页

    static var screenTitle: String { localized("achievements.title") }
    static var unlockedState: String { localized("achievements.unlocked") }
    static var lockedState: String { localized("achievements.locked") }
    static var emptyHint: String { localized("achievements.empty") }
    static var newlyUnlockedCaption: String { localized("result.newAchievements") }

    static func progressCount(unlocked: Int, total: Int) -> String {
        String(format: localized("achievements.progressCount"), locale: .current, unlocked, total)
    }

    // MARK: - 查表

    private static func localized(_ key: String) -> String {
        NSLocalizedString(key, tableName: table, bundle: .main, value: "", comment: "")
    }

    #if DEBUG
    /// 本类型会解析的全部 key。测试用它逐条核对表里确实有对应条目——
    /// 拼错的 key 会原样显示成 key 本身，在英文下看着还算像话，其他语言下就露馅。
    static var allKeys: [String] {
        var keys = [
            "achievements.title",
            "achievements.unlocked",
            "achievements.locked",
            "achievements.empty",
            "achievements.progressCount",
            "result.newAchievements",
        ]
        for achievement in Achievement.all {
            keys.append(achievement.titleKey)
            keys.append(achievement.detailKey)
        }
        return keys
    }
    #endif
}
