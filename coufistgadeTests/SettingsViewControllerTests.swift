//
//  SettingsViewControllerTests.swift
//  coufistgadeTests
//

import XCTest
@testable import coufistgade

final class SettingsViewControllerTests: XCTestCase {

    private func makeSUT(
        _ store: PersistenceManager? = nil
    ) -> (SettingsViewController, PersistenceManager) {
        let store = store ?? PersistenceManager(
            defaults: UserDefaults(suiteName: "bouncy.tests.\(UUID().uuidString)")!
        )
        let sut = SettingsViewController(store: store)
        sut.loadViewIfNeeded()
        sut.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        sut.view.layoutIfNeeded()
        return (sut, store)
    }

    private func table(in sut: SettingsViewController) -> UITableView? {
        func search(_ view: UIView) -> UITableView? {
            if let table = view as? UITableView { return table }
            for subview in view.subviews {
                if let found = search(subview) { return found }
            }
            return nil
        }
        return search(sut.view)
    }

    private func toggle(
        for setting: SettingsViewController.Setting,
        in sut: SettingsViewController
    ) -> UISwitch? {
        guard let table = table(in: sut),
              let section = SettingsViewController.Setting.allCases.firstIndex(of: setting)
        else { return nil }
        let path = IndexPath(row: 0, section: section)
        // The live cell, not a freshly dequeued one: asking the data source
        // directly returns a cell whose closure prepareForReuse has since
        // cleared, so flipping its switch would write nowhere.
        table.layoutIfNeeded()
        let cell = table.cellForRow(at: path)
            ?? table.dataSource?.tableView(table, cellForRowAt: path)
        let id = SettingsViewController.AccessibilityID.toggle(setting)

        func search(_ view: UIView?) -> UISwitch? {
            guard let view else { return nil }
            if let found = view as? UISwitch, found.accessibilityIdentifier == id { return found }
            for subview in view.subviews {
                if let found = search(subview) { return found }
            }
            return nil
        }
        return search(cell?.accessoryView) ?? search(cell)
    }

    // MARK: - Contents

    func testShowsExactlyTheThreeFunctionalOptions() {
        // UI_DESIGN §15 lists four; Music is deliberately absent because no music
        // exists to toggle. See the note on SettingsViewController.Setting.
        XCTAssertEqual(
            SettingsViewController.Setting.allCases.map(\.title),
            [Strings.sound, Strings.haptics, Strings.reduceMotion]
        )
    }

    func testNoRowIsAnInertSwitch() throws {
        // The reason Music went away: a switch that stores a preference nothing
        // reads is a non-functional control, which App Review 2.1 treats as an
        // unfinished app. Every row left must drive something real.
        let (sut, store) = makeSUT()

        for setting in SettingsViewController.Setting.allCases {
            let toggle = try XCTUnwrap(toggle(for: setting, in: sut))
            let before = isStored(setting, in: store)
            toggle.isOn = !before
            toggle.sendActions(for: .valueChanged)

            XCTAssertNotEqual(
                isStored(setting, in: store),
                before,
                "\(setting.title) does not write anything."
            )
        }
    }

    private func isStored(_ setting: SettingsViewController.Setting, in store: PersistenceManager) -> Bool {
        switch setting {
        case .sound: store.soundEnabled
        case .haptics: store.hapticsEnabled
        case .reduceMotion: store.reduceMotionEnabled
        }
    }

    func testEveryOptionHasARowWithASwitch() {
        let (sut, _) = makeSUT()

        for setting in SettingsViewController.Setting.allCases {
            XCTAssertNotNil(toggle(for: setting, in: sut), "\(setting.title) has no switch.")
        }
    }

    // MARK: - Reading stored values

    func testSwitchesReflectStoredValuesOnOpen() throws {
        let suite = UserDefaults(suiteName: "bouncy.tests.\(UUID().uuidString)")!
        let store = PersistenceManager(defaults: suite)
        store.soundEnabled = false
        store.hapticsEnabled = true

        let (sut, _) = makeSUT(store)

        XCTAssertEqual(try XCTUnwrap(toggle(for: .sound, in: sut)).isOn, false)
        XCTAssertEqual(try XCTUnwrap(toggle(for: .haptics, in: sut)).isOn, true)
    }

    func testAFreshInstallShowsSoundAndHapticsOn() throws {
        let (sut, _) = makeSUT()

        // The registered defaults, surfaced. A screen full of off switches on
        // first open would look broken.
        XCTAssertTrue(try XCTUnwrap(toggle(for: .sound, in: sut)).isOn)
        XCTAssertTrue(try XCTUnwrap(toggle(for: .haptics, in: sut)).isOn)
        XCTAssertFalse(try XCTUnwrap(toggle(for: .reduceMotion, in: sut)).isOn)
    }

    // MARK: - Writing

    func testFlippingASwitchWritesImmediately() throws {
        let (sut, store) = makeSUT()
        let sound = try XCTUnwrap(toggle(for: .sound, in: sut))

        sound.isOn = false
        sound.sendActions(for: .valueChanged)

        // No Save button, so the write has to happen here or not at all.
        XCTAssertFalse(store.soundEnabled)
    }

    func testEachSwitchWritesOnlyItsOwnSetting() throws {
        let (sut, store) = makeSUT()

        let haptics = try XCTUnwrap(toggle(for: .haptics, in: sut))
        haptics.isOn = false
        haptics.sendActions(for: .valueChanged)

        XCTAssertFalse(store.hapticsEnabled)
        XCTAssertTrue(store.soundEnabled, "Flipping Haptics changed Sound.")
        XCTAssertFalse(store.reduceMotionEnabled)
    }

    func testASettingCanBeTurnedBackOn() throws {
        let (sut, store) = makeSUT()
        let sound = try XCTUnwrap(toggle(for: .sound, in: sut))

        sound.isOn = false
        sound.sendActions(for: .valueChanged)
        sound.isOn = true
        sound.sendActions(for: .valueChanged)

        XCTAssertTrue(store.soundEnabled)
    }

    func testReduceMotionWrittenHereReachesMotionPreference() throws {
        let suite = UserDefaults(suiteName: "bouncy.tests.\(UUID().uuidString)")!
        let store = PersistenceManager(defaults: suite)
        let (sut, _) = makeSUT(store)
        let original = MotionPreference.storedPreference
        MotionPreference.storedPreference = { store.reduceMotionEnabled }
        defer { MotionPreference.storedPreference = original }

        let toggleView = try XCTUnwrap(toggle(for: .reduceMotion, in: sut))
        toggleView.isOn = true
        toggleView.sendActions(for: .valueChanged)

        // The switch is only real if the merge picks it up.
        XCTAssertTrue(MotionPreference.isReduced)
    }

    // MARK: - Accessibility

    func testEverySwitchIsLabelled() throws {
        let (sut, _) = makeSUT()

        for setting in SettingsViewController.Setting.allCases {
            // A bare switch announces "on" without saying what of.
            XCTAssertEqual(
                try XCTUnwrap(toggle(for: setting, in: sut)).accessibilityLabel,
                setting.title
            )
        }
    }

    func testTheCloseButtonIsLabelledAndMeetsTheTouchTarget() throws {
        let (sut, _) = makeSUT()

        func search(_ view: UIView) -> UIView? {
            if view.accessibilityIdentifier == SettingsViewController.AccessibilityID.closeButton {
                return view
            }
            for subview in view.subviews {
                if let found = search(subview) { return found }
            }
            return nil
        }
        let close = try XCTUnwrap(search(sut.view))

        XCTAssertEqual(close.accessibilityLabel, Strings.closeSettingsLabel)
        XCTAssertGreaterThanOrEqual(close.bounds.height, Theme.Layout.minimumTouchTarget)
    }

    func testRowsAreNotSelectableSinceTheSwitchIsTheControl() {
        let (sut, _) = makeSUT()

        XCTAssertEqual(table(in: sut)?.allowsSelection, false)
    }

    // MARK: - Navigation

    func testHomeCanReachSettingsAndComeBack() {
        let home = HomeViewController()
        let nav = UINavigationController(rootViewController: home)
        home.loadViewIfNeeded()

        nav.pushViewController(SettingsViewController(), animated: false)
        XCTAssertTrue(nav.topViewController is SettingsViewController)

        nav.popViewController(animated: false)
        XCTAssertTrue(nav.topViewController is HomeViewController, "The player must not be trapped.")
    }
}
