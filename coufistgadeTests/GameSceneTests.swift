//
//  GameSceneTests.swift
//  coufistgadeTests
//

import XCTest
import SpriteKit
@testable import coufistgade

final class GameSceneTests: XCTestCase {

    private let sceneSize = CGSize(width: 393, height: 852)

    /// A scene only builds its world in didMove(to:), so tests need a real
    /// SKView to present into.
    private func makeSUT(
        insets: UIEdgeInsets = .zero
    ) -> (scene: GameScene, view: SKView) {
        let view = SKView(frame: CGRect(origin: .zero, size: sceneSize))
        let scene = GameScene(size: sceneSize)
        scene.scaleMode = .resizeFill
        scene.updatePlayableInsets(insets)
        view.presentScene(scene)
        return (scene, view)
    }

    private func boundaryNode(in scene: GameScene) -> SKNode? {
        scene.childNode(withName: "boundary")
    }

    // MARK: - Physics world

    func testGravityMatchesConfiguration() {
        let (scene, _) = makeSUT()

        XCTAssertEqual(scene.physicsWorld.gravity.dx, GameConfiguration.Physics.gravity.dx)
        XCTAssertEqual(scene.physicsWorld.gravity.dy, GameConfiguration.Physics.gravity.dy)
    }

    // MARK: - Boundary

    func testBoundaryExistsAndIsAnEdgeLoop() throws {
        let (scene, _) = makeSUT()
        let boundary = try XCTUnwrap(boundaryNode(in: scene))
        let body = try XCTUnwrap(boundary.physicsBody)

        // An edge loop is immovable and massless; a volume body would not be.
        XCTAssertFalse(body.isDynamic)
        XCTAssertEqual(body.mass, 0, accuracy: .ulpOfOne)
    }

    func testBoundaryCollidesWithBallsButReportsNoContacts() throws {
        let (scene, _) = makeSUT()
        let body = try XCTUnwrap(boundaryNode(in: scene)?.physicsBody)

        XCTAssertEqual(body.categoryBitMask, PhysicsCategory.boundary)
        XCTAssertEqual(body.collisionBitMask, PhysicsCategory.allBalls)
        XCTAssertEqual(body.contactTestBitMask, PhysicsCategory.none)
    }

    func testBoundaryUsesConfiguredMaterial() throws {
        let (scene, _) = makeSUT()
        let body = try XCTUnwrap(boundaryNode(in: scene)?.physicsBody)

        XCTAssertEqual(body.friction, GameConfiguration.Physics.boundaryFriction)
        XCTAssertEqual(body.restitution, GameConfiguration.Physics.boundaryRestitution)
    }

    func testPlayableRectIsInsetFromSafeArea() {
        let insets = UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
        let (scene, _) = makeSUT(insets: insets)
        let inset = GameConfiguration.World.boundaryInset

        let rect = scene.playableRect

        XCTAssertEqual(rect.minY, insets.bottom + inset, accuracy: .ulpOfOne)
        XCTAssertEqual(
            rect.height,
            sceneSize.height - insets.top - insets.bottom - inset * 2,
            accuracy: .ulpOfOne
        )
        XCTAssertEqual(rect.width, sceneSize.width - inset * 2, accuracy: .ulpOfOne)
    }

    func testPlayableRectStaysInsideSceneBounds() {
        let insets = UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
        let (scene, _) = makeSUT(insets: insets)

        let rect = scene.playableRect

        XCTAssertTrue(CGRect(origin: .zero, size: sceneSize).contains(rect))
    }

    func testBoundaryRebuildsWhenInsetsChange() throws {
        let (scene, _) = makeSUT()
        let boundary = try XCTUnwrap(boundaryNode(in: scene) as? BoundaryNode)
        let before = boundary.enclosedRect

        scene.updatePlayableInsets(UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0))

        // The node persists and re-encloses; what matters is that the wall
        // actually moved to the new rect.
        XCTAssertNotEqual(before, boundary.enclosedRect)
        XCTAssertEqual(boundary.enclosedRect, scene.playableRect)
        XCTAssertEqual(scene.children.filter { $0.name == "boundary" }.count, 1)
    }

    func testRepeatedInsetUpdatesDoNotAccumulateNodes() {
        let (scene, _) = makeSUT()

        for i in 1...5 {
            scene.updatePlayableInsets(UIEdgeInsets(top: CGFloat(i), left: 0, bottom: 0, right: 0))
        }

        XCTAssertEqual(scene.children.filter { $0.name == "boundary" }.count, 1)
    }

    func testIdenticalInsetUpdateIsIgnored() throws {
        let insets = UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
        let (scene, _) = makeSUT(insets: insets)
        let before = try XCTUnwrap(boundaryNode(in: scene))

        scene.updatePlayableInsets(insets)

        XCTAssertIdentical(before, boundaryNode(in: scene), "Redundant update rebuilt the edge.")
    }

    func testZeroSizedSceneProducesNoPhysicsEdge() {
        let view = SKView(frame: .zero)
        let scene = GameScene(size: .zero)
        view.presentScene(scene)

        // Degenerate geometry must leave the wall bodyless rather than build an
        // invalid physics body.
        XCTAssertNil(boundaryNode(in: scene)?.physicsBody)
    }

    // MARK: - Background

    func testBackgroundSitsBehindEverythingAndFillsTheScene() throws {
        let (scene, _) = makeSUT()
        let background = try XCTUnwrap(scene.childNode(withName: "background") as? SKSpriteNode)

        XCTAssertLessThan(background.zPosition, 0)
        XCTAssertEqual(background.size, sceneSize)
        XCTAssertNotNil(background.texture)
    }

    // MARK: - World contents

    func testEveryDynamicBodyIsABall() {
        let (scene, _) = makeSUT()

        // Guards against stray physics bodies entering the world: the only
        // moving things should be the player ball plus the normal balls.
        let dynamicNodes = scene.children.filter { $0.physicsBody?.isDynamic == true }
        XCTAssertTrue(dynamicNodes.allSatisfy { $0 is BallNode })
        XCTAssertEqual(
            dynamicNodes.count,
            1 + scene.children.compactMap { $0 as? BallNode }.filter { $0.kind == .normal }.count
        )
    }
}
