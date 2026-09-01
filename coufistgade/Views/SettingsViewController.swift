//
//  SettingsViewController.swift
//  coufistgade
//
//  Sound, Haptics, Reduce Motion (UI_DESIGN §15).
//
//  A grouped UITableView because §15 asks for native settings patterns: it gives
//  Dynamic Type, VoiceOver grouping, and the platform's own row metrics for
//  free, all of which a hand-built stack of switches would have to reimplement
//  and would get subtly wrong.
//
//  Writes straight through to PersistenceManager on each change. No Save button,
//  no staged edits — a settings screen that can be abandoned halfway is a state
//  machine nobody asked for.
//

import UIKit

final class SettingsViewController: UIViewController {

    enum AccessibilityID {
        static let table = "settings.table"
        static let closeButton = "settings.closeButton"
        static func toggle(_ setting: Setting) -> String { "settings.toggle.\(setting.rawValue)" }
    }

    /// The options, in the order §15 lists them.
    ///
    /// Music is absent deliberately. §15 lists it, but no music exists in the
    /// app, so the row was a switch that saved a preference and then did
    /// nothing — a non-functional control plus a "no music in this build"
    /// caption, which is exactly what App Review 2.1 (App Completeness) reads
    /// as an unfinished app. `PersistenceManager.musicEnabled` is still stored,
    /// so adding the row back costs one case when music actually ships.
    enum Setting: String, CaseIterable {
        case sound
        case haptics
        case reduceMotion

        var title: String {
            switch self {
            case .sound: Strings.sound
            case .haptics: Strings.haptics
            case .reduceMotion: Strings.reduceMotion
            }
        }

        /// Shown beneath the row. Only where the label alone would leave a real
        /// question — captioning "Sound" with "Plays sounds" is noise.
        var footer: String? {
            switch self {
            case .sound: nil
            case .haptics: Strings.hapticsFooter
            case .reduceMotion: Strings.reduceMotionFooter
            }
        }
    }

    private let store: PersistenceManager
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let titleLabel = UILabel()

    init(store: PersistenceManager = PersistenceManager()) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("SettingsViewController is code-only; this app uses no storyboards or nibs.")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = UIColor(resource: .appBackground)

        // The navigation bar is hidden app-wide, so this screen carries its own
        // heading and its own way out rather than turning the bar on for one
        // screen. `title` alone would render nowhere.
        titleLabel.text = Strings.settings
        titleLabel.font = Theme.Typography.rounded(
            .title1,
            weight: .bold,
            maximumPointSize: Theme.Typography.MaxPointSize.wordmark
        )
        titleLabel.textColor = UIColor(resource: .textPrimary)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.accessibilityTraits = .header
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(SettingToggleCell.self, forCellReuseIdentifier: SettingToggleCell.reuseID)
        // Rows contain a switch, so selection would only ever be misleading.
        tableView.allowsSelection = false
        tableView.accessibilityIdentifier = AccessibilityID.table

        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        let closeButton = UIButton(type: .system)
        var config = UIButton.Configuration.plain()
        config.image = UIImage(
            systemName: "xmark",
            withConfiguration: UIImage.SymbolConfiguration(
                pointSize: Theme.Layout.settingsIconPointSize
            )
        )
        config.baseForegroundColor = UIColor(resource: .textSecondary)
        config.contentInsets = .zero
        closeButton.configuration = config
        closeButton.backgroundColor = UIColor(resource: .surface)
        closeButton.layer.cornerRadius = Theme.Layout.minimumTouchTarget / 2
        closeButton.accessibilityIdentifier = AccessibilityID.closeButton
        closeButton.accessibilityLabel = Strings.closeSettingsLabel
        closeButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)
        self.closeButton = closeButton
    }

    private var closeButton: UIButton?

    private func setupConstraints() {
        let safe = view.safeAreaLayoutGuide
        guard let closeButton else { return }

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: safe.topAnchor, constant: Theme.Spacing.xs),
            closeButton.trailingAnchor.constraint(
                equalTo: safe.trailingAnchor,
                constant: -Theme.Spacing.m
            ),
            closeButton.widthAnchor.constraint(equalToConstant: Theme.Layout.minimumTouchTarget),
            closeButton.heightAnchor.constraint(equalToConstant: Theme.Layout.minimumTouchTarget),

            titleLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: Theme.Spacing.m),
            titleLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: closeButton.leadingAnchor,
                constant: -Theme.Spacing.xs
            ),

            tableView.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: Theme.Spacing.s),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Reading and writing

    private func isOn(_ setting: Setting) -> Bool {
        switch setting {
        case .sound: store.soundEnabled
        case .haptics: store.hapticsEnabled
        case .reduceMotion: store.reduceMotionEnabled
        }
    }

    private func set(_ setting: Setting, to isOn: Bool) {
        switch setting {
        case .sound: store.soundEnabled = isOn
        case .haptics: store.hapticsEnabled = isOn
        case .reduceMotion: store.reduceMotionEnabled = isOn
        }
    }

    // MARK: - Actions

    @objc private func handleClose() {
        navigationController?.popViewController(animated: true)
    }
}

// MARK: - UITableViewDataSource

extension SettingsViewController: UITableViewDataSource {

    /// One section per setting, so each can carry its own footer.
    func numberOfSections(in tableView: UITableView) -> Int {
        Setting.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }

    func tableView(
        _ tableView: UITableView,
        titleForFooterInSection section: Int
    ) -> String? {
        Setting.allCases[section].footer
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let setting = Setting.allCases[indexPath.section]
        let cell = tableView.dequeueReusableCell(
            withIdentifier: SettingToggleCell.reuseID,
            for: indexPath
        ) as? SettingToggleCell ?? SettingToggleCell(style: .default, reuseIdentifier: nil)

        cell.configure(
            title: setting.title,
            isOn: isOn(setting),
            accessibilityID: AccessibilityID.toggle(setting)
        ) { [weak self] isOn in
            self?.set(setting, to: isOn)
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension SettingsViewController: UITableViewDelegate {}

/// A title and a switch. Written rather than using UITableViewCell's accessory
/// view so the switch's value change has somewhere to go.
private final class SettingToggleCell: UITableViewCell {

    static let reuseID = "SettingToggleCell"

    private let toggle = UISwitch()
    private var onChange: ((Bool) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = UIColor(resource: .surface)
        textLabel?.textColor = UIColor(resource: .textPrimary)
        textLabel?.font = Theme.Typography.rounded(
            .body,
            weight: .medium,
            maximumPointSize: Theme.Typography.MaxPointSize.buttonLabel
        )
        textLabel?.adjustsFontForContentSizeCategory = true
        textLabel?.numberOfLines = 0

        toggle.onTintColor = UIColor(resource: .accent)
        toggle.addTarget(self, action: #selector(handleToggle), for: .valueChanged)
        accessoryView = toggle
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("SettingToggleCell is code-only.")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        // Cleared so a recycled cell cannot write to the setting it used to show.
        onChange = nil
    }

    func configure(
        title: String,
        isOn: Bool,
        accessibilityID: String,
        onChange: @escaping (Bool) -> Void
    ) {
        textLabel?.text = title
        toggle.isOn = isOn
        toggle.accessibilityIdentifier = accessibilityID
        // The switch alone announces "on"; VoiceOver needs to know of what.
        toggle.accessibilityLabel = title
        self.onChange = onChange
    }

    @objc private func handleToggle() {
        onChange?(toggle.isOn)
    }
}
