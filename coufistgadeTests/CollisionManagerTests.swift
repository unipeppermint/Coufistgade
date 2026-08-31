//
//  CollisionManagerTests.swift
//  coufistgadeTests
//
//  SKPhysicsContact cannot be constructed, so the interpretation logic is
//  tested through the static seams and the wiring through one real physics
//  contact at the bottom of the file.
//

import XCTest
import SpriteKit
@testable import coufistgade

final class CollisionManagerTests: XCTestCase {

    private let right = CGVector(dx: 1, dy: 0)

    // MARK: - Impact speed

    func testHeadOnImpactReportsTheFullClosingSpeed() {
        let speed = CollisionManager.separationSpeed(
            playerVelocity: CGVector(dx: 600, dy: 0),
            normalVelocity: .zero,
            contactNormal: right
        )

        XCTAssertEqual(speed, 600, accuracy: 0.001)
    }

    func testClosingSpeedIsRelativeNotAbsolute() {
        // A ball fleeing at nearly the player's speed is barely touched, even
        // though the player is moving fast.
        let speed = CollisionManager.separationSpeed(
            playerVelocity: CGVector(dx: 600, dy: 0),
            normalVelocity: CGVector(dx: 560, dy: 0),
            contactNormal: right
        )

        XCTAssertEqual(speed, 40, accuracy: 0.001)
    }

    func testGlancingBlowIsNotGradedAsAHardHit() {
        // The whole reason for projecting onto the normal: 2000 pt/s of relative
        // motion, all of it sideways, is a graze and must not read as a smash.
        let speed = CollisionManager.separationSpeed(
            playerVelocity: CGVector(dx: 0, dy: 2000),
            normalVelocity: .zero,
            contactNormal: right
        )

        XCTAssertEqual(speed, 0, accuracy: 0.001)
        XCTAssertNil(ImpactIntensity(impactSpeed: speed))
    }

    func testResultDoesNotDependOnWhichBodySpriteKitCalledBodyA() {
        let forward = CollisionManager.separationSpeed(
            playerVelocity: CGVector(dx: 600, dy: 0),
            normalVelocity: .zero,
            contactNormal: right
        )
        let reversed = CollisionManager.separationSpeed(
            playerVelocity: CGVector(dx: 600, dy: 0),
            normalVelocity: .zero,
            contactNormal: CGVector(dx: -1, dy: 0)
        )

        XCTAssertEqual(forward, reversed, accuracy: 0.001)
    }

    func testUnnormalisedContactNormalStillYieldsPointsPerSecond() {
        // contactNormal is documented as a unit vector; not relying on that
        // keeps the value in real units if it ever is not.
        let speed = CollisionManager.separationSpeed(
            playerVelocity: CGVector(dx: 600, dy: 0),
            normalVelocity: .zero,
            contactNormal: CGVector(dx: 17, dy: 0)
        )

        XCTAssertEqual(speed, 600, accuracy: 0.001)
    }

    func testDegenerateContactNormalProducesZeroNotNaN() {
        let speed = CollisionManager.separationSpeed(
            playerVelocity: CGVector(dx: 600, dy: 0),
            normalVelocity: .zero,
            contactNormal: .zero
        )

        XCTAssertFalse(speed.isNaN)
        XCTAssertEqual(speed, 0)
    }

    func testDiagonalImpactUsesOnlyTheNormalComponent() {
        // 45° into the surface: exactly half the speed closes the gap.
        let unit = CGFloat(1 / 2.0.squareRoot())
        let diagonal = CGVector(dx: unit, dy: unit)
        let speed = CollisionManager.separationSpeed(
            playerVelocity: CGVector(dx: 1000, dy: 0),
            normalVelocity: .zero,
            contactNormal: diagonal
        )

        XCTAssertEqual(speed, 1000 * unit, accuracy: 0.001)
    }

    // MARK: - Recovering approach speed

    func testApproachSpeedUndoesTheBounceTheSolverAlreadyApplied() {
        // didBegin sees post-collision velocities, so a 1000 pt/s approach is
        // reported as 820. Grading must work from the 1000.
        let reported = 1000 * GameConfiguration.Physics.ballRestitution

        XCTAssertEqual(CollisionManager.approachSpeed(fromSeparation: reported), 1000,
                       accuracy: 0.001)
    }

    func testApproachSpeedIsNeverSmallerThanWhatWasReported() {
        // Restitution is at most 1, so the correction can only scale upward.
        for separation in stride(from: CGFloat(0), through: 2000, by: 100) {
            XCTAssertGreaterThanOrEqual(
                CollisionManager.approachSpeed(fromSeparation: separation),
                separation
            )
        }
    }

    func testPerfectlyInelasticBallsWouldNotDivideByZero() {
        // Guards a plausible Phase 15 tuning value rather than a fantasy one.
        XCTAssertEqual(CollisionManager.approachSpeed(fromSeparation: 0), 0)
        XCTAssertGreaterThan(GameConfiguration.Physics.ballRestitution, 0)
    }

    // MARK: - Intensity grading

    func testSpeedsBelowTheGrazeThresholdAreNotEventsAtAll() {
        let graze = GameConfiguration.Collision.grazeSpeed

        XCTAssertNil(ImpactIntensity(impactSpeed: 0))
        XCTAssertNil(ImpactIntensity(impactSpeed: graze - 1))
        XCTAssertNotNil(ImpactIntensity(impactSpeed: graze))
    }

    func testEachTierCoversItsConfiguredBand() {
        let config = GameConfiguration.Collision.self

        XCTAssertEqual(ImpactIntensity(impactSpeed: config.grazeSpeed), .low)
        XCTAssertEqual(ImpactIntensity(impactSpeed: config.mediumImpactSpeed - 1), .low)
        XCTAssertEqual(ImpactIntensity(impactSpeed: config.mediumImpactSpeed), .medium)
        XCTAssertEqual(ImpactIntensity(impactSpeed: config.highImpactSpeed - 1), .medium)
        XCTAssertEqual(ImpactIntensity(impactSpeed: config.highImpactSpeed), .high)
        XCTAssertEqual(ImpactIntensity(impactSpeed: 99_999), .high)
    }

    func testDriftingBallsCannotScoreAgainstAParkedPlayer() {
        // Normal balls drift forever by design. If the graze floor sat inside
        // their speed band, an idle player would collect free hits.
        let fastestDrift = GameConfiguration.Ball.normalDriftSpeedRange.upperBound
        let approach = CollisionManager.approachSpeed(
            fromSeparation: fastestDrift * GameConfiguration.Physics.ballRestitution
        )

        XCTAssertNil(
            ImpactIntensity(impactSpeed: approach),
            "A ball drifting at its top speed into a still player registered a hit."
        )
    }

    func testTheTiersDivideTheThrowRangeRatherThanSaturatingAtTheTop() {
        let config = GameConfiguration.Collision.self
        let cap = GameConfiguration.Input.maximumThrowSpeed

        // High must take real commitment. At 400/1000 it began around half the
        // usable throw range, so the loudest feedback in the game was the
        // default for any hard throw (GAMEPLAY §12 calls High "additional
        // visual emphasis" — emphasis has to be uncommon to read as emphasis).
        XCTAssertGreaterThan(config.highImpactSpeed / cap, 0.5, "High is too easy to reach.")
        XCTAssertLessThan(config.highImpactSpeed / cap, 0.8, "High is out of practical reach.")

        // And Medium must not swallow the middle either.
        XCTAssertGreaterThan(config.mediumImpactSpeed / cap, 0.2)
        XCTAssertLessThan(config.mediumImpactSpeed / cap, 0.45)
    }

    func testEachTierOwnsAComparableSliceOfTheThrowRange() {
        let config = GameConfiguration.Collision.self
        let cap = GameConfiguration.Input.maximumThrowSpeed

        let low = config.mediumImpactSpeed - config.grazeSpeed
        let medium = config.highImpactSpeed - config.mediumImpactSpeed
        let high = cap - config.highImpactSpeed

        // Not equal thirds, but none should be less than half the widest.
        let widest = max(low, max(medium, high))
        for (name, width) in [("low", low), ("medium", medium), ("high", high)] {
            XCTAssertGreaterThan(width / widest, 0.5, "The \(name) band is too narrow to feel.")
        }
    }

    func testThresholdsAreOrderedSoNoTierIsUnreachable() {
        let config = GameConfiguration.Collision.self

        XCTAssertLessThan(config.grazeSpeed, config.mediumImpactSpeed)
        XCTAssertLessThan(config.mediumImpactSpeed, config.highImpactSpeed)
        // Every tier must be produced by some speed, or grading is a lie.
        let produced = Set(
            stride(from: CGFloat(0), through: 2000, by: 5)
                .compactMap { ImpactIntensity(impactSpeed: $0) }
        )
        XCTAssertEqual(produced, Set(ImpactIntensity.allCases))
    }

    func testIntensitiesCompareInSeverityOrder() {
        // Downstream feedback scales with this ordering.
        XCTAssertLessThan(ImpactIntensity.low, .medium)
        XCTAssertLessThan(ImpactIntensity.medium, .high)
        XCTAssertEqual(ImpactIntensity.allCases.max(), .high)
    }

    // MARK: - Repeat suppression

    func testFirstHitOnABallIsAlwaysAccepted() {
        let sut = CollisionManager()
        let ball = ObjectIdentifier(NSObject())

        XCTAssertTrue(sut.accept(ball, at: 0))
    }

    func testResettlingContactsWithinTheCooldownAreDropped() {
        let sut = CollisionManager()
        let object = NSObject()
        let ball = ObjectIdentifier(object)
        let cooldown = GameConfiguration.Collision.repeatContactCooldown

        XCTAssertTrue(sut.accept(ball, at: 10))
        // Two balls resting together re-contact every frame.
        for frame in 1...8 {
            XCTAssertFalse(
                sut.accept(ball, at: 10 + Double(frame) / 60),
                "Frame \(frame) leaked an event inside the \(cooldown)s cooldown."
            )
        }
    }

    func testAGenuineSecondHitAfterTheCooldownCounts() {
        let sut = CollisionManager()
        let object = NSObject()
        let ball = ObjectIdentifier(object)
        let cooldown = GameConfiguration.Collision.repeatContactCooldown

        XCTAssertTrue(sut.accept(ball, at: 10))
        XCTAssertTrue(sut.accept(ball, at: 10 + cooldown))
    }

    func testCooldownIsPerBallSoOneHitDoesNotMuteTheField() {
        let sut = CollisionManager()
        let objects = (0..<3).map { _ in NSObject() }
        let balls = objects.map(ObjectIdentifier.init)

        // Ploughing through a cluster must score every ball in it.
        XCTAssertTrue(sut.accept(balls[0], at: 5))
        XCTAssertTrue(sut.accept(balls[1], at: 5.01))
        XCTAssertTrue(sut.accept(balls[2], at: 5.02))
        XCTAssertFalse(sut.accept(balls[0], at: 5.03))
    }

    func testCooldownIsShorterThanTheComboWindow() {
        // A cooldown at or beyond the combo window would make chaining hits on
        // one ball impossible, silently capping the combo system in Phase 9.
        XCTAssertLessThan(GameConfiguration.Collision.repeatContactCooldown, 2.0)
    }
}
