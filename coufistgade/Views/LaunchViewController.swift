//
//  LaunchViewController.swift
//  coufistgade
//
//  app 的第一帧。球从上方落下、弹一下定住，字标浮上来，然后交给首页。
//
//  **为什么需要这个类。** Info.plist 里的 `UILaunchScreen` 是系统在进程起来之前
//  画的，那时没有代码在跑 —— 它只能是一块纯色或一张静态图，不可能有动画。所以
//  真正的启动动画必须由 app 自己的第一个控制器来做，这就是这里。
//
//  **交接处不能闪。** 这个控制器的底色必须和 `UILaunchScreen` 的
//  `UIColorName`（AppBackground）**同一个色值**，否则静态启动图切到第一帧时会闪
//  一下。两边都读同一个 asset，而不是各写一个十六进制。
//
//  **球为什么是落下而不是淡入。** 产品叫 Bounce Rally，落体加一次回弹就是产品名
//  本身，不需要文案解释。这也是整个 app 里唯一一处「动画即说明」的地方。
//
//  复用 HeroBallView 而不是另画一个球：切到首页之后玩家看到的是同一个球，尺寸算
//  法也照抄首页（§6 的 ratio 与下限），所以那一刀切过去球不会跳。
//

import UIKit

final class LaunchViewController: UIViewController {

    enum AccessibilityID {
        static let ball = "launch.ball"
        static let wordmark = "launch.wordmark"
    }

    /// 动画放完（或被跳过）时调用一次。SceneDelegate 用它换根控制器。
    var onFinish: (() -> Void)?

    private let heroBallView: HeroBallView
    private let titleLabel = UILabel()

    /// 驱动落体的那条约束。动画改的是它的 constant。
    private var ballCenterY: NSLayoutConstraint?

    /// 可注入，让测试能跑两条动画路径而不必去改模拟器的辅助功能设置。
    private let prefersReducedMotion: () -> Bool

    /// onFinish 只该发生一次。点击跳过与动画自然结束会抢这一次。
    private var hasFinished = false

    /// 动画进行中。viewDidLayoutSubviews 靠它决定要不要把球按回静止位置 ——
    /// 落体途中若被布局回调重置 constant，球会瞬移。
    private(set) var isAnimating = false

    init(prefersReducedMotion: @escaping () -> Bool = { MotionPreference.isReduced }) {
        self.prefersReducedMotion = prefersReducedMotion
        // 启动页的球不呼吸：它正在做一件更明确的事（落下），两个动作叠在一起会
        // 互相干扰。呼吸是首页那个球的职责。
        self.heroBallView = HeroBallView(prefersReducedMotion: { true })
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("LaunchViewController is code-only; this app uses no storyboards or nibs.")
    }
}

// MARK: - 生命周期

extension LaunchViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // 见文件头：必须和 UILaunchScreen 的 UIColorName 同一个 asset。
        view.backgroundColor = UIColor(resource: .appBackground)
        setupUI()
        setupConstraints()
        setupSkipGesture()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        play()
    }

    private func setupUI() {
        heroBallView.accessibilityIdentifier = AccessibilityID.ball
        heroBallView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(heroBallView)

        // 字标的属性必须和首页那个逐项对齐（kern 4、同字体、同上限、同缩放策略），
        // 否则切过去会看到字距或字号跳一下。见 HomeViewController 里那段实测说明。
        titleLabel.attributedText = NSAttributedString(
            string: "BOUNCE RALLY",
            attributes: [
                .kern: 4,
                .font: Theme.Typography.rounded(
                    .largeTitle,
                    weight: .bold,
                    maximumPointSize: Theme.Typography.MaxPointSize.wordmark
                ),
                .foregroundColor: UIColor(resource: .textPrimary),
            ]
        )
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.6
        titleLabel.accessibilityIdentifier = AccessibilityID.wordmark
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // 两者都从透明开始：第一帧应当和静态启动图完全一样（一块纯色），
        // 动画从那里长出来。
        heroBallView.alpha = 0
        titleLabel.alpha = 0

        // 整屏对 VoiceOver 只说一句，而不是让它逐个念球和字标。
        view.isAccessibilityElement = true
        view.accessibilityLabel = Strings.launchLabel
        heroBallView.isAccessibilityElement = false
        titleLabel.isAccessibilityElement = false
    }
}

// MARK: - 布局

extension LaunchViewController {

    /// 球静止位置相对安全区中心的上移量，占安全区高度的比例。
    ///
    /// 不居中：字标在下面占一块，球压在正中会让整幅偏下。首页的球也不是严格居中
    /// （那里 centerY 是 defaultHigh，会被下面的链条顶上去），这里取一个固定值达到
    /// 同样的观感。
    private static let ballRiseRatio: CGFloat = 0.08

    private func setupConstraints() {
        let safe = view.safeAreaLayoutGuide

        // 尺寸算法照抄首页，三条一起：比例、上限、下限。缺任何一条都会让启动页的
        // 球和首页的球在某个屏宽上对不上。
        let width = heroBallView.widthAnchor.constraint(
            equalTo: safe.widthAnchor,
            multiplier: Theme.Layout.heroBallWidthRatio
        )
        width.priority = .defaultHigh

        let centerY = heroBallView.centerYAnchor.constraint(
            equalTo: safe.centerYAnchor,
            constant: 0
        )
        ballCenterY = centerY

        NSLayoutConstraint.activate([
            width,
            heroBallView.widthAnchor.constraint(
                greaterThanOrEqualToConstant: Theme.Layout.heroBallMinimumDiameter
            ),
            heroBallView.widthAnchor.constraint(
                lessThanOrEqualToConstant: Theme.Layout.heroBallMaximumDiameter
            ),
            heroBallView.heightAnchor.constraint(equalTo: heroBallView.widthAnchor),
            heroBallView.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            centerY,

            titleLabel.topAnchor.constraint(
                equalTo: heroBallView.bottomAnchor,
                constant: Theme.Spacing.l
            ),
            titleLabel.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            titleLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: safe.leadingAnchor,
                constant: Theme.Spacing.m
            ),
            titleLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: safe.trailingAnchor,
                constant: -Theme.Spacing.m
            ),
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 球的静止位置。动画没跑时（含 Reduce Motion）它就该在这儿。
        guard !isAnimating else { return }
        ballCenterY?.constant = restingOffset
    }

    private var restingOffset: CGFloat {
        -view.safeAreaLayoutGuide.layoutFrame.height * Self.ballRiseRatio
    }

    /// 球完全在屏幕上方之外的位置，落体的起点。
    private var offscreenOffset: CGFloat {
        let safeHeight = view.safeAreaLayoutGuide.layoutFrame.height
        let diameter = heroBallView.bounds.height
        // 半个安全区高度把球送到上边缘，再加一个直径确保它整颗都在屏幕外。
        return -(safeHeight / 2 + max(diameter, Theme.Layout.heroBallMinimumDiameter))
    }
}

// MARK: - 动画

extension LaunchViewController {

    /// 落地那一下的阻尼。
    ///
    /// 0.62 是「弹一次就定住」的位置：再低会连弹好几下，像个 bug；再高就没有弹性，
    /// 球只是滑到位，产品名那层意思就没了。
    private static let settleDamping: CGFloat = 0.62

    /// 放启动动画。放完（或 Reduce Motion 下直接淡入完）调 onFinish。
    func play() {
        guard !isAnimating, !hasFinished else { return }

        // 先跑一次布局，让 heroBallView.bounds 有值 —— offscreenOffset 要用它的
        // 直径。viewDidAppear 时通常已经布过，但显式一次比依赖时序可靠。
        view.layoutIfNeeded()

        // UI_DESIGN §20：减少大幅动画，但不能把东西拿掉。落体是「大幅」的，
        // 换成原地淡入 —— 玩家仍然看到球和字标，只是它们不飞。
        guard !prefersReducedMotion() else {
            playReducedMotion()
            return
        }

        isAnimating = true

        // 从屏幕外开始。alpha 立刻给满：球是从上面掉进来的，不该边掉边淡入，
        // 那会同时表达两件事。
        ballCenterY?.constant = offscreenOffset
        view.layoutIfNeeded()
        heroBallView.alpha = 1

        UIView.animate(
            withDuration: Theme.Duration.launchBallDrop,
            delay: 0,
            usingSpringWithDamping: Self.settleDamping,
            initialSpringVelocity: 0,
            options: [.allowUserInteraction]
        ) {
            self.ballCenterY?.constant = self.restingOffset
            self.view.layoutIfNeeded()
        } completion: { _ in
            self.fadeInWordmarkAndFinish()
        }
    }

    /// 球落地之后：字标浮上来，停一下，交班。
    private func fadeInWordmarkAndFinish() {
        guard !hasFinished else { return }

        UIView.animate(
            withDuration: Theme.Duration.launchWordmarkFade,
            delay: 0,
            options: [.curveEaseOut, .allowUserInteraction]
        ) {
            self.titleLabel.alpha = 1
        } completion: { _ in
            self.isAnimating = false
            // 停一下再走，让玩家看清刚才落定的画面。
            DispatchQueue.main.asyncAfter(deadline: .now() + Theme.Duration.launchHold) {
                self.finish()
            }
        }
    }

    /// Reduce Motion 下的版本：球在静止位置原地淡入，不落体。
    ///
    /// 淡入本身保留，因为它不是「大幅动画」，而且去掉之后这个页面会变成一帧硬切，
    /// 反而更突兀。
    private func playReducedMotion() {
        isAnimating = true
        ballCenterY?.constant = restingOffset
        view.layoutIfNeeded()

        UIView.animate(
            withDuration: Theme.Duration.transition,
            delay: 0,
            options: [.curveEaseOut, .allowUserInteraction]
        ) {
            self.heroBallView.alpha = 1
            self.titleLabel.alpha = 1
        } completion: { _ in
            self.isAnimating = false
            DispatchQueue.main.asyncAfter(deadline: .now() + Theme.Duration.launchHold) {
                self.finish()
            }
        }
    }
}

// MARK: - 跳过与收尾

extension LaunchViewController {

    /// 点一下直接进游戏。
    ///
    /// 回头客不该被这一秒挡住。启动页是给第一次打开的人看的，第一百次打开的人只想
    /// 玩，所以整屏都可点。
    private func setupSkipGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleSkip))
        view.addGestureRecognizer(tap)
    }

    @objc private func handleSkip() {
        skip()
    }

    /// 跳过启动动画，立刻交班。
    ///
    /// 与 `handleSkip` 分开，只为让测试有个不依赖手势识别器的入口 —— UITapGesture
    /// 在测试进程里无法真正触发，而经 `NSSelectorFromString` 去调私有方法会在方法
    /// 改名时静默失效。
    func skip() {
        guard !hasFinished else { return }
        // 把动画停在当前位置再走 —— 不停的话它会在换根控制器的过程里继续跑。
        heroBallView.layer.removeAllAnimations()
        view.layer.removeAllAnimations()
        isAnimating = false
        finish()
    }

    /// 交班。只会真正发生一次。
    private func finish() {
        guard !hasFinished else { return }
        hasFinished = true
        onFinish?()
    }
}
