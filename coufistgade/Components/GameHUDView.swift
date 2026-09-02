//
//  GameHUDView.swift
//  coufistgade
//
//  The game's UIKit HUD: score, and combo when it is running (UI_DESIGN §8).
//
//  Composed rather than left as two views on the controller for one concrete
//  reason: the HUD's height sets the top of the playable area, and that has to
//  be a single measurement. Two independently-positioned views would each need
//  the controller to know their layout relationship.
//

import UIKit

final class GameHUDView: UIView {

    private let scoreHUD: ScoreHUDView
    private let comboHUD: ComboHUDView
    private let timerHUD: TimerHUDView
    /// 对局中的三个轮子（GAMEPLAY §27）。
    ///
    /// 高度恒定，见 ReelHUDStripView 顶部——它和 combo 行受同一条约束约束：
    /// 这一条的高度决定物理天花板的位置。
    private let reelStrip = ReelHUDStripView()
    private let stack = UIStackView()

    /// Emphasis from the most recent combo event, applied to the next score pop.
    ///
    /// GAMEPLAY §16 asks for a stronger *score* animation at combo 4, so the
    /// score pop needs the combo's emphasis. It cannot be derived from
    /// ScoreEvent's multiplier: combo 2 and combo 3 both pay 2x, so the
    /// multiplier alone cannot tell them apart. GameScene reports combo before
    /// score, which is what makes this ordering sound.
    private var pendingEmphasis: ComboEmphasis = .normal

    init(
        scoreHUD: ScoreHUDView = ScoreHUDView(),
        comboHUD: ComboHUDView = ComboHUDView(),
        timerHUD: TimerHUDView = TimerHUDView()
    ) {
        self.scoreHUD = scoreHUD
        self.comboHUD = comboHUD
        self.timerHUD = timerHUD
        super.init(frame: .zero)
        setupUI()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("GameHUDView is code-only; this app uses no storyboards or nibs.")
    }

    // MARK: - Setup

    private func setupUI() {
        isUserInteractionEnabled = false

        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = Theme.Spacing.xs / 2
        // The score column is only as wide as its content, so the timer's
        // clearance constraint has something real to measure against.
        stack.setContentCompressionResistancePriority(.required, for: .horizontal)
        // The combo view stays in the layout at alpha 0 rather than being
        // hidden, and carries seed text so its height is reserved from the
        // start. isHidden would collapse it out of the stack, and empty labels
        // measure zero — either way the HUD's height would change, moving the
        // physics ceiling up and down mid-round and shoving balls around every
        // time a combo started or lapsed. A reserved row costs a little space
        // and keeps the world still.
        // Score and combo centred; the timer is placed separately below, on the
        // pause button's row. Stacked directly above the score it read as part
        // of it — a bare number sitting on top of "SCORE 40".
        // 轮子排在 combo 下面：它是这一局的目标，而分数与连击是当下的状态。
        // 目标放在状态之后读起来才顺——先看到「我现在多少」，再看到「还差多少」。
        [scoreHUD, comboHUD, reelStrip].forEach { stack.addArrangedSubview($0) }

        stack.translatesAutoresizingMaskIntoConstraints = false
        timerHUD.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        addSubview(timerHUD)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            // Content-width and centred, rather than pinned to both edges, so the
            // timer has room at the right and the score still reads as centred.
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),

            // Right edge, level with the top of the score: balances the pause
            // button across the row.
            timerHUD.trailingAnchor.constraint(equalTo: trailingAnchor),
            timerHUD.topAnchor.constraint(equalTo: topAnchor),
            // At accessibility sizes the score grows outward; yielding to it
            // keeps the two from colliding mid-row.
            timerHUD.leadingAnchor.constraint(greaterThanOrEqualTo: stack.trailingAnchor),
        ])
    }

    // MARK: - Events

    func apply(score event: ScoreEvent) {
        scoreHUD.apply(event, emphasis: pendingEmphasis)
    }

    func apply(combo event: ComboEvent) {
        pendingEmphasis = event.emphasis
        comboHUD.apply(event)
    }

    func apply(remainingSeconds: Int) {
        timerHUD.update(remainingSeconds: remainingSeconds)
    }

    /// 轮子的进度（GAMEPLAY §27）。
    ///
    /// 每次得分都会调到这里，但绝大多数时候三个符号一个都没变——只有跨档时才给
    /// 回弹与提示音，否则每次命中都响一下，那条 HUD 会变成噪音。
    func apply(reels progress: ReelProgress, feedback: (ReelDimension) -> Void) {
        let advanced = reelStrip.apply(progress)
        guard !advanced.isEmpty else { return }
        reelStrip.playAdvanceBounce(for: advanced)
        advanced.forEach(feedback)
    }

    func reset() {
        pendingEmphasis = .normal
        scoreHUD.reset()
        comboHUD.reset()
        timerHUD.reset()
        reelStrip.reset()
    }

    // MARK: - Inspection

    var displayedScoreText: String? { scoreHUD.displayedScoreText }
    var displayedMultiplierText: String? { comboHUD.displayedMultiplierText }
    var isComboVisible: Bool { comboHUD.isReadoutVisible }
    var displayedTimeText: String? { timerHUD.displayedText }
    var isTimerUrgent: Bool { timerHUD.isShowingUrgency }
    var displayedReelSymbols: [ReelSymbol] { reelStrip.displayedSymbols }

}
