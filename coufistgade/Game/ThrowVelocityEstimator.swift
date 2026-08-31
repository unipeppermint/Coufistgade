//
//  ThrowVelocityEstimator.swift
//  coufistgade
//
//  Turns a stream of drag samples into a release velocity.
//
//  Deliberately free of SpriteKit and UITouch: it takes points and timestamps,
//  so the throw maths can be unit-tested without a running scene or a real
//  finger (ARCHITECTURE §26 lists physics/touch as manual-test territory
//  precisely because it usually is not testable — this part can be).
//

import CoreGraphics
import Foundation

struct ThrowVelocityEstimator {

    struct Sample {
        let point: CGPoint
        let time: TimeInterval
    }

    /// Enough history to cover the trailing window several times over at 60Hz,
    /// while staying bounded during a long drag.
    private static let maximumSamples = 16

    private var samples: [Sample] = []

    mutating func reset() {
        samples.removeAll(keepingCapacity: true)
    }

    mutating func record(point: CGPoint, time: TimeInterval) {
        samples.append(Sample(point: point, time: time))
        if samples.count > Self.maximumSamples {
            samples.removeFirst(samples.count - Self.maximumSamples)
        }
    }

    /// Velocity in points per second at the moment of release.
    ///
    /// The window is measured back from `releaseTime`, not from the newest
    /// sample. That distinction is the whole point: `touchesMoved` stops firing
    /// while a finger rests, so anchoring to the last sample would resurrect
    /// stale motion and fling a ball the player had deliberately parked.
    func velocity(releasePoint: CGPoint, releaseTime: TimeInterval) -> CGVector {
        let cutoff = releaseTime - GameConfiguration.Input.throwSampleWindow

        // Oldest sample still inside the window, and the one just before it, so
        // a gesture with few samples still has a baseline to measure from.
        guard let anchor = samples.last(where: { $0.time <= cutoff })
            ?? samples.first(where: { $0.time > cutoff })
        else {
            return .zero
        }

        let elapsed = releaseTime - anchor.time
        guard elapsed > 0 else { return .zero }

        return CGVector(
            dx: (releasePoint.x - anchor.point.x) / CGFloat(elapsed),
            dy: (releasePoint.y - anchor.point.y) / CGFloat(elapsed)
        )
    }

    /// Applies the dead zone and the ceiling from GAMEPLAY §7.
    static func clamped(_ velocity: CGVector) -> CGVector {
        let speed = hypot(velocity.dx, velocity.dy)

        guard speed >= GameConfiguration.Input.minimumThrowSpeed else {
            // A near-still release places the ball rather than throwing it.
            return .zero
        }
        guard speed > GameConfiguration.Input.maximumThrowSpeed else {
            return velocity
        }

        let scale = GameConfiguration.Input.maximumThrowSpeed / speed
        return CGVector(dx: velocity.dx * scale, dy: velocity.dy * scale)
    }
}
