//
//  PerformanceTests.swift
//  coufistgadeTests
//
//  ROADMAP Phase 16. Measures frame-time distribution rather than average FPS:
//  an average of 60 can hide a 200ms stall, and it is the stall the player feels.
//
//  Absolute numbers are simulator numbers — a device has a real GPU and a
//  thermal budget. What transfers is the *shape*: whether worst-case frames stay
//  near the budget, and whether node count and memory return to baseline.
//

import XCTest
import SpriteKit
@testable import coufistgade

final class PerformanceTests: XCTestCase {

    /// Frame budget at 60Hz. Anything past this dropped a frame.
    private let budget: TimeInterval = 1.0 / 60

    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    // MARK: - Harness

    private final class FrameTimer: GameSceneFrameObserver {
        private(set) var intervals: [TimeInterval] = []
        private var last: Date?

        func gameSceneDidUpdate() {
            let now = Date()
            if let last { intervals.append(now.timeIntervalSince(last)) }
            self.last = now
        }

        /// Drops the first few frames: presenting a scene bakes textures and
        /// warms the render pipeline, which is startup cost, not steady state.
        var steady: [TimeInterval] { Array(intervals.dropFirst(10)) }

        func percentile(_ p: Double) -> TimeInterval {
            let sorted = steady.sorted()
            guard !sorted.isEmpty else { return 0 }
            return sorted[min(sorted.count - 1, Int(Double(sorted.count - 1) * p))]
        }

        var worst: TimeInterval { steady.max() ?? 0 }
        var mean: TimeInterval {
            steady.isEmpty ? 0 : steady.reduce(0, +) / Double(steady.count)
        }
    }

    private func makeScene(maximumBalls: Bool = false) -> (GameScene, FrameTimer, BallNode) {
        let size = CGSize(width: 393, height: 852)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        let window = UIWindow(frame: view.frame)
        window.addSubview(view)
        window.makeKeyAndVisible()
        self.window = window

        let scene = GameScene(size: size)
        scene.scaleMode = .resizeFill
        let timer = FrameTimer()
        scene.frameObserver = timer
        view.presentScene(scene)
        scene.startNewRound()
        if maximumBalls { scene.debugFillToMaximumBalls() }

        let ball = scene.children
            .compactMap { $0 as? BallNode }
            .first { $0.kind == .player }!
        return (scene, timer, ball)
    }

    private func run(_ duration: TimeInterval, each: (() -> Void)? = nil) {
        let end = Date().addingTimeInterval(duration)
        while Date() < end {
            each?()
            RunLoop.current.run(until: Date().addingTimeInterval(0.008))
        }
    }

    /// Throws the ball repeatedly for `duration`, varying the direction.
    ///
    /// Re-assigning velocity every iteration — which these tests used to do — is
    /// not sustained throwing: it overwrites each wall bounce, so a ball pinned
    /// against a wall with velocity pointing into it stays there for the whole
    /// run and never hits anything. That produced a test that scored zero and
    /// failed intermittently. Throwing at intervals lets physics actually run.
    private func throwRepeatedly(
        _ ball: BallNode,
        for duration: TimeInterval,
        every interval: TimeInterval = 0.4,
        each: (() -> Void)? = nil
    ) {
        let end = Date().addingTimeInterval(duration)
        var nextThrow = Date()
        var angle: CGFloat = 0.6
        while Date() < end {
            if Date() >= nextThrow {
                // Rotate the direction so no single throw can wedge the ball.
                angle += 1.1
                let speed: CGFloat = 1700
                ball.physicsBody?.velocity = CGVector(
                    dx: speed * cos(angle),
                    dy: speed * sin(angle)
                )
                nextThrow = Date().addingTimeInterval(interval)
            }
            each?()
            RunLoop.current.run(until: Date().addingTimeInterval(0.008))
        }
    }

    /// Resident footprint in MB.
    private func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.phys_footprint) / 1_048_576
    }

    private func report(_ label: String, _ timer: FrameTimer) {
        print(String(
            format: "PERF %@ mean=%.1fms p50=%.1fms p95=%.1fms p99=%.1fms worst=%.1fms frames=%d dropped=%d",
            label,
            timer.mean * 1000,
            timer.percentile(0.5) * 1000,
            timer.percentile(0.95) * 1000,
            timer.percentile(0.99) * 1000,
            timer.worst * 1000,
            timer.steady.count,
            timer.steady.filter { $0 > budget * 1.5 }.count
        ))
    }

    // MARK: - Maximum ball count

    func testMaximumBallCountHoldsTheFrameBudget() {
        let (scene, timer, ball) = makeScene(maximumBalls: true)

        let normals = scene.children.compactMap { $0 as? BallNode }.filter { $0.kind == .normal }
        XCTAssertEqual(
            normals.count,
            GameConfiguration.Ball.maximumNormalCount,
            "The field was not actually filled; the test would be measuring nothing."
        )

        // Keep everything moving so the solver has real work every frame.
        throwRepeatedly(ball, for: 3.0)

        report("maxBalls", timer)
        XCTAssertGreaterThan(timer.steady.count, 100, "Too few frames to judge.")
        XCTAssertLessThan(timer.percentile(0.95) , budget * 1.5, "p95 missed the frame budget.")
    }

    // MARK: - Repeated collisions and particle bursts

    func testSustainedCollisionsAndBurstsHoldTheFrameBudget() {
        let (scene, timer, ball) = makeScene(maximumBalls: true)
        var relaunches = 0

        // Every throw is a fresh burst of contacts, each spawning an emitter
        // and a popup.
        throwRepeatedly(ball, for: 4.0) { relaunches += 1 }

        report("collisions", timer)
        XCTAssertGreaterThan(scene.score, 0, "No collisions happened; test is vacuous.")
        XCTAssertLessThan(timer.percentile(0.95), budget * 1.5, "p95 missed the frame budget.")
        XCTAssertLessThan(timer.percentile(0.99), budget * 3, "p99 shows a visible stall.")
    }

    func testEffectNodesReturnToBaselineAfterABurst() {
        let (scene, _, ball) = makeScene(maximumBalls: true)
        let baseline = scene.children.count
        var peak = baseline

        // Sampled every iteration, not once at the end: effects live under a
        // second, so a single reading after the run measures the settled state
        // and would report a peak that never happened.
        var scoringHits = 0
        throwRepeatedly(ball, for: 2.5) {
            peak = max(peak, scene.children.count)
            scoringHits = scene.score / GameConfiguration.Score.base
        }

        // Let every emitter and popup finish and remove itself.
        ball.removeFromParent()
        run(2.0)

        print("PERF nodes baseline=\(baseline) peak=\(peak) settled=\(scene.children.count) hits=\(scoringHits)")

        // The claim under test is that effects clean themselves up. Observing a
        // peak is only possible if collisions happened at all, and whether a
        // sample lands while one is in flight is a race — so the peak assertion
        // is conditional on there having been something to see.
        if scoringHits > 0 {
            XCTAssertGreaterThan(peak, baseline, "Effects never appeared despite \(scoringHits) hits.")
        }
        // baseline minus the player ball, removed above. This is the real claim,
        // and it holds whether or not a sample caught an effect mid-flight.
        XCTAssertEqual(scene.children.count, baseline - 1, "Effect nodes leaked.")
    }

    // MARK: - Long session

    func testAFullRoundDoesNotGrowMemory() {
        let (scene, timer, ball) = makeScene(maximumBalls: true)
        let before = footprintMB()

        // A full round's worth of play, throwing throughout.
        throwRepeatedly(ball, for: 12.0)

        let after = footprintMB()
        report("longSession", timer)
        print(String(format: "PERF memory before=%.1fMB after=%.1fMB delta=%+.1fMB",
                     before, after, after - before))

        XCTAssertGreaterThan(scene.score, 0)
        // Textures are cached on first use, so some growth is expected. Runaway
        // growth is what this catches — a leak per collision, say.
        XCTAssertLessThan(after - before, 40, "Memory grew by more than a cache warm-up explains.")
    }

    func testRepeatedRoundsDoNotAccumulate() {
        let (scene, _, ball) = makeScene(maximumBalls: true)
        let before = footprintMB()
        var counts: [Int] = []

        // Restarting is where leaks show: each round rebuilds the whole field.
        for _ in 0..<6 {
            scene.startNewRound()
            scene.debugFillToMaximumBalls()
            throwRepeatedly(ball, for: 0.7, every: 0.3)
            // Balls only, not every child. "The field is rebuilt" is a claim about
            // balls; counting all children instead made this timing-dependent,
            // because an aftershock collision — a struck ball carrying the
            // throw's energy back into the player — can leave an emitter and a
            // popup in flight at sample time. Those are transient by design.
            counts.append(scene.children.compactMap { $0 as? BallNode }.count)
        }

        let after = footprintMB()
        print("PERF repeatedRounds ballCounts=\(counts)")
        print(String(format: "PERF repeatedRounds memory delta=%+.1fMB", after - before))

        // Rebuilt, not added to: the same count every round, and that count is
        // the maximum plus the one player ball.
        XCTAssertEqual(
            Set(counts).count,
            1,
            "The field is not being rebuilt cleanly across rounds: \(counts)"
        )
        XCTAssertEqual(counts.first, GameConfiguration.Ball.maximumNormalCount + 1)
        XCTAssertLessThan(after - before, 25, "Memory climbed across rounds.")
    }

    // MARK: - Idle cost

    func testAnIdleFieldIsCheap() {
        let (_, timer, _) = makeScene(maximumBalls: true)

        // No throws: ten balls drifting with zero damping, forever.
        run(2.5)

        report("idle", timer)
        XCTAssertLessThan(timer.percentile(0.99), budget * 1.5, "Idle drift is costing frames.")
    }
}
