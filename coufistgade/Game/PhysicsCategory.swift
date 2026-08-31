//
//  PhysicsCategory.swift
//  coufistgade
//
//  Physics category bitmasks (ARCHITECTURE §10).
//  The boundary is the only category with a body in Phase 3; the ball
//  categories are declared alongside it because a bitmask is only meaningful
//  relative to the others it is tested against.
//

import Foundation

enum PhysicsCategory {
    static let none: UInt32 = 0
    static let boundary: UInt32 = 1 << 0
    static let playerBall: UInt32 = 1 << 1
    static let normalBall: UInt32 = 1 << 2

    static let allBalls: UInt32 = playerBall | normalBall
}
