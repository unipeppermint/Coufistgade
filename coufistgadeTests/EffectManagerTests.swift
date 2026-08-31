//
//  EffectManagerTests.swift
//  coufistgadeTests
//

import XCTest
import SpriteKit
@testable import coufistgade

final class EffectManagerTests: XCTestCase {

    private func makeCollision(
        _ intensity: ImpactIntensity,
        at point: CGPoint = CGPoint(x: 100, y: 200)
    ) -> BallCollision {
        BallCollision(
            playerBall: BallNode(kind: .player),
            normalBall: BallNode(kind: .normal),
            point: point,
            impactSpeed: 500,
            intensity: intensity
        )
    }

    private func emitters(in node: SKNode) -> [SKEmitterNode] {
        node.children.compactMap { $0 as? SKEmitterNode }
    }

    private func labels(in node: SKNode) -> [SKLabelNode] {
        node.children.compactMap { $0 as? SKLabelNode }
    }

    private func rgba(_ colour: UIColor) -> [CGFloat] {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        colour.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [red, green, blue, alpha].map { ($0 * 1000).rounded() / 1000 }
    }

    // MARK: - Impact particles

    func testAnImpactEmitsABurstAtTheContactPoint() throws {
        let container = SKNode()
        let sut = EffectManager(container: container, prefersReducedMotion: { false })
        let point = CGPoint(x: 42, y: 84)

        sut.playImpact(makeCollision(.medium, at: point))

        let emitter = try XCTUnwrap(emitters(in: container).first)
        XCTAssertEqual(emitter.position, point)
    }

    func testTheBurstIsFiniteNotAContinuousStream() throws {
        let container = SKNode()
        let sut = EffectManager(container: container, prefersReducedMotion: { false })

        sut.playImpact(makeCollision(.high))

        // A stream would keep emitting for as long as the node lived and pile
        // particles up through a rally.
        let emitter = try XCTUnwrap(emitters(in: container).first)
        XCTAssertGreaterThan(emitter.numParticlesToEmit, 0)
    }

    func testParticleCountScalesWithIntensity() throws {
        var counts: [Int] = []

        for intensity in ImpactIntensity.allCases {
            let container = SKNode()
            let sut = EffectManager(container: container, prefersReducedMotion: { false })
            sut.playImpact(makeCollision(intensity))
            counts.append(try XCTUnwrap(emitters(in: container).first).numParticlesToEmit)
        }

        // GAMEPLAY §11: feedback should scale with impact intensity.
        XCTAssertEqual(counts, counts.sorted())
        XCTAssertLessThan(counts.first!, counts.last!)
    }

    func testParticlesTakeTheirColourFromTheBallTheyCameFrom() throws {
        let container = SKNode()
        let sut = EffectManager(container: container, prefersReducedMotion: { false })
        let collision = makeCollision(.low)

        sut.playImpact(collision)

        // UI_DESIGN §12: particle colour should match the ball.
        //
        // Compared by component, not by object: SpriteKit re-encodes the colour
        // into its own space on assignment, so the UIColors differ even when the
        // values are identical.
        let emitter = try XCTUnwrap(emitters(in: container).first)
        XCTAssertEqual(
            rgba(emitter.particleColor),
            rgba(collision.normalBall.kind.highlightColor)
        )
    }

    func testEmittersShareOneTexture() throws {
        let container = SKNode()
        let sut = EffectManager(container: container, prefersReducedMotion: { false })

        sut.playImpact(makeCollision(.low))
        sut.playImpact(makeCollision(.high))

        // Per-instance textures cannot batch, and this is the hot path.
        let textures = emitters(in: container).compactMap(\.particleTexture)
        XCTAssertEqual(textures.count, 2)
        XCTAssertIdentical(textures[0], textures[1])
    }

    // MARK: - Cleanup

    func testEveryEmitterCarriesItsOwnRemoval() throws {
        let container = SKNode()
        let sut = EffectManager(container: container, prefersReducedMotion: { false })

        sut.playImpact(makeCollision(.medium))

        // Nothing else removes these, so a burst without an action would leak
        // a node per hit for the whole round.
        let emitter = try XCTUnwrap(emitters(in: container).first)
        XCTAssertTrue(emitter.hasActions())
    }

    func testEveryPopupCarriesItsOwnRemoval() throws {
        let container = SKNode()
        let sut = EffectManager(container: container, prefersReducedMotion: { false })

        sut.playScorePopup(ScoreEvent(points: 10, total: 10, multiplier: 1), at: .zero)

        XCTAssertTrue(try XCTUnwrap(labels(in: container).first).hasActions())
    }

    func testPopupsAlsoCleanThemselvesUpUnderReduceMotion() throws {
        let container = SKNode()
        let sut = EffectManager(container: container, prefersReducedMotion: { true })

        sut.playScorePopup(ScoreEvent(points: 10, total: 10, multiplier: 1), at: .zero)

        // The Reduce Motion branch is a different action sequence, so it needs
        // its own guarantee that the node still leaves.
        XCTAssertTrue(try XCTUnwrap(labels(in: container).first).hasActions())
    }

    // MARK: - Score popup

    func testPopupShowsThePointsEarnedNotTheTotal() throws {
        let container = SKNode()
        let sut = EffectManager(container: container, prefersReducedMotion: { false })

        sut.playScorePopup(ScoreEvent(points: 30, total: 250, multiplier: 3), at: .zero)

        XCTAssertEqual(try XCTUnwrap(labels(in: container).first).text, "+30")
    }

    func testPopupAppearsWhereTheHitHappened() throws {
        let container = SKNode()
        let sut = EffectManager(container: container, prefersReducedMotion: { false })
        let point = CGPoint(x: 210, y: 480)

        sut.playScorePopup(ScoreEvent(points: 10, total: 10, multiplier: 1), at: point)

        XCTAssertEqual(try XCTUnwrap(labels(in: container).first).position, point)
    }

    func testAMultipliedScoreIsVisuallyDistinct() throws {
        let container = SKNode()
        let sut = EffectManager(container: container, prefersReducedMotion: { false })

        sut.playScorePopup(ScoreEvent(points: 10, total: 10, multiplier: 1), at: .zero)
        sut.playScorePopup(ScoreEvent(points: 50, total: 60, multiplier: 5), at: .zero)

        let popups = labels(in: container)
        XCTAssertEqual(popups.count, 2)
        // A combo hit is worth more, so it should not look identical.
        XCTAssertNotEqual(popups[0].fontColor, popups[1].fontColor)
        XCTAssertLessThan(popups[0].fontSize, popups[1].fontSize)
    }

    // MARK: - Reduce Motion

    func testReduceMotionSuppressesParticles() {
        let container = SKNode()
        let sut = EffectManager(container: container, prefersReducedMotion: { true })

        sut.playImpact(makeCollision(.high))

        XCTAssertTrue(emitters(in: container).isEmpty)
    }

    func testReduceMotionStillShowsTheScore() throws {
        let container = SKNode()
        let sut = EffectManager(container: container, prefersReducedMotion: { true })

        sut.playScorePopup(ScoreEvent(points: 20, total: 20, multiplier: 2), at: .zero)

        // The setting objects to motion, not to information.
        XCTAssertEqual(try XCTUnwrap(labels(in: container).first).text, "+20")
    }

    func testReduceMotionSuppressesTheComboPulse() {
        let container = SKNode()
        let sut = EffectManager(container: container, prefersReducedMotion: { true })
        let ball = BallNode(kind: .player)
        container.addChild(ball)

        sut.playComboEmphasis(
            ComboEvent(count: 10, multiplier: 10, emphasis: .major, isVisible: true),
            on: ball
        )

        XCTAssertFalse(ball.hasActions())
    }

    // MARK: - Combo emphasis

    func testOrdinaryCombosDoNotPulseTheBall() {
        let container = SKNode()
        let sut = EffectManager(container: container, prefersReducedMotion: { false })
        let ball = BallNode(kind: .player)

        sut.playComboEmphasis(
            ComboEvent(count: 2, multiplier: 2, emphasis: .normal, isVisible: true),
            on: ball
        )

        // GAMEPLAY §16 reserves the escalation for 4 and 10; pulsing on every
        // combo would overwhelm the player, which §16 explicitly warns against.
        XCTAssertFalse(ball.hasActions())
    }

    func testStrongAndMajorCombosPulseTheBall() {
        let container = SKNode()
        let sut = EffectManager(container: container, prefersReducedMotion: { false })

        for emphasis in [ComboEmphasis.strong, .major] {
            let ball = BallNode(kind: .player)
            sut.playComboEmphasis(
                ComboEvent(count: 4, multiplier: 3, emphasis: emphasis, isVisible: true),
                on: ball
            )
            XCTAssertTrue(ball.hasActions(), "\(emphasis) produced no pulse.")
        }
    }

    func testARapidSecondMilestoneReplacesThePulseRatherThanQueueing() {
        let container = SKNode()
        let sut = EffectManager(container: container, prefersReducedMotion: { false })
        let ball = BallNode(kind: .player)
        let event = ComboEvent(count: 4, multiplier: 3, emphasis: .strong, isVisible: true)

        sut.playComboEmphasis(event, on: ball)
        sut.playComboEmphasis(event, on: ball)

        // Queued pulses would leave the ball briefly oversized; a keyed action
        // replaces the previous one.
        XCTAssertTrue(ball.hasActions())
        XCTAssertNotNil(ball.action(forKey: "combo.pulse"))
    }
}
