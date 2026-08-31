//
//  BallNodeTests.swift
//  coufistgadeTests
//

import XCTest
import SpriteKit
@testable import coufistgade

final class BallNodeTests: XCTestCase {

    // MARK: - Physics parameters

    func testPlayerBallUsesConfiguredMaterial() throws {
        let sut = BallNode(kind: .player)
        let body = try XCTUnwrap(sut.physicsBody)

        // SKPhysicsBody stores these as 32-bit floats, so a CGFloat round trip
        // is not bit-exact — compare with float tolerance, not equality.
        let tolerance = CGFloat(Float.ulpOfOne)
        XCTAssertEqual(body.friction, GameConfiguration.Physics.ballFriction, accuracy: tolerance)
        XCTAssertEqual(
            body.restitution,
            GameConfiguration.Physics.ballRestitution,
            accuracy: tolerance
        )
        XCTAssertEqual(
            body.linearDamping,
            GameConfiguration.Physics.ballLinearDamping,
            accuracy: tolerance
        )
        XCTAssertEqual(
            body.angularDamping,
            GameConfiguration.Physics.ballAngularDamping,
            accuracy: tolerance
        )
        XCTAssertEqual(body.density, GameConfiguration.Physics.ballDensity, accuracy: tolerance)
    }

    func testBallIsDynamicAndSpinsButIgnoresGravity() throws {
        let sut = BallNode(kind: .player)
        let body = try XCTUnwrap(sut.physicsBody)

        XCTAssertTrue(body.isDynamic)
        // angularDamping is meaningless without rotation.
        XCTAssertTrue(body.allowsRotation)
        XCTAssertFalse(body.affectedByGravity)
    }

    func testBallUsesPreciseCollisionDetection() throws {
        let sut = BallNode(kind: .player)
        let body = try XCTUnwrap(sut.physicsBody)

        // GAMEPLAY §9: no tunnelling at speed.
        XCTAssertTrue(body.usesPreciseCollisionDetection)
    }

    func testBallHasNonZeroMassDerivedFromDensity() throws {
        let sut = BallNode(kind: .player)
        let body = try XCTUnwrap(sut.physicsBody)

        // A zero-mass dynamic body would not transfer momentum on impact.
        XCTAssertGreaterThan(body.mass, 0)
    }

    // MARK: - Collision wiring

    func testBallsCollideWithWallsAndEachOther() throws {
        for kind in [BallNode.Kind.player, .normal] {
            let body = try XCTUnwrap(BallNode(kind: kind).physicsBody)

            XCTAssertEqual(body.categoryBitMask, kind.categoryBitMask)
            XCTAssertEqual(
                body.collisionBitMask,
                PhysicsCategory.boundary | PhysicsCategory.allBalls
            )
        }
    }

    func testOnlyThePlayerBallReportsContacts() throws {
        // Physical collision is independent of contact *reporting*. Reporting
        // is declared on the player side alone, so a wall bounce or two normal
        // balls drifting together can never reach the scoring path.
        let player = try XCTUnwrap(BallNode(kind: .player).physicsBody)
        let normal = try XCTUnwrap(BallNode(kind: .normal).physicsBody)

        XCTAssertEqual(player.contactTestBitMask, PhysicsCategory.normalBall)
        XCTAssertEqual(normal.contactTestBitMask, PhysicsCategory.none)
        XCTAssertEqual(player.contactTestBitMask & PhysicsCategory.boundary, 0)
        XCTAssertEqual(player.contactTestBitMask & PhysicsCategory.playerBall, 0)
    }

    func testKindsCarryDistinctCategories() {
        XCTAssertEqual(BallNode.Kind.player.categoryBitMask, PhysicsCategory.playerBall)
        XCTAssertEqual(BallNode.Kind.normal.categoryBitMask, PhysicsCategory.normalBall)
        XCTAssertNotEqual(
            BallNode.Kind.player.categoryBitMask,
            BallNode.Kind.normal.categoryBitMask
        )
    }

    // MARK: - Geometry

    func testPhysicalRadiusComesFromConfiguredDiameterNotSpriteSize() {
        let sut = BallNode(kind: .player)

        XCTAssertEqual(sut.physicalRadius, GameConfiguration.Ball.playerDiameter / 2)
        // The sprite is padded for the baked-in glow, so it must be larger.
        // Confusing the two would inflate the hitbox.
        XCTAssertGreaterThan(sut.size.width, GameConfiguration.Ball.playerDiameter)
        XCTAssertEqual(
            sut.size.width,
            GameConfiguration.Ball.playerDiameter + GameConfiguration.Ball.glowPadding * 2,
            accuracy: .ulpOfOne
        )
    }

    func testPlayerBallIsLargerThanNormalBall() {
        // GAMEPLAY §4: the player ball is slightly larger.
        XCTAssertGreaterThan(BallNode.Kind.player.diameter, BallNode.Kind.normal.diameter)
    }

    func testSpriteIsSquareSoTheBallIsNotOval() {
        let sut = BallNode(kind: .player)

        XCTAssertEqual(sut.size.width, sut.size.height, accuracy: .ulpOfOne)
    }

    // MARK: - Rendering

    func testBothKindsProduceATexture() {
        XCTAssertNotNil(BallNode(kind: .player).texture)
        XCTAssertNotNil(BallNode(kind: .normal).texture)
    }

    func testTextureIsSharedBetweenBallsOfTheSameKind() {
        let first = BallNode(kind: .normal)
        let second = BallNode(kind: .normal)

        // Shared textures let the renderer batch balls into one draw call
        // (ARCHITECTURE §25).
        XCTAssertIdentical(first.texture, second.texture)
    }

    func testOnlyThePlayerBallGlows() {
        // GAMEPLAY §4: the player ball gets the stronger visual treatment.
        XCTAssertGreaterThan(BallNode.Kind.player.glowOpacity, 0)
        XCTAssertEqual(BallNode.Kind.normal.glowOpacity, 0)
    }
}
