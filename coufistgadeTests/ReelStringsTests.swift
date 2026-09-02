//
//  ReelStringsTests.swift
//  coufistgadeTests
//
//  转轴文案在 Reels.xcstrings 里，独立于主表。查表方式与覆盖率的验证方式都和
//  AchievementTrackerTests 里那两条一致——拼错的 key 会原样显示成 key 本身，
//  在英文下看着还算像话，所以必须去编译产物里查，而不是看返回值。
//

import XCTest
@testable import coufistgade

final class ReelStringsTests: XCTestCase {

    func testEveryDeclaredKeyResolves() {
        for key in ReelStrings.allKeys {
            let value = NSLocalizedString(
                key, tableName: "Reels", bundle: .main, value: "", comment: ""
            )
            XCTAssertFalse(value.isEmpty, "\(key) 不在 Reels 表里")
            XCTAssertNotEqual(value, key, "\(key) 原样返回，说明查表失败")
        }
    }

    func testEnglishCarriesEveryReelString() throws {
        let path = try XCTUnwrap(
            Bundle.main.path(forResource: "en", ofType: "lproj"),
            "en.lproj 不在 bundle 里"
        )
        let bundle = try XCTUnwrap(Bundle(path: path))

        guard let url = bundle.url(forResource: "Reels", withExtension: "strings"),
              let data = try? Data(contentsOf: url),
              let table = try? PropertyListSerialization.propertyList(
                  from: data, options: [], format: nil
              ) as? [String: String]
        else {
            throw XCTSkip("这个工具链输出的是二进制 .strings，读不到条目")
        }

        for key in ReelStrings.allKeys {
            XCTAssertNotNil(table[key], "Reels 表里没有 \(key)")
        }
    }

    func testTheTableHasNoKeysNothingUses() throws {
        // 死条目是表走样的方式：改名会留下旧的那条，而没有任何东西指向它。
        let path = try XCTUnwrap(Bundle.main.path(forResource: "en", ofType: "lproj"))
        let bundle = try XCTUnwrap(Bundle(path: path))

        guard let url = bundle.url(forResource: "Reels", withExtension: "strings"),
              let data = try? Data(contentsOf: url),
              let table = try? PropertyListSerialization.propertyList(
                  from: data, options: [], format: nil
              ) as? [String: String]
        else {
            throw XCTSkip("这个工具链输出的是二进制 .strings，读不到条目")
        }

        let unused = Set(table.keys).subtracting(Set(ReelStrings.allKeys))
        XCTAssertTrue(unused.isEmpty, "没有任何东西用到的条目：\(unused.sorted())")
    }

    func testNoDuplicateKeys() {
        XCTAssertEqual(
            Set(ReelStrings.allKeys).count,
            ReelStrings.allKeys.count,
            "allKeys 里有重复"
        )
    }

    // MARK: - 每个符号与维度都有文案

    func testEverySymbolHasAName() {
        // 无障碍标签要读出符号名。缺一条就会读出 "reel.symbol.star" 这种东西。
        for symbol in ReelSymbol.allCases {
            let name = ReelStrings.symbolName(symbol)
            XCTAssertFalse(name.isEmpty, "\(symbol) 没有名字")
            XCTAssertNotEqual(name, symbol.localizationKey, "\(symbol) 的名字未翻译")
        }
    }

    func testEverySymbolHasAGlyph() {
        for symbol in ReelSymbol.allCases {
            XCTAssertFalse(symbol.glyph.isEmpty, "\(symbol) 没有字形")
        }
    }

    func testEverySymbolGlyphIsDistinct() {
        // 两个档位显示同一个字形，玩家就分不出成线没成线。
        let glyphs = ReelSymbol.allCases.map(\.glyph)
        XCTAssertEqual(Set(glyphs).count, glyphs.count, "有重复的字形：\(glyphs)")
    }

    func testEveryDimensionHasACaption() {
        for dimension in ReelDimension.allCases {
            let caption = ReelStrings.dimensionCaption(dimension)
            XCTAssertFalse(caption.isEmpty, "\(dimension) 没有标题")
            XCTAssertNotEqual(caption, dimension.localizationKey, "\(dimension) 的标题未翻译")
        }
    }

    // MARK: - 插值

    func testTheBonusValueRendersItsNumber() {
        let rendered = ReelStrings.bonusValue(150)
        XCTAssertTrue(rendered.contains("150"), "奖励分没渲染出来 — \(rendered)")
    }

    func testTheLineCaptionRendersTheSymbolName() {
        let rendered = ReelStrings.lineCaption(.seven)
        // 比较时两边都大写：成线文案整句是大写的（见 ReelStrings.lineCaption 的
        // 说明），而符号名在表里是 "Seven" 这样的自然写法。
        XCTAssertTrue(
            rendered.contains(ReelStrings.symbolName(.seven).localizedUppercase),
            "成线文案没带上符号名 — \(rendered)"
        )
    }

    func testTheLineCaptionIsAllCaps() {
        // 这一页所有说明性标签都是全大写（SCORE、BEST、COMBO、HITS、CHAIN）。
        // 「Star LINE」这种混合大小写在模拟器上一眼就看得出是漏了处理。
        for symbol in ReelSymbol.allCases {
            let rendered = ReelStrings.lineCaption(symbol)
            XCTAssertEqual(
                rendered,
                rendered.localizedUppercase,
                "\(symbol) 的成线文案不是全大写 — \(rendered)"
            )
        }
    }

    func testTheSlotLabelRendersBothTheValueAndTheSymbol() {
        let slot = ReelSlot(dimension: .hits, symbol: .star, value: 17)
        let rendered = ReelStrings.slotLabel(slot)

        XCTAssertTrue(rendered.contains("17"), "没带上数值 — \(rendered)")
        XCTAssertTrue(
            rendered.contains(ReelStrings.symbolName(.star)),
            "没带上符号名 — \(rendered)"
        )
        XCTAssertTrue(
            rendered.contains(ReelStrings.dimensionCaption(.hits)),
            "没带上维度名 — \(rendered)"
        )
    }

    func testTheLineAnnouncementRendersBothArguments() {
        let rendered = ReelStrings.lineAnnouncement(symbol: .star, bonus: 150)

        XCTAssertTrue(rendered.contains("150"), "没带上奖励分 — \(rendered)")
        XCTAssertTrue(
            rendered.contains(ReelStrings.symbolName(.star)),
            "没带上符号名 — \(rendered)"
        )
    }

    func testMultiArgumentFormatsArePositional() throws {
        // 两个裸 %lld 无法重排，翻译时会被迫沿用英文语序。现在只有英文，但要求保留。
        let path = try XCTUnwrap(Bundle.main.path(forResource: "en", ofType: "lproj"))
        let bundle = try XCTUnwrap(Bundle(path: path))

        for key in ["reel.slotLabel", "reel.lineAnnouncement"] {
            let format = bundle.localizedString(forKey: key, value: nil, table: "Reels")
            XCTAssertTrue(format.contains("$"), "\(key) 收多个参数但不是位置式的")
        }
    }
}
