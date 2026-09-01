//
//  LocalizationTests.swift
//  coufistgadeTests
//
//  ROADMAP Phase 18. The app ships English only.
//
//  Simplified Chinese was removed, and with it the checks that compared two
//  languages against each other — a format specifier that differs between
//  languages was the failure worth guarding, and there is no second language to
//  differ from. What remains guards the English catalog itself: every key the app
//  asks for exists, nothing is stranded in the catalog unused, and multi-argument
//  formats stay positional so a translation can be added later without reopening
//  every string.
//
//  Note the limit of a single-language catalog: for English the value equals the
//  key, so "the key resolved" and "the key is missing" look identical. Presence is
//  therefore proven from the compiled catalog, not from the returned string.
//

import XCTest
@testable import coufistgade

final class LocalizationTests: XCTestCase {

    private func englishBundle() throws -> Bundle {
        let path = try XCTUnwrap(
            Bundle.main.path(forResource: "en", ofType: "lproj"),
            "en.lproj is missing — the language is not shipping."
        )
        return try XCTUnwrap(Bundle(path: path))
    }

    private func value(_ key: String) throws -> String {
        try englishBundle().localizedString(forKey: key, value: nil, table: "Localizable")
    }

    /// The compiled English table, or nil on toolchains that emit binary .strings.
    private func compiledTable() throws -> [String: String]? {
        let bundle = try englishBundle()
        guard let url = bundle.url(forResource: "Localizable", withExtension: "strings"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(
                  from: data, options: [], format: nil
              ) as? [String: String]
        else { return nil }
        return plist
    }

    /// Format specifiers in order of appearance, positional index stripped.
    private func specifiers(of format: String) -> [String] {
        var found: [String] = []
        var rest = Substring(format)
        while let percent = rest.firstIndex(of: "%") {
            var cursor = rest.index(after: percent)
            guard cursor < rest.endIndex else { break }
            if rest[cursor] == "%" {  // escaped literal
                rest = rest[rest.index(after: cursor)...]
                continue
            }
            var token = ""
            // Skip a positional prefix like "2$" — reordering is legitimate.
            var digits = ""
            while cursor < rest.endIndex, rest[cursor].isNumber {
                digits.append(rest[cursor])
                cursor = rest.index(after: cursor)
            }
            if cursor < rest.endIndex, rest[cursor] == "$" {
                cursor = rest.index(after: cursor)
            } else {
                token += digits  // width, not a position
            }
            while cursor < rest.endIndex {
                let character = rest[cursor]
                token.append(character)
                cursor = rest.index(after: cursor)
                if character.isLetter { break }
            }
            found.append(token)
            rest = rest[cursor...]
        }
        return found
    }

    // MARK: - The language ships

    func testEnglishIsInTheBundle() throws {
        XCTAssertNoThrow(try englishBundle(), "en is not shipping.")
    }

    func testNoOtherLanguageIsBundled() throws {
        // Chinese was removed. A stale .lproj left in the product would still be
        // offered by iOS on a zh device, showing a half-translated app.
        let others = try XCTUnwrap(
            Bundle.main.paths(forResourcesOfType: "lproj", inDirectory: nil) as [String]?
        )
        .map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent }
        .filter { $0 != "en" && $0 != "Base" }

        XCTAssertTrue(others.isEmpty, "Unexpected localisations still bundled: \(others.sorted())")
    }

    // MARK: - Coverage

    func testEveryKeyTheAppUsesExistsInTheCatalog() throws {
        // For English the value equals the key, so a missing entry cannot be seen
        // in what NSLocalizedString returns. The compiled table is the only place
        // absence is visible.
        guard let table = try compiledTable() else {
            throw XCTSkip("Binary .strings on this toolchain; coverage cannot be read.")
        }

        for key in Strings.allKeys {
            XCTAssertNotNil(table[key], "\"\(key)\" is not in the catalog.")
            XCTAssertFalse(
                (table[key] ?? "").isEmpty,
                "\"\(key)\" has an empty value."
            )
        }
    }

    func testTheCatalogHasNoKeysTheAppNeverUses() throws {
        // Dead entries are how a catalog drifts: a renamed key leaves the old one
        // behind, and nothing points at it.
        guard let table = try compiledTable() else {
            throw XCTSkip("Binary .strings on this toolchain; coverage cannot be read.")
        }

        let unused = Set(table.keys).subtracting(Set(Strings.allKeys))
        XCTAssertTrue(unused.isEmpty, "Catalog keys nothing uses: \(unused.sorted())")
    }

    // MARK: - Format safety

    func testMultiArgumentStringsUsePositionalSpecifiers() throws {
        // Two bare %lld cannot be reordered. Nothing needs reordering while English
        // is the only language, but a translation added later would be stuck with
        // English word order — so the requirement stays.
        for key in Strings.allKeys {
            let format = try value(key)
            guard specifiers(of: format).count > 1 else { continue }
            XCTAssertTrue(
                format.contains("$"),
                "\"\(key)\" takes several arguments but is not positional."
            )
        }
    }

    // MARK: - Rendering

    func testInterpolatedStringsRenderTheirValues() throws {
        // Proves the specifiers actually consume the arguments, which inspecting
        // the format string cannot.
        let bundle = try englishBundle()

        let score = String(
            format: bundle.localizedString(forKey: "Score %lld", value: nil, table: "Localizable"),
            locale: Locale(identifier: "en"),
            250
        )
        XCTAssertTrue(score.contains("250"), "Score not rendered — \(score)")

        let combo = String(
            format: bundle.localizedString(
                forKey: "Combo %1$lld, %2$lld times",
                value: nil,
                table: "Localizable"
            ),
            locale: Locale(identifier: "en"),
            7, 5
        )
        XCTAssertTrue(combo.contains("7"), "Combo count not rendered — \(combo)")
        XCTAssertTrue(combo.contains("5"), "Multiplier not rendered — \(combo)")
    }

    // MARK: - Accessors

    func testEveryAccessorReturnsSomething() {
        let resolved: [String] = [
            Strings.bestCaption, Strings.play, Strings.startGameLabel,
            Strings.openSettingsLabel, Strings.scoreCaption, Strings.pauseGameLabel,
            Strings.playfieldLabel, Strings.playfieldHint, Strings.paused,
            Strings.resume, Strings.quit, Strings.newRecord,
            Strings.comboCaptionPlain, Strings.bestComboCaption, Strings.playAgain,
            Strings.home, Strings.settings, Strings.closeSettingsLabel,
            Strings.sound, Strings.haptics, Strings.reduceMotion,
            Strings.hapticsFooter, Strings.reduceMotionFooter,
        ]

        for string in resolved {
            XCTAssertFalse(string.isEmpty)
        }
        // Whether each accessor's key is actually in the catalog is proven by
        // testEveryKeyTheAppUsesExistsInTheCatalog; this only guards the list.
        XCTAssertEqual(Set(Strings.allKeys).count, Strings.allKeys.count, "Duplicate keys.")
    }

    func testTheWordmarkIsNotLocalised() {
        // UI_DESIGN §4: BOUNCY is the product's name. A wordmark is not
        // translated, so it must not appear in the catalog at all.
        XCTAssertFalse(Strings.allKeys.contains("BOUNCY"))
    }
}
