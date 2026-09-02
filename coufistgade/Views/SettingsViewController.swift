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
        static let resetProgressRow = "settings.resetProgress"
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

    /// 表里的一节。
    ///
    /// 引入它是因为「重置进度」不是一个 setting——它没有开关状态，也不写偏好。
    /// 原先三处 dataSource 方法都直接拿 `Setting.allCases[section]` 索引，多出一节
    /// 之后那个下标会越界。让 section 有自己的类型，越界就编译不过，而不是运行时崩。
    private enum Section: Hashable {
        case setting(Setting)
        case resetProgress

        /// 顺序即屏幕上的顺序：偏好在前，破坏性操作垫底。
        ///
        /// 破坏性的那一节放最后是刻意的——它不该出现在玩家滑动去改音效时的路上。
        static let all: [Section] = Setting.allCases.map(Section.setting) + [.resetProgress]

        var footer: String? {
            switch self {
            case .setting(let setting): setting.footer
            case .resetProgress: Strings.resetProgressFooter
            }
        }
    }

    private let store: PersistenceManager
    /// 重置完成后播报给 VoiceOver。可注入，让测试不必让 VoiceOver 真的在跑。
    private let announcer: Announcer
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let titleLabel = UILabel()

    init(
        store: PersistenceManager = PersistenceManager(),
        announcer: Announcer = Announcer()
    ) {
        self.store = store
        self.announcer = announcer
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
        tableView.register(
            DestructiveActionCell.self,
            forCellReuseIdentifier: DestructiveActionCell.reuseID
        )
        // 开关行不可选（点它只会误导），但重置行必须可点。所以全表允许选中，
        // 由 willSelectRowAt 逐行否决——原先在这里一次性关掉整表，多出可点的一行
        // 之后就不对了。
        tableView.allowsSelection = true
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

    /// One section per row, so each can carry its own footer.
    func numberOfSections(in tableView: UITableView) -> Int {
        Section.all.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }

    func tableView(
        _ tableView: UITableView,
        titleForFooterInSection section: Int
    ) -> String? {
        Section.all[section].footer
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        switch Section.all[indexPath.section] {
        case .setting(let setting):
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

        case .resetProgress:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: DestructiveActionCell.reuseID,
                for: indexPath
            ) as? DestructiveActionCell ?? DestructiveActionCell(style: .default, reuseIdentifier: nil)

            cell.configure(
                title: Strings.resetProgress,
                accessibilityID: AccessibilityID.resetProgressRow
            )
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension SettingsViewController: UITableViewDelegate {

    /// 只有重置那一行可选。
    ///
    /// 逐行否决而不是全表关掉：开关行被点中会高亮一下然后什么都不发生，那是误导。
    func tableView(
        _ tableView: UITableView,
        willSelectRowAt indexPath: IndexPath
    ) -> IndexPath? {
        switch Section.all[indexPath.section] {
        case .setting: nil
        case .resetProgress: indexPath
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // 高亮立刻收回：弹窗盖上来后底下留着一行选中态，关掉弹窗时会像是还没做完。
        tableView.deselectRow(at: indexPath, animated: true)
        guard case .resetProgress = Section.all[indexPath.section] else { return }
        confirmResetProgress()
    }

    /// 二次确认。破坏性且不可撤销，点一下不能直接生效。
    ///
    /// 用 UIAlertController 而不是自制面板：破坏性确认是玩家在别的 app 里已经认识
    /// 的形状，而且它自带无障碍与键盘处理。这一页本来就是用 UITableView 换取
    /// 平台行为的（见文件头），同一个取舍。
    private func confirmResetProgress() {
        let alert = UIAlertController(
            title: Strings.resetProgressConfirmTitle,
            message: Strings.resetProgressConfirmMessage,
            preferredStyle: .alert
        )
        // 取消在前且是 .cancel：误触时最可能连点到的应当是「什么都没发生」。
        alert.addAction(UIAlertAction(title: Strings.cancel, style: .cancel))
        alert.addAction(
            UIAlertAction(title: Strings.resetProgressConfirmAction, style: .destructive) {
                [weak self] _ in
                self?.store.resetProgress()
                // 重置后这一页上没有任何可见变化能说明它生效了（最高分显示在首页与
                // 成就页），所以给 VoiceOver 一句播报，否则那次点击对盲用户是静默的。
                self?.announcer.announceImmediately(Strings.resetProgressDoneAnnouncement)
            }
        )
        present(alert, animated: true)
    }
}

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

/// 一个破坏性操作行。红字，无附件视图，无开关。
///
/// 不和 SettingToggleCell 合成一个类：开关行有 on/off 状态且每次变更都要写偏好，
/// 这一行只触发一次且没有状态。合起来会让每个方法里都多一个 switch。
private final class DestructiveActionCell: UITableViewCell {

    static let reuseID = "DestructiveActionCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = UIColor(resource: .surface)
        // 系统红，不是主题的 accent：破坏性操作该用平台自己那个红，玩家在别的 app
        // 里已经学会了它的含义。accent 是「主操作」的颜色（首页 PLAY、结算页
        // Play Again 都用它），用在这里会让重置看起来像是被推荐的选择。
        textLabel?.textColor = .systemRed
        textLabel?.font = Theme.Typography.rounded(
            .body,
            weight: .medium,
            maximumPointSize: Theme.Typography.MaxPointSize.buttonLabel
        )
        textLabel?.adjustsFontForContentSizeCategory = true
        textLabel?.numberOfLines = 0
        textLabel?.textAlignment = .center
        selectionStyle = .default
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("DestructiveActionCell is code-only.")
    }

    func configure(title: String, accessibilityID: String) {
        textLabel?.text = title
        accessibilityIdentifier = accessibilityID
        // 整行是一个按钮：VoiceOver 该读作「重置进度，按钮」，而不是一段文字。
        isAccessibilityElement = true
        accessibilityLabel = title
        accessibilityTraits = .button
    }
}
