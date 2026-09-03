//
//  Theme.swift
//  coufistgade
//
//  Central home for the UI design tokens from docs/UI_DESIGN.md.
//  Gameplay and physics constants do NOT belong here — those land in
//  GameConfiguration when Phase 3 starts.
//

import UIKit

enum Theme {

    /// 8pt spacing system (UI_DESIGN §17).
    enum Spacing {
        static let xs: CGFloat = 8
        static let s: CGFloat = 16
        static let m: CGFloat = 24
        static let l: CGFloat = 32
        static let xl: CGFloat = 48
    }

    /// UI_DESIGN §18.
    enum Radius {
        static let button: CGFloat = 20
        static let card: CGFloat = 24

        /// 对局中 HUD 轮窗的圆角。
        ///
        /// 不能用 button（20）：那个值是给 56 高的按钮定的，而 HUD 里的轮窗只有
        /// 34 高（Layout.reelWindowCompactHeight）。两个 20 的圆角要吃掉 40pt，
        /// 超过了整条边，圆角于是被压到饱和，方格看起来是个胶囊——「轮窗」这件事
        /// 就读不出来了。取高度的一个较小比例，让它仍是个圆角方格。
        static let reelWindowCompact: CGFloat = 10
    }

    /// UI_DESIGN §19.
    enum Duration {
        static let buttonFeedback: TimeInterval = 0.18
        static let transition: TimeInterval = 0.3
        /// One full breathe cycle of the hero ball (UI_DESIGN §6: 2–4s).
        static let heroFloatCycle: TimeInterval = 3.0
    }

    enum Layout {
        /// Minimum tappable area per Apple's HIG.
        static let minimumTouchTarget: CGFloat = 44
        /// Fixed: the gear is a constant-size icon in a constant-size target,
        /// so it must not grow with Dynamic Type.
        static let settingsIconPointSize: CGFloat = 20
        static let primaryButtonHeight: CGFloat = 56
        static let primaryButtonWidthRatio: CGFloat = 0.6
        static let heroBallWidthRatio: CGFloat = 0.42
        static let heroBallMinimumDiameter: CGFloat = 120
        static let heroBallMaximumDiameter: CGFloat = 200

        /// 结算转轴的窗口最小高度（UI_DESIGN §13a）。
        ///
        /// 取触控目标的尺寸，尽管轮窗不可点：三个格子并排时这个高度看起来正好，
        /// 而复用已有常量省掉一个自由数字。大号 Dynamic Type 下由内容顶开。
        static let reelWindowMinimumHeight: CGFloat = 56

        /// 轮子上符号的字号上限。
        ///
        /// 必须设上限：符号是 emoji，字形跟随 Dynamic Type 无限放大会顶出固定
        /// 宽度的轮窗，三列等宽的排布随之崩掉。
        static let reelSymbolMaxPointSize: CGFloat = 34

        /// 对局中 HUD 里的轮窗，比结算页那个小一号。
        ///
        /// 小是必须的，而不是审美选择：HUD 的高度决定物理天花板的位置
        /// （见 GameScreenView.playableInsets），每多一点都从可玩区域里扣。
        static let reelWindowCompactHeight: CGFloat = 34
        static let reelSymbolCompactMaxPointSize: CGFloat = 20

        /// 对局中轮窗的最小宽度。
        ///
        /// 略宽于高（34），因为老虎机的轮窗本来就是横向略长的方格。不设下限的话，
        /// 窗口会缩到 emoji 的固有宽度，三个格子看起来是圆的，读不出「轮子」。
        static let reelWindowCompactWidth: CGFloat = 46

        /// 「还差多少」那行字的固定高度。
        ///
        /// 必须固定：这行字会在「+13」与「✓」之间来回变，若高度随内容变化，
        /// HUD 的高度就会跟着变，物理天花板会在对局中上下移动，把球推来推去。
        /// 这正是 combo 那一行用 alpha 0 而不是 isHidden 的同一个理由。
        static let reelShortfallHeight: CGFloat = 14
    }

    enum Typography {
        /// Display typography caps. Wordmarks and button labels gain nothing
        /// from unbounded growth, and uncapped they force the whole vertical
        /// chain past the screen height at accessibility sizes.
        enum MaxPointSize {
            static let wordmark: CGFloat = 40
            static let caption: CGFloat = 22
            static let scoreValue: CGFloat = 44
            static let buttonLabel: CGFloat = 24
        }

        /// Scales with Dynamic Type while keeping the rounded, playful tone
        /// asked for in UI_DESIGN §16.
        static func rounded(
            _ style: UIFont.TextStyle,
            weight: UIFont.Weight,
            maximumPointSize: CGFloat? = nil
        ) -> UIFont {
            let metrics = UIFontMetrics(forTextStyle: style)
            let base = UIFont.preferredFont(forTextStyle: style)
            let sized = UIFont.systemFont(ofSize: base.pointSize, weight: weight)
            let designed = sized.fontDescriptor.withDesign(.rounded)
                .map { UIFont(descriptor: $0, size: 0) } ?? sized

            guard let maximumPointSize else {
                return metrics.scaledFont(for: designed)
            }
            return metrics.scaledFont(for: designed, maximumPointSize: maximumPointSize)
        }

        /// Score-style numerals: rounded, bold, and monospaced so the value
        /// does not jitter horizontally as digits change.
        static func numeric(
            _ style: UIFont.TextStyle,
            maximumPointSize: CGFloat? = nil
        ) -> UIFont {
            let metrics = UIFontMetrics(forTextStyle: style)
            let base = UIFont.preferredFont(forTextStyle: style)
            let sized = UIFont.monospacedDigitSystemFont(ofSize: base.pointSize, weight: .bold)
            let designed = sized.fontDescriptor.withDesign(.rounded)
                .map { UIFont(descriptor: $0, size: 0) } ?? sized

            guard let maximumPointSize else {
                return metrics.scaledFont(for: designed)
            }
            return metrics.scaledFont(for: designed, maximumPointSize: maximumPointSize)
        }
    }
}
