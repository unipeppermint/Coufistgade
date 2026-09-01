//
//  AchievementsViewController.swift
//  coufistgade
//
//  成就列表。PRD §10 的 Achievements 第一版。
//
//  用 UIScrollView + UIStackView 而不是 UITableView：成就是固定十条，没有复用
//  需求，而 cell 复用正是 Phase 14 咬过我一次的地方。少一层机制，少一处出错。
//
//  只读页面：不写任何数据，解锁判定发生在一局结束时（AchievementTracker）。
//

import UIKit

final class AchievementsViewController: UIViewController {

    enum AccessibilityID {
        static let closeButton = "achievements.closeButton"
        static let progressLabel = "achievements.progressLabel"
        static let scrollView = "achievements.scrollView"
    }

    private let tracker: AchievementTracker

    private let titleLabel = UILabel()
    private let progressLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let scrollView = UIScrollView()
    private let rowStack = UIStackView()

    init(tracker: AchievementTracker = AchievementTracker()) {
        self.tracker = tracker
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AchievementsViewController is code-only; this app uses no storyboards or nibs.")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupActions()
        populate()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = UIColor(resource: .appBackground)

        // 导航栏全局隐藏，所以这一页自带标题与退出口——和设置页同样的处理。
        titleLabel.text = AchievementStrings.screenTitle
        titleLabel.font = Theme.Typography.rounded(
            .title1,
            weight: .bold,
            maximumPointSize: Theme.Typography.MaxPointSize.wordmark
        )
        titleLabel.textColor = UIColor(resource: .textPrimary)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.accessibilityTraits = .header

        progressLabel.font = Theme.Typography.rounded(
            .subheadline,
            weight: .medium,
            maximumPointSize: Theme.Typography.MaxPointSize.caption
        )
        progressLabel.textColor = UIColor(resource: .textSecondary)
        progressLabel.adjustsFontForContentSizeCategory = true
        progressLabel.accessibilityIdentifier = AccessibilityID.progressLabel

        var closeConfig = UIButton.Configuration.plain()
        closeConfig.image = UIImage(
            systemName: "xmark",
            withConfiguration: UIImage.SymbolConfiguration(
                pointSize: Theme.Layout.settingsIconPointSize
            )
        )
        closeConfig.baseForegroundColor = UIColor(resource: .textSecondary)
        closeConfig.contentInsets = .zero
        closeButton.configuration = closeConfig
        closeButton.backgroundColor = UIColor(resource: .surface)
        closeButton.layer.cornerRadius = Theme.Layout.minimumTouchTarget / 2
        closeButton.accessibilityIdentifier = AccessibilityID.closeButton
        closeButton.accessibilityLabel = Strings.closeSettingsLabel

        scrollView.accessibilityIdentifier = AccessibilityID.scrollView
        scrollView.alwaysBounceVertical = true

        rowStack.axis = .vertical
        rowStack.spacing = Theme.Spacing.xs

        [titleLabel, progressLabel, closeButton, scrollView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(rowStack)
    }

    private func setupConstraints() {
        let safe = view.safeAreaLayoutGuide

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

            progressLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            progressLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            progressLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: safe.trailingAnchor,
                constant: -Theme.Spacing.m
            ),

            scrollView.topAnchor.constraint(
                equalTo: progressLabel.bottomAnchor,
                constant: Theme.Spacing.s
            ),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // 纵向（滚动方向）绑 contentLayoutGuide：这几条决定内容有多高。
            //
            // 底部常量是 **正** 的。滚动视图的裸 bottomAnchor 指向 content guide，
            // 负值会把内容高度压得比实际行高更短，最后一行就被裁掉 —— 这正是
            // 「显示不全」的原因。正值表示内容再向下延伸 32pt 作为留白。
            rowStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            scrollView.contentLayoutGuide.bottomAnchor.constraint(
                equalTo: rowStack.bottomAnchor,
                constant: Theme.Spacing.l
            ),
            rowStack.leadingAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.leadingAnchor,
                constant: Theme.Spacing.m
            ),
            scrollView.contentLayoutGuide.trailingAnchor.constraint(
                equalTo: rowStack.trailingAnchor,
                constant: Theme.Spacing.m
            ),

            // 横向绑 frameLayoutGuide：宽度必须来自屏幕，不能来自内容。
            //
            // 原先五条约束全指向裸 anchor（即 content guide），于是宽度由内容决定，
            // 而标签换行又依赖宽度 —— 循环。Auto Layout 会解出某个宽度，但不保证
            // 是屏幕宽度。
            rowStack.widthAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.widthAnchor,
                constant: -Theme.Spacing.m * 2
            ),
        ])
    }

    private func setupActions() {
        closeButton.addTarget(self, action: #selector(handleCloseTapped), for: .touchUpInside)
    }

    // MARK: - Data

    private func populate() {
        progressLabel.text = AchievementStrings.progressCount(
            unlocked: tracker.unlockedCount,
            total: Achievement.all.count
        )

        // 一条都没解锁时给一句提示，否则整页只剩十行锁头，读起来像坏了。
        if tracker.unlockedCount == 0 {
            let hint = UILabel()
            hint.text = AchievementStrings.emptyHint
            hint.font = Theme.Typography.rounded(
                .subheadline,
                weight: .regular,
                maximumPointSize: Theme.Typography.MaxPointSize.caption
            )
            hint.textColor = UIColor(resource: .textSecondary)
            hint.adjustsFontForContentSizeCategory = true
            hint.numberOfLines = 0
            rowStack.addArrangedSubview(hint)
        }

        for achievement in Achievement.all {
            rowStack.addArrangedSubview(
                AchievementRowView(
                    achievement: achievement,
                    isUnlocked: tracker.isUnlocked(achievement),
                    progress: tracker.progress(for: achievement)
                )
            )
        }
    }

    // MARK: - Actions

    @objc private func handleCloseTapped() {
        navigationController?.popViewController(animated: true)
    }
}
