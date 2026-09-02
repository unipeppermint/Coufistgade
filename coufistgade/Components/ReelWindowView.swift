//
//  ReelWindowView.swift
//  coufistgade
//
//  一个轮窗：带边框的方格，里面一个符号。见 GAMEPLAY §27、UI_DESIGN §13a。
//
//  抽出来是因为它现在有两个使用者——对局中的 HUD（ReelHUDStripView）与结算页的
//  面板（ReelPanelView）。两处必须画得一模一样：玩家在对局里看着符号往上爬，
//  结算页那三个就得是同一个东西，否则「它一直在那儿」这件事就断了。
//
//  只画不判：不知道阈值，不知道奖励，不知道哪个轮子拖住了赔付。那些都是调用方
//  传进来的状态。
//

import UIKit

final class ReelWindowView: UIView {

    /// 强调状态（GAMEPLAY §27）。
    ///
    /// 分三种而不是一个布尔，因为按最低档赔付之后屏幕上要表达的事情多了一件：
    /// 哪几个轮子在**拖住**赔付。那几个描暗一点的边，就是「往这儿推」的指引。
    enum Emphasis {
        /// 三轮齐平：全部描亮。
        case aligned
        /// 落在最低档，正是它决定了这次赔多少。
        case lagging
        /// 比最低档高，对赔付没有影响。
        case neutral
    }

    /// 尺寸。HUD 里的比结算页的小一号——那里它和分数、计时器挤在一行。
    enum Size {
        case compact
        case regular

        var minimumHeight: CGFloat {
            switch self {
            case .compact: Theme.Layout.reelWindowCompactHeight
            case .regular: Theme.Layout.reelWindowMinimumHeight
            }
        }

        var maximumSymbolPointSize: CGFloat {
            switch self {
            case .compact: Theme.Layout.reelSymbolCompactMaxPointSize
            case .regular: Theme.Layout.reelSymbolMaxPointSize
            }
        }

        var textStyle: UIFont.TextStyle {
            switch self {
            case .compact: .body
            case .regular: .title1
            }
        }
    }

    private let symbolLabel = UILabel()

    /// 当前显示的符号。
    var symbol: ReelSymbol = .cherry {
        didSet { symbolLabel.text = symbol.glyph }
    }

    init(size: Size) {
        super.init(frame: .zero)

        backgroundColor = UIColor(resource: .appBackground)
        layer.cornerRadius = Theme.Radius.button
        layer.cornerCurve = .continuous
        apply(.neutral)

        // 符号是 emoji，跟随 Dynamic Type 但设上限：轮窗是固定尺寸的方格，字形
        // 无限放大会顶出窗口，三列等宽的排布随之崩掉。
        symbolLabel.font = Theme.Typography.rounded(
            size.textStyle,
            weight: .regular,
            maximumPointSize: size.maximumSymbolPointSize
        )
        symbolLabel.adjustsFontForContentSizeCategory = true
        symbolLabel.textAlignment = .center
        symbolLabel.text = symbol.glyph
        symbolLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(symbolLabel)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: size.minimumHeight),
            symbolLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            symbolLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            symbolLabel.topAnchor.constraint(
                greaterThanOrEqualTo: topAnchor,
                constant: Theme.Spacing.xs / 2
            ),
            bottomAnchor.constraint(
                greaterThanOrEqualTo: symbolLabel.bottomAnchor,
                constant: Theme.Spacing.xs / 2
            ),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("ReelWindowView is code-only; this app uses no storyboards or nibs.")
    }

    // MARK: - 状态

    func apply(_ emphasis: Emphasis) {
        switch emphasis {
        case .aligned:
            layer.borderColor = UIColor(resource: .accent).cgColor
            layer.borderWidth = 2
        case .lagging:
            // 同一个强调色但压暗：它是要被推上去的那个，不是成就。
            layer.borderColor = UIColor(resource: .accent).withAlphaComponent(0.5).cgColor
            layer.borderWidth = 2
        case .neutral:
            layer.borderColor = Self.defaultBorderColor
            layer.borderWidth = Self.defaultBorderWidth
        }
    }

    /// 定住/跨档时的一下回弹。
    func playSettleBounce() {
        let overshoot = GameConfiguration.Reels.settleOvershoot
        transform = CGAffineTransform(scaleX: overshoot, y: overshoot)
        UIView.animate(
            withDuration: GameConfiguration.Reels.settleDuration,
            delay: 0,
            usingSpringWithDamping: 0.5,
            initialSpringVelocity: 0.6
        ) {
            self.transform = .identity
        }
    }

    private static let defaultBorderWidth: CGFloat = 1
    private static var defaultBorderColor: CGColor {
        UIColor(resource: .textSecondary).withAlphaComponent(0.25).cgColor
    }
}
