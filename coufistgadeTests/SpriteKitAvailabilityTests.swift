//
//  SpriteKitAvailabilityTests.swift
//  coufistgadeTests
//
//  Phase 1 guard: SpriteKit is linked and usable inside the app process.
//  Phase 3 replaces these with real GameScene tests.
//

import XCTest
import SpriteKit
@testable import coufistgade

final class SpriteKitAvailabilityTests: XCTestCase {

    func testSKViewPresentsSceneInHostProcess() {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let scene = SKScene(size: view.bounds.size)

        view.presentScene(scene)

        XCTAssertIdentical(view.scene, scene)
        XCTAssertEqual(scene.size, CGSize(width: 320, height: 480))
    }

    func testPhysicsWorldIsReachableAndConfigurable() {
        let scene = SKScene(size: CGSize(width: 100, height: 100))

        // Phase 3 owns the real values; this only proves the physics stack is linked.
        scene.physicsWorld.gravity = CGVector(dx: 0, dy: 0)

        XCTAssertEqual(scene.physicsWorld.gravity.dx, 0, accuracy: .ulpOfOne)
        XCTAssertEqual(scene.physicsWorld.gravity.dy, 0, accuracy: .ulpOfOne)
    }
}
