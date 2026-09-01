//
//  AchievementFeedbackTests.swift
//  coufistgadeTests
//
//  解锁提示音与震动。ResultViewController 的服务是注入的，所以不需要真的起音频
//  引擎，也不需要 Taptic Engine。
//

import XCTest
import AVFoundation
@testable import coufistgade

final class AchievementFeedbackTests: XCTestCase {

    private final class AudioSpy: AudioPlaying {
        var isEnabled = true
        var unlocks = 0
        var impacts = 0
        var milestones = 0
        func playImpact(_ intensity: ImpactIntensity) { impacts += 1 }
        func playComboMilestone() { milestones += 1 }
        func playAchievementUnlock() { unlocks += 1 }
    }

    private final class HapticSpy: HapticPlaying {
        var isEnabled = true
        var unlocks = 0
        func playImpact(_ intensity: ImpactIntensity) {}
        func playComboMilestone() {}
        func playAchievementUnlock() { unlocks += 1 }
    }

    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    private func achievement(_ id: String) -> Achievement {
        Achievement.all.first { $0.id == id }!
    }

    private func result(unlocked: [Achievement], isNewRecord: Bool = false) -> RoundResult {
        RoundResult(
            score: 120,
            roundCombo: 4,
            bestScore: 300,
            bestCombo: 9,
            isNewRecord: isNewRecord,
            unlockedAchievements: unlocked
        )
    }

    /// 走完真实的呈现流程：反馈在 viewDidAppear 里播，光 loadViewIfNeeded 不够。
    private func present(
        _ result: RoundResult
    ) -> (ResultViewController, AudioSpy, HapticSpy) {
        let audio = AudioSpy()
        let haptics = HapticSpy()
        let sut = ResultViewController(
            result: result,
            prefersReducedMotion: { true },
            audio: audio,
            haptics: haptics
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = sut
        window.makeKeyAndVisible()
        self.window = window
        sut.view.layoutIfNeeded()
        // makeKeyAndVisible 不保证同步走完呈现周期，所以转一次 run loop。
        // 光靠 begin/endAppearanceTransition 在这个环境里不触发 viewDidAppear。
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        return (sut, audio, haptics)
    }

    // MARK: - 有解锁时

    func testUnlockingPlaysBothCues() {
        let (_, audio, haptics) = present(result(unlocked: [achievement("firstPoints")]))

        XCTAssertEqual(audio.unlocks, 1)
        XCTAssertEqual(haptics.unlocks, 1)
    }

    func testMultipleUnlocksStillPlayOnlyOneCue() {
        // 一局解锁三条会响三声，听起来像故障。数量由页面上列出的行数表达。
        let three = [
            achievement("firstPoints"),
            achievement("century"),
            achievement("chainFour"),
        ]
        let (_, audio, haptics) = present(result(unlocked: three))

        XCTAssertEqual(audio.unlocks, 1, "按成就条数重复播放了")
        XCTAssertEqual(haptics.unlocks, 1)
    }

    // MARK: - 没有解锁时

    func testNoUnlockPlaysNothing() {
        // 空数组是常态：大多数局都不会解锁新东西，这时必须完全安静。
        let (_, audio, haptics) = present(result(unlocked: []))

        XCTAssertEqual(audio.unlocks, 0)
        XCTAssertEqual(haptics.unlocks, 0)
    }

    func testARecordWithoutUnlocksDoesNotPlayTheUnlockCue() {
        // 破纪录有自己的庆祝动画，不应借用解锁提示音。
        let (_, audio, _) = present(result(unlocked: [], isNewRecord: true))

        XCTAssertEqual(audio.unlocks, 0)
    }

    // MARK: - 合成

    func testTheUnlockCueIsAudibleAndDistinctFromTheComboCue() throws {
        let service = AudioService()

        let unlock = try XCTUnwrap(service.debugAchievementBuffer(), "没有生成解锁音缓冲")
        let combo = try XCTUnwrap(service.debugComboBuffer())

        // 真的有声音，不是一段静音。
        XCTAssertGreaterThan(Self.peak(of: unlock), 0.01)

        // 且与连击音可区分：解锁更长。两者共用一组常量时这条会失败。
        XCTAssertGreaterThan(unlock.frameLength, combo.frameLength, "解锁音与连击音无法区分")
    }

    func testTheUnlockCueIsShortEnoughToNotOutstayTheScreen() {
        // 结算页出现即播。太长会盖住玩家点 Play Again 的节奏。
        XCTAssertLessThan(GameConfiguration.Feedback.Audio.achievementDuration, 0.4)
    }

    private static func peak(of buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData else { return 0 }
        let samples = UnsafeBufferPointer(start: data[0], count: Int(buffer.frameLength))
        return samples.map(abs).max() ?? 0
    }
}
