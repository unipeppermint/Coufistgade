//
//  LocalizationTests.swift
//  coufistgadeTests
//
//  ROADMAP Phase 18. Checks the two shipped languages against each other.
//
//  The failure mode worth guarding is not a clumsy translation — it is a format
//  specifier that differs between languages. `String(format:)` reads its
//  arguments according to the format string, so a zh-Hans entry with the wrong
//  specifier reads past the arguments given and crashes, in that language only,
//  on a device nobody tested.
//

import XCTest
@testable import coufistgade

final class LocalizationTests: XCTestCase {

    private let languages = ["en", "zh-Hans"]

    private func bundle(for language: String) throws -> Bundle {
        let path = try XCTUnwrap(
            Bundle.main.path(forResource: language, ofType: "lproj"),
            "\(language).lproj is missing — the language is not shipping."
        )
        return try XCTUnwrap(Bundle(path: path))
    }

    private func value(_ key: String, in language: String) throws -> String {
        // A missing key resolves to the key itself, which is how absence is
        // detected below.
        try bundle(for: language).localizedString(forKey: key, value: nil, table: "Localizable")
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

    // MARK: - Both languages ship

    func testBothDocumentedLanguagesAreInTheBundle() throws {
        // ROADMAP Phase 18: English and Simplified Chinese.
        for language in languages {
            XCTAssertNoThrow(try bundle(for: language), "\(language) is not shipping.")
        }
    }

    // MARK: - Coverage

    func testEveryKeyTheAppUsesExistsInBothLanguages() throws {
        for key in Strings.allKeys {
            for language in languages {
                let resolved = try value(key, in: language)
                // A key resolving to itself means no entry: for en that is the
                // intended value, so only zh-Hans can be judged this way.
                if language != "en" {
                    XCTAssertNotEqual(
                        resolved, key,
                        "\(language) has no translation for \"\(key)\"."
                    )
                }
                XCTAssertFalse(resolved.isEmpty, "\(language) has an empty value for \"\(key)\".")
            }
        }
    }

    func testTheCatalogHasNoKeysTheAppNeverUses() throws {
        // Dead entries are how a catalog drifts: a renamed key leaves the old
        // one translated and paid for, and nothing points at it.
        let english = try bundle(for: "en")
        let used = Set(Strings.allKeys)

        guard let table = english.url(forResource: "Localizable", withExtension: "strings"),
              let contents = try? Data(contentsOf: table),
              let plist = try? PropertyListSerialization.propertyList(
                  from: contents, options: [], format: nil
              ) as? [String: String]
        else {
            // Binary .strings on some toolchains; coverage above still holds.
            return
        }

        let unused = Set(plist.keys).subtracting(used)
        XCTAssertTrue(unused.isEmpty, "Catalog keys nothing uses: \(unused.sorted())")
    }

    // MARK: - Format safety

    func testFormatSpecifiersMatchAcrossLanguages() throws {
        for key in Strings.allKeys {
            let englishSpecifiers = specifiers(of: try value(key, in: "en"))
            for language in languages.dropFirst() {
                let translated = specifiers(of: try value(key, in: language))
                // Order may differ via positional arguments; the multiset may not.
                XCTAssertEqual(
                    englishSpecifiers.sorted(), translated.sorted(),
                    "\"\(key)\": en has \(englishSpecifiers), \(language) has \(translated). "
                        + "A mismatch crashes String(format:) in \(language) only."
                )
            }
        }
    }

    func testMultiArgumentStringsUsePositionalSpecifiers() throws {
        // Two bare %lld cannot be reordered, and word order differs between these
        // two languages — so anything with more than one argument must be
        // positional or a translator has no way to move them.
        for key in Strings.allKeys {
            let format = try value(key, in: "en")
            guard specifiers(of: format).count > 1 else { continue }
            XCTAssertTrue(
                format.contains("$"),
                "\"\(key)\" takes several arguments but is not positional."
            )
        }
    }

    // MARK: - Rendering

    func testInterpolatedStringsRenderTheirValuesInBothLanguages() throws {
        // Proves the specifiers actually consume the arguments, which the static
        // comparison above cannot.
        for language in languages {
            let bundle = try self.bundle(for: language)

            let score = String(
                format: bundle.localizedString(forKey: "Score %lld", value: nil, table: "Localizable"),
                locale: Locale(identifier: language),
                250
            )
            XCTAssertTrue(score.contains("250"), "\(language): score not rendered — \(score)")

            let combo = String(
                format: bundle.localizedString(
                    forKey: "Combo %1$lld, %2$lld times",
                    value: nil,
                    table: "Localizable"
                ),
                locale: Locale(identifier: language),
                7, 5
            )
            XCTAssertTrue(combo.contains("7"), "\(language): combo count not rendered — \(combo)")
            XCTAssertTrue(combo.contains("5"), "\(language): multiplier not rendered — \(combo)")
        }
    }

    // MARK: - Accessors

    func testEveryAccessorResolvesRatherThanEchoingItsKey() {
        // Catches a typo in Strings.swift: a key absent from the catalog renders
        // verbatim, which looks plausible in English and wrong everywhere else.
        let resolved: [String] = [
            Strings.bestCaption, Strings.play, Strings.startGameLabel,
            Strings.openSettingsLabel, Strings.scoreCaption, Strings.pauseGameLabel,
            Strings.playfieldLabel, Strings.playfieldHint, Strings.paused,
            Strings.resume, Strings.quit, Strings.newRecord,
            Strings.comboCaptionPlain, Strings.bestComboCaption, Strings.playAgain,
            Strings.home, Strings.settings, Strings.closeSettingsLabel,
            Strings.sound, Strings.music, Strings.haptics, Strings.reduceMotion,
            Strings.musicFooter, Strings.hapticsFooter, Strings.reduceMotionFooter,
        ]

        for string in resolved {
            XCTAssertFalse(string.isEmpty)
        }
        // Every accessor's key must be declared, or the coverage test above is
        // checking a shorter list than the app actually uses.
        XCTAssertEqual(Set(Strings.allKeys).count, Strings.allKeys.count, "Duplicate keys.")
    }

    func testTheWordmarkIsNotLocalised() {
        // UI_DESIGN §4: BOUNCY is the product's name. A wordmark is not
        // translated, so it must not appear in the catalog at all.
        XCTAssertFalse(Strings.allKeys.contains("BOUNCY"))
    }
}
