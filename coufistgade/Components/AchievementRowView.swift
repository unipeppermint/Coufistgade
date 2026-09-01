//
//  AchievementRowView.swift
//  coufistgade
//
//  成就列表里的一行：名称、说明、解锁状态，生涯类成就还有一条进度。
//
//  不用 UITableViewCell：成就是固定十条，没有复用需求，而 cell 复用恰恰是
//  Phase 14 里咬过我一次的地方（prepareForReuse 清掉了闭包）。一个普通 UIView
//  加进 UIStackView，少一层出错的余地。
//
//  整行作为单个无障碍元素：VoiceOver 应当读出"名称，说明，已解锁"这一整句，
//  而不是把三段拆成三个互不相关的碎片。
//

import UIKit

final class AchievementRowView: UIView {

    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let stateIcon = UIImageView()
    private let progressBar = UIProgressView(progressViewStyle: .default)
    private let textStack = UIStackView()

    init(achievement: Achievement, isUnlocked: Bool, progress: Double?) {
        super.init(frame: .zero)
        setupUI()
        setupConstraints()
        configure(achievement: achievement, isUnlocked: isUnlocked, progress: progress)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AchievementRowView is code-only; this app uses no storyboards or nibs.")
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = UIColor(resource: .surface)
        layer.cornerRadius = Theme.Radius.button
        layer.cornerCurve = .continuous

        titleLabel.font = Theme.Typography.rounded(
            .headline,
            weight: .semibold,
            maximumPointSize: Theme.Typography.MaxPointSize.buttonLabel
        )
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0

        detailLabel.font = Theme.Typography.rounded(
            .subheadline,
            weight: .regular,
            maximumPointSize: Theme.Typography.MaxPointSize.caption
        )
        detailLabel.textColor = UIColor(resource: .textSecondary)
        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.numberOfLines = 0

        stateIcon.contentMode = .scaleAspectFit
        stateIcon.setContentCompressionResistancePriority(.required, for: .horizontal)

        progressBar.trackTintColor = UIColor(resource: .appBackground)
        progressBar.progressTintColor = UIColor(resource: .accent)

        textStack.axis = .vertical
        textStack.spacing = 2
        // .fill 而不是 .leading：进度条要占满文字块的宽度。
        //
        // 原先是 .leading，进度条会缩到自身固有宽度（很窄），当初就是为了补救
        // 这点才加了 `progressBar.widthAnchor == textStack.widthAnchor` —— 那条把
        // 子视图宽度反绑到父 stack，构成循环。改 alignment 是正解。
        //
        // 标签本身设了 numberOfLines = 0，.fill 下它们也能正常换行。
        textStack.alignment = .fill
        [titleLabel, detailLabel, progressBar].forEach { textStack.addArrangedSubview($0) }

        [textStack, stateIcon].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        // 整行读作一句，见文件头。
        isAccessibilityElement = true
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            textStack.topAnchor.constraint(equalTo: topAnchor, constant: Theme.Spacing.s),
            textStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Theme.Spacing.s),
            textStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Theme.Spacing.s),

            stateIcon.leadingAnchor.constraint(
                equalTo: textStack.trailingAnchor,
                constant: Theme.Spacing.s
            ),
            stateIcon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Theme.Spacing.s),
            stateIcon.centerYAnchor.constraint(equalTo: centerYAnchor),
            stateIcon.widthAnchor.constraint(equalToConstant: 24),
            stateIcon.heightAnchor.constraint(equalToConstant: 24),
            // 进度条的宽度由 textStack 的 .fill 对齐给出，不在这里反向绑定。
        ])
    }

    // MARK: - Configure

    private func configure(achievement: Achievement, isUnlocked: Bool, progress: Double?) {
        titleLabel.text = AchievementStrings.title(achievement)
        detailLabel.text = AchievementStrings.detail(achievement)

        // 未解锁的成就压暗，但仍然可读：目标本身就是内容，藏起来玩家就不知道该
        // 追什么。这也是不用问号占位的原因。
        titleLabel.textColor = isUnlocked
            ? UIColor(resource: .textPrimary)
            : UIColor(resource: .textSecondary)

        let symbol = isUnlocked ? "checkmark.circle.fill" : "lock.fill"
        stateIcon.image = UIImage(systemName: symbol)
        stateIcon.tintColor = isUnlocked
            ? UIColor(resource: .accent)
            : UIColor(resource: .textSecondary)

        // 进度条只对生涯类成就有意义，且解锁后不再需要。
        if let progress, !isUnlocked {
            progressBar.isHidden = false
            progressBar.progress = Float(progress)
        } else {
            progressBar.isHidden = true
        }

        let state = isUnlocked
            ? AchievementStrings.unlockedState
            : AchievementStrings.lockedState
        accessibilityLabel = "\(titleLabel.text ?? ""), \(detailLabel.text ?? ""), \(state)"
    }
}
