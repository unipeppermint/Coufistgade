//
//  FeedbackCoordinatorTests.swift
//  coufistgadeTests
//

import XCTest
import SpriteKit
@testable import coufistgade

final class FeedbackCoordinatorTests: XCTestCase {

    private final class AudioSpy: AudioPlaying {
        var isEnabled = true
        var impacts: [ImpactIntensity] = []
        var milestones = 0
        func playImpact(_ intensity: ImpactIntensity) { impacts.append(intensity) }
        func playComboMilestone() { milestones += 1 }
        func playAchievementUnlock() {}
    }

    private final class HapticSpy: HapticPlaying {
        var isEnabled = true
        var impacts: [ImpactIntensity] = []
        var milestones = 0
        func playImpact(_ intensity: ImpactIntensity) { impacts.append(intensity) }
        func playComboMilestone() { milestones += 1 }
        func playAchievementUnlock() {}
    }

    private struct SUT {
        let coordinator: FeedbackCoordinator
        let container: SKNode
        let audio: AudioSpy
        let haptics: HapticSpy
    }

    private func makeSUT() -> SUT {
        let container = SKNode()
        let audio = AudioSpy()
        let haptics = HapticSpy()
        return SUT(
            coordinator: FeedbackCoordinator(
                effects: EffectManager(container: container, prefersReducedMotion: { false }),
                audio: audio,
                haptics: haptics
            ),
            container: container,
            audio: audio,
            haptics: haptics
        )
    }

    private func play(
        _ sut: SUT,
        intensity: ImpactIntensity = .medium,
        comboCount: Int,
        multiplier: Int = 1,
        emphasis: ComboEmphasis = .normal
    ) {
        let collision = BallCollision(
            playerBall: BallNode(kind: .player),
            normalBall: BallNode(kind: .normal),
            point: CGPoint(x: 50, y: 50),
            impactSpeed: 400,
            intensity: intensity
        )
        sut.container.addChild(collision.playerBall)
        sut.coordinator.play(
            collision: collision,
            score: ScoreEvent(points: 10 * multiplier, total: 10 * multiplier, multiplier: multiplier),
            combo: ComboEvent(
                count: comboCount,
                multiplier: multiplier,
                emphasis: emphasis,
                isVisible: comboCount >= 2
            )
        )
    }

    // MARK: - The full bundle

    func testOneCollisionProducesEveryChannelOfFeedback() {
        let sut = makeSUT()

        play(sut, comboCount: 1)

        // GAMEPLAY §12 describes feedback as a bundle per tier.
        XCTAssertEqual(sut.audio.impacts, [.medium])
        XCTAssertEqual(sut.haptics.impacts, [.medium])
        XCTAssertFalse(sut.container.children.compactMap { $0 as? SKEmitterNode }.isEmpty)
        XCTAssertFalse(sut.container.children.compactMap { $0 as? SKLabelNode }.isEmpty)
    }

    func testTheIntensityIsPassedThroughUnchanged() {
        for intensity in ImpactIntensity.allCases {
            let sut = makeSUT()
            play(sut, intensity: intensity, comboCount: 1)

            XCTAssertEqual(sut.audio.impacts, [intensity])
            XCTAssertEqual(sut.haptics.impacts, [intensity])
        }
    }

    // MARK: - Milestones

    func testMilestoneCuesFireOnlyAtTheDocumentedCombos() {
        // GAMEPLAY §16 names 2, 4, 7, 10.
        for count in 1...12 {
            let sut = makeSUT()
            play(sut, comboCount: count)

            let expected = GameConfiguration.Combo.milestoneCounts.contains(count) ? 1 : 0
            XCTAssertEqual(sut.audio.milestones, expected, "combo \(count) audio")
            XCTAssertEqual(sut.haptics.milestones, expected, "combo \(count) haptic")
        }
    }

    func testMilestonesUseExactCountsSoTheyFireOnceNotForever() {
        // An "at or above 10" rule would fire the major cue on every hit for the
        // rest of the rally, which is precisely §16's "do not overwhelm".
        let sut = makeSUT()

        play(sut, comboCount: 10, multiplier: 10, emphasis: .major)
        play(sut, comboCount: 11, multiplier: 10, emphasis: .major)
        play(sut, comboCount: 12, multiplier: 10, emphasis: .major)

        XCTAssertEqual(sut.audio.milestones, 1)
    }

    func testEveryMilestoneCountIsReachableOnTheComboLadder() {
        // A milestone above the ladder's top rung would never fire.
        let maximumRung = GameConfiguration.Combo.multiplierLadder
            .map(\.minimumCount)
            .max() ?? 0

        for milestone in GameConfiguration.Combo.milestoneCounts {
            XCTAssertLessThanOrEqual(milestone, maximumRung, "Milestone \(milestone) unreachable.")
        }
    }

    func testTheFirstHitOfARallyIsNotAMilestone() {
        let sut = makeSUT()

        play(sut, comboCount: 1)

        // Combo 1 pays 1x — nothing has been achieved yet.
        XCTAssertEqual(sut.audio.milestones, 0)
    }
}
