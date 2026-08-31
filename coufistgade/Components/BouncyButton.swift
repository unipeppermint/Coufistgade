//
//  BouncyButton.swift
//  coufistgade
//
//  A UIButton that scales down on touch and springs back (UI_DESIGN §7).
//  Shared by Home's Play button and, later, Result's Play Again button.
//

import UIKit

final class BouncyButton: UIButton {

    private static let pressedScale: CGFloat = 0.94

    override init(frame: CGRect) {
        super.init(frame: frame)
        addPressFeedback()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("BouncyButton is code-only; this app uses no storyboards or nibs.")
    }

    private func addPressFeedback() {
        addTarget(self, action: #selector(handlePressDown), for: [.touchDown, .touchDragEnter])
        addTarget(
            self,
            action: #selector(handlePressUp),
            for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit]
        )
    }

    @objc private func handlePressDown() {
        animate(to: Self.pressedScale)
    }

    @objc private func handlePressUp() {
        animate(to: 1.0)
    }

    private func animate(to scale: CGFloat) {
        // Press feedback is essential interaction feedback, so UI_DESIGN §20
        // keeps it even under Reduce Motion — only the spring is flattened.
        let useSpring = !MotionPreference.isReduced
        let animator = UIViewPropertyAnimator(
            duration: Theme.Duration.buttonFeedback,
            dampingRatio: useSpring ? 0.55 : 1.0
        ) {
            self.transform = CGAffineTransform(scaleX: scale, y: scale)
        }
        animator.isUserInteractionEnabled = true
        animator.startAnimation()
    }
}
