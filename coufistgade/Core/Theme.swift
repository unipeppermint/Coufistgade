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
