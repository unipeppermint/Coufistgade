//
//  GameScreenView.swift
//  coufistgade
//
//  The game screen's view hierarchy: the SKView, the pause button, the HUD, and
//  the overlay, plus the constraints that place them.
//
//  Extracted from GameViewController, which had grown past 370 lines and was
//  doing two jobs. Everything here is view construction and geometry; the
//  controller keeps the lifecycle, the scene, and the navigation.
//
//  It owns `playableInsets` because that is a measurement of these views — the
//  controller cannot compute it without reaching into all four of them.
//

import UIKit
import SpriteKit

final class GameScreenView: UIView {

    let skView = SKView()
    let hud = GameHUDView()
    let overlay = GameOverlayView()
    private let pauseButton = UIButton(type: .system)

    var onPauseTapped: (() -> Void)?

    init(pauseButtonAccessibilityID: String) {
        super.init(frame: .zero)
        setupUI(pauseButtonAccessibilityID: pauseButtonAccessibilityID)
        setupConstraints()
        pauseButton.addTarget(self, action: #selector(handlePause), for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("GameScreenView is code-only; this app uses no storyboards or nibs.")
    }

    // MARK: - Setup

    private func setupUI(pauseButtonAccessibilityID: String) {
        backgroundColor = UIColor(resource: .appBackground)

        skView.ignoresSiblingOrder = true
        skView.allowsTransparency = false
        // Otherwise VoiceOver reads the playfield as an unlabelled blank. It is
        // one element on purpose: the balls move continuously, so exposing each
        // as its own element would produce a list that changes under the user's
        // finger and could never be navigated.
        skView.isAccessibilityElement = true
        skView.accessibilityLabel = Strings.playfieldLabel
        skView.accessibilityHint = Strings.playfieldHint
        skView.accessibilityTraits = .allowsDirectInteraction
        // Game feel is the product (PRD §13), so take ProMotion when offered
        // instead of capping at 60. Requires CADisableMinimumFrameDuration in
        // Info.plist to actually be granted.
        skView.preferredFramesPerSecond = UIScreen.main.maximumFramesPerSecond
        #if DEBUG
        skView.showsFPS = true
        skView.showsNodeCount = true
        skView.showsPhysics = DebugOptions.showPhysics
        #endif

        // Pause, not close: UI_DESIGN §8 puts Pause in the HUD and §24 routes
        // quitting through its panel, so leaving mid-round takes two deliberate
        // taps instead of one stray one at the edge of the playfield.
        var pauseConfig = UIButton.Configuration.plain()
        pauseConfig.image = UIImage(
            systemName: "pause.fill",
            withConfiguration: UIImage.SymbolConfiguration(
                pointSize: Theme.Layout.settingsIconPointSize
            )
        )
        pauseConfig.baseForegroundColor = UIColor(resource: .textSecondary)
        pauseConfig.contentInsets = .zero
        pauseButton.configuration = pauseConfig
        pauseButton.backgroundColor = UIColor(resource: .surface)
        pauseButton.layer.cornerRadius = Theme.Layout.minimumTouchTarget / 2
        pauseButton.accessibilityIdentifier = pauseButtonAccessibilityID
        pauseButton.accessibilityLabel = Strings.pauseGameLabel

        [skView, pauseButton, hud, overlay].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
    }

    private func setupConstraints() {
        let safe = safeAreaLayoutGuide

        NSLayoutConstraint.activate([
            // Full screen, so the background bleeds under the safe area.
            skView.topAnchor.constraint(equalTo: topAnchor),
            skView.leadingAnchor.constraint(equalTo: leadingAnchor),
            skView.trailingAnchor.constraint(equalTo: trailingAnchor),
            skView.bottomAnchor.constraint(equalTo: bottomAnchor),

            overlay.topAnchor.constraint(equalTo: topAnchor),
            overlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: bottomAnchor),

            pauseButton.topAnchor.constraint(equalTo: safe.topAnchor, constant: Theme.Spacing.xs),
            pauseButton.leadingAnchor.constraint(
                equalTo: safe.leadingAnchor,
                constant: Theme.Spacing.m
            ),
            pauseButton.widthAnchor.constraint(equalToConstant: Theme.Layout.minimumTouchTarget),
            pauseButton.heightAnchor.constraint(equalToConstant: Theme.Layout.minimumTouchTarget),

            hud.topAnchor.constraint(equalTo: safe.topAnchor, constant: Theme.Spacing.xs),
            // Full safe width, so the score stays centred on the screen and the
            // timer can sit at the right edge. The pause button overlays the
            // left end, where the HUD has nothing.
            hud.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: Theme.Spacing.m),
            hud.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -Theme.Spacing.m),
        ])
    }

    // MARK: - Geometry

    /// The region the physics world may use, in view coordinates.
    ///
    /// The SKView spans the full screen so the background can bleed to the edges,
    /// which means the playable region has to be described separately: the safe
    /// area keeps balls out from under the Dynamic Island and the home indicator
    /// (GAMEPLAY §9), and the extra top inset keeps them from drifting behind the
    /// score.
    ///
    /// UI_DESIGN §8 asks that the HUD not obstruct the physics world; this is the
    /// other half of that bargain. A ball passing behind the number makes the one
    /// value the player is reading briefly unreadable, and the HUD cannot move out
    /// of the way because it is what the player looks at.
    var playableInsets: UIEdgeInsets {
        var insets = safeAreaInsets
        // Whichever hangs lower sets the ceiling. pauseButton is a fixed 44pt;
        // the HUD grows with text size, and reserves the combo row even while the
        // combo is invisible so this measurement stays stable mid-round.
        let hudBottom = max(pauseButton.frame.maxY, hud.frame.maxY)
        guard hudBottom > 0 else { return insets }

        insets.top = max(insets.top, hudBottom + Theme.Spacing.xs)
        return insets
    }

    /// Blocks throws while a panel is up. The overlay covers the screen, but the
    /// SKView would still receive touches through it.
    func setGameInteractionEnabled(_ isEnabled: Bool) {
        skView.isUserInteractionEnabled = isEnabled
    }

    @objc private func handlePause() {
        onPauseTapped?()
    }
}
