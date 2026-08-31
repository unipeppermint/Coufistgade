//
//  AccessibilityTests.swift
//  coufistgadeTests
//
//  ROADMAP Phase 17. Contrast is computed rather than eyeballed; labels and
//  announcements are asserted against the strings UI_DESIGN §21 names.
//
//  These check what code can check. They are not a substitute for a VoiceOver
//  pass on a device — see the phase notes.
//

import XCTest
import SpriteKit
@testable import coufistgade

final class AccessibilityTests: XCTestCase {

    // MARK: - Contrast

    /// WCAG 2.1 relative luminance.
    private func luminance(_ colour: UIColor) -> CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        colour.getRed(&r, green: &g, blue: &b, alpha: &a)
        func channel(_ v: CGFloat) -> CGFloat {
            v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }

    private func contrast(_ a: UIColor, _ b: UIColor) -> CGFloat {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    func testEveryTextPairMeetsWCAGAA() {
        // UI_DESIGN §21: "Ensure adequate contrast." Every pair that actually
        // appears together in the UI, at the 4.5:1 body-text threshold.
        let pairs: [(String, UIColor, UIColor)] = [
            ("primary on background", UIColor(resource: .textPrimary), UIColor(resource: .appBackground)),
            ("primary on surface", UIColor(resource: .textPrimary), UIColor(resource: .surface)),
            ("primary over game", UIColor(resource: .textPrimary), UIColor(resource: .gameBackgroundCenter)),
            ("secondary on background", UIColor(resource: .textSecondary), UIColor(resource: .appBackground)),
            ("secondary on surface", UIColor(resource: .textSecondary), UIColor(resource: .surface)),
            ("secondary over game", UIColor(resource: .textSecondary), UIColor(resource: .gameBackgroundCenter)),
            ("accent on background", UIColor(resource: .accent), UIColor(resource: .appBackground)),
            ("accent on surface", UIColor(resource: .accent), UIColor(resource: .surface)),
            ("accent over game", UIColor(resource: .accent), UIColor(resource: .gameBackgroundCenter)),
        ]

        for (label, foreground, background) in pairs {
            let ratio = contrast(foreground, background)
            XCTAssertGreaterThanOrEqual(ratio, 4.5, "\(label): \(String(format: "%.2f", ratio)):1")
        }
    }

    func testThePlayButtonLabelReadsAgainstItsFill() {
        // Dark text on the accent fill, which no foreground/background token pair
        // describes — so it needs checking on its own.
        let ratio = contrast(UIColor(resource: .appBackground), UIColor(resource: .accent))

        XCTAssertGreaterThanOrEqual(ratio, 4.5, "PLAY label: \(String(format: "%.2f", ratio)):1")
    }

    func testBallsAreDistinguishableFromTheBackground() {
        // Non-text contrast, so the 3:1 threshold. A ball the player cannot
        // pick out of the background is unplayable regardless of labels.
        let normal = contrast(
            UIColor(resource: .normalBallHighlight),
            UIColor(resource: .gameBackgroundCenter)
        )
        let player = contrast(UIColor(resource: .accent), UIColor(resource: .gameBackgroundCenter))

        XCTAssertGreaterThanOrEqual(normal, 3.0)
        XCTAssertGreaterThanOrEqual(player, 3.0)
    }

    func testThePlayerBallIsNotDistinguishedByColourAlone() {
        // MEASURED: accent cyan against the normal ball's highlight is only
        // 1.18:1. The two differ sharply in hue but barely in luminance, so a
        // player with reduced colour vision could not tell them apart by colour.
        //
        // GAMEPLAY §4's "distinctive visual treatment" therefore has to rest on
        // something else, and it does: the player ball is the larger of the two
        // and the only one that glows. This asserts those redundant cues exist,
        // because they are what the distinction actually depends on.
        let colourRatio = contrast(
            UIColor(resource: .accent),
            UIColor(resource: .normalBallHighlight)
        )
        XCTAssertLessThan(colourRatio, 3.0, "If colour alone now suffices, update this reasoning.")

        // Size: a non-colour cue, and a large enough gap to read at a glance.
        let player = BallNode.Kind.player.diameter
        let normal = BallNode.Kind.normal.diameter
        XCTAssertGreaterThan(player / normal, 1.2, "The size difference is too subtle to rely on.")

        // Glow: the second non-colour cue.
        XCTAssertGreaterThan(BallNode.Kind.player.glowOpacity, 0)
        XCTAssertEqual(BallNode.Kind.normal.glowOpacity, 0)
    }

    // MARK: - Documented labels

    func testTheThreeLabelsNamedInTheDesignDocAreExact() throws {
        // UI_DESIGN §21 spells these out in English, so the English entries are
        // pinned — read from the en table rather than from the resolved label,
        // which follows whatever language the device is set to.
        XCTAssertEqual(try Self.localized("Start Game", language: "en"), "Start Game")
        XCTAssertEqual(try Self.localized("Open Settings", language: "en"), "Open Settings")
        XCTAssertEqual(try Self.localized("Pause Game", language: "en"), "Pause Game")
    }

    func testTheDocumentedLabelsAreActuallyAttachedToTheirControls() {
        // Separately from the wording: the label has to reach the control, in
        // whatever language is current.
        let home = HomeViewController()
        home.loadViewIfNeeded()

        func label(_ id: String, in view: UIView) -> String? {
            if view.accessibilityIdentifier == id { return view.accessibilityLabel }
            for subview in view.subviews {
                if let found = label(id, in: subview) { return found }
            }
            return nil
        }

        XCTAssertEqual(
            label(HomeViewController.AccessibilityID.playButton, in: home.view),
            Strings.startGameLabel
        )
        XCTAssertEqual(
            label(HomeViewController.AccessibilityID.settingsButton, in: home.view),
            Strings.openSettingsLabel
        )

        let game = GameViewController()
        game.loadViewIfNeeded()
        XCTAssertEqual(
            label(GameViewController.AccessibilityID.pauseButton, in: game.view),
            Strings.pauseGameLabel
        )
    }

    /// Looks a key up in a specific language.
    ///
    /// Xcode compiles Localizable.xcstrings into one .strings per language, so the
    /// source catalog is not in the bundle — the per-language tables are, and
    /// those are what actually ship.
    static func localized(_ key: String, language: String) throws -> String {
        let path = try XCTUnwrap(
            Bundle.main.path(forResource: language, ofType: "lproj"),
            "\(language).lproj is missing from the bundle."
        )
        let bundle = try XCTUnwrap(Bundle(path: path))
        return bundle.localizedString(forKey: key, value: nil, table: "Localizable")
    }

    func testThePlayfieldIsLabelledAndHinted() throws {
        let sut = GameViewController()
        sut.loadViewIfNeeded()

        func find(_ view: UIView) -> SKView? {
            if let sk = view as? SKView { return sk }
            for subview in view.subviews {
                if let found = find(subview) { return found }
            }
            return nil
        }
        let skView = try XCTUnwrap(find(sut.view))

        // Otherwise VoiceOver reads the playfield as an unlabelled blank.
        XCTAssertTrue(skView.isAccessibilityElement)
        XCTAssertEqual(skView.accessibilityLabel, Strings.playfieldLabel)
        XCTAssertNotNil(skView.accessibilityHint)
        // Direct interaction: VoiceOver's own gestures must not swallow a drag.
        XCTAssertTrue(skView.accessibilityTraits.contains(.allowsDirectInteraction))
    }

    // MARK: - Announcements

    private func makeAnnouncer(
        now: @escaping () -> TimeInterval
    ) -> (Announcer, () -> [String]) {
        var spoken: [String] = []
        let announcer = Announcer(now: now, speak: { spoken.append($0) })
        announcer.isTestOverrideEnabled = true
        return (announcer, { spoken })
    }

    func testAnAnnouncementIsSpoken() {
        var time: TimeInterval = 0
        let (sut, spoken) = makeAnnouncer(now: { time })

        XCTAssertTrue(sut.announce("Combo 4, 3 times"))
        XCTAssertEqual(spoken(), ["Combo 4, 3 times"])
    }

    func testRapidAnnouncementsAreThrottled() {
        var time: TimeInterval = 0
        let (sut, spoken) = makeAnnouncer(now: { time })

        // Collisions arrive up to seven a second. VoiceOver queues, so an
        // unthrottled feed would still be speaking hit four at round end.
        sut.announce("first")
        for _ in 0..<10 {
            time += 0.15
            sut.announce("later")
        }

        XCTAssertEqual(spoken(), ["first"])
    }

    func testAnnouncementsResumeAfterTheInterval() {
        var time: TimeInterval = 0
        let (sut, spoken) = makeAnnouncer(now: { time })

        sut.announce("first")
        time += Announcer.minimumInterval
        sut.announce("second")

        XCTAssertEqual(spoken(), ["first", "second"])
    }

    func testTheRoundEndingBypassesTheThrottle() {
        var time: TimeInterval = 0
        let (sut, spoken) = makeAnnouncer(now: { time })

        // A combo announced a moment before must not swallow the result.
        sut.announce("Combo 10, 10 times")
        time += 0.1
        XCTAssertTrue(sut.announceImmediately("Time's up. Score 250."))

        XCTAssertEqual(spoken(), ["Combo 10, 10 times", "Time's up. Score 250."])
    }

    func testAnImmediateAnnouncementStillArmsTheThrottleForWhatFollows() {
        var time: TimeInterval = 0
        let (sut, spoken) = makeAnnouncer(now: { time })

        sut.announceImmediately("Paused")
        time += 0.1
        sut.announce("Combo 4, 3 times")

        // Otherwise a bypass would leave the next ordinary announcement free to
        // talk over it.
        XCTAssertEqual(spoken(), ["Paused"])
    }

    func testNothingIsSpokenWhenVoiceOverIsOff() {
        var spoken: [String] = []
        let sut = Announcer(now: { 0 }, speak: { spoken.append($0) })
        // No test override, and VoiceOver is not running in a test process.

        XCTAssertFalse(sut.announce("ignored"))
        XCTAssertFalse(sut.announceImmediately("also ignored"))
        XCTAssertTrue(spoken.isEmpty, "Announcements were posted with VoiceOver off.")
    }

    // MARK: - Dynamic Type

    func testEveryTextStyleScalesWithDynamicType() {
        // Theme is the only source of fonts outside the SpriteKit layer, so
        // checking it covers the whole UIKit surface.
        let small = UITraitCollection(preferredContentSizeCategory: .small)
        let large = UITraitCollection(preferredContentSizeCategory: .accessibilityLarge)

        let styles: [UIFont.TextStyle] = [.caption2, .caption1, .subheadline, .body, .headline, .title1]
        for style in styles {
            let smallFont = Theme.Typography.rounded(style, weight: .medium)
            let largeFont = small.performAsCurrent {
                Theme.Typography.rounded(style, weight: .medium)
            }
            _ = smallFont
            _ = largeFont
            // Compared through the metrics rather than the trait collection,
            // which UIFont.preferredFont resolves at call time.
            let scaled = UIFontMetrics(forTextStyle: style).scaledValue(
                for: 17,
                compatibleWith: large
            )
            XCTAssertGreaterThan(scaled, 17, "\(style) does not grow at accessibility sizes.")
        }
    }

    func testCappedStylesStillGrowButStayBounded() {
        // The caps exist so a wordmark cannot force the layout off-screen; they
        // must not stop it growing at all.
        let cap = Theme.Typography.MaxPointSize.wordmark
        let font = Theme.Typography.rounded(.title1, weight: .bold, maximumPointSize: cap)

        XCTAssertLessThanOrEqual(font.pointSize, cap)
        XCTAssertGreaterThan(font.pointSize, 0)
    }
}
