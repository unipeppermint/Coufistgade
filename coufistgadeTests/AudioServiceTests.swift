//
//  AudioServiceTests.swift
//  coufistgadeTests
//
//  Inspects the synthesised buffers directly. Every other test uses a spy, so
//  without these "audio works" would rest on nothing but the call reaching a
//  protocol.
//

import XCTest
import AVFoundation
@testable import coufistgade

final class AudioServiceTests: XCTestCase {

    // MARK: - Synthesis

    func testEveryIntensityProducesANonSilentBuffer() throws {
        let sut = AudioService()

        for intensity in ImpactIntensity.allCases {
            let buffer = try XCTUnwrap(
                sut.debugBuffer(for: intensity),
                "No buffer for \(intensity)."
            )
            let peak = Self.peakAmplitude(of: buffer)
            XCTAssertGreaterThan(peak, 0.01, "\(intensity) is effectively silent (peak \(peak)).")
        }
    }

    func testTheComboCueIsAlsoAudible() throws {
        let sut = AudioService()

        let buffer = try XCTUnwrap(sut.debugComboBuffer())

        XCTAssertGreaterThan(Self.peakAmplitude(of: buffer), 0.01)
    }

    func testLouderTiersAreActuallyLouder() throws {
        let sut = AudioService()

        var peaks: [Float] = []
        for intensity in ImpactIntensity.allCases {
            peaks.append(Self.peakAmplitude(of: try XCTUnwrap(sut.debugBuffer(for: intensity))))
        }

        // GAMEPLAY §12: light sound → stronger → strong.
        XCTAssertEqual(peaks, peaks.sorted(), "Loudness does not rise with intensity: \(peaks)")
        XCTAssertLessThan(peaks.first!, peaks.last!)
    }

    func testHarderHitsSoundLowerNotHigher() {
        let config = GameConfiguration.Feedback.Audio.self

        // A big impact should sound bigger. Rising pitch with force reads as
        // comical rather than weighty.
        XCTAssertGreaterThan(config.frequency(for: .low), config.frequency(for: .medium))
        XCTAssertGreaterThan(config.frequency(for: .medium), config.frequency(for: .high))
    }

    func testNoBufferClips() throws {
        let sut = AudioService()

        // Amplitudes are summed with an envelope; anything at or past 1.0 would
        // distort on the way out.
        for intensity in ImpactIntensity.allCases {
            let peak = Self.peakAmplitude(of: try XCTUnwrap(sut.debugBuffer(for: intensity)))
            XCTAssertLessThan(peak, 1.0, "\(intensity) clips.")
        }
    }

    func testCuesAreEffectivelyOverBeforeTheNextHitCanArrive() throws {
        let sut = AudioService()
        let cooldown = GameConfiguration.Collision.repeatContactCooldown

        // Hits can arrive every 0.15s, and a cue still ringing at full volume
        // would smear a rally into a drone.
        //
        // The buffer length is the wrong measure of this: the envelope decays
        // exponentially, so the High cue's 0.18s buffer is inaudible long before
        // it ends. What matters is when it drops below hearing.
        for intensity in ImpactIntensity.allCases {
            let buffer = try XCTUnwrap(sut.debugBuffer(for: intensity))
            let audible = Self.audibleDuration(of: buffer, threshold: 0.02)
            XCTAssertLessThan(
                audible, cooldown,
                "\(intensity) is still audible after \(audible)s, past the \(cooldown)s cooldown."
            )
        }
    }

    func testEachCueDecaysRatherThanEndingAbruptly() throws {
        let sut = AudioService()
        let buffer = try XCTUnwrap(sut.debugBuffer(for: .high))
        let samples = Self.samples(of: buffer)

        // A cue that stops at full amplitude clicks. The tail should be far
        // quieter than the body.
        let head = samples.prefix(samples.count / 4).map(abs).max() ?? 0
        let tail = samples.suffix(samples.count / 10).map(abs).max() ?? 0
        XCTAssertLessThan(tail, head * 0.5, "No decay: head \(head), tail \(tail).")
    }

    func testTheCueStartsFromSilenceToAvoidAClick() throws {
        let sut = AudioService()
        let samples = Self.samples(of: try XCTUnwrap(sut.debugBuffer(for: .high)))

        XCTAssertEqual(samples.first ?? 1, 0, accuracy: 0.001)
    }

    // MARK: - Enablement

    func testDisablingStopsPlayback() {
        let sut = AudioService()
        sut.isEnabled = false

        // Nothing to assert audibly in a test process; what matters is that the
        // call is safe and does not start the engine.
        sut.playImpact(.high)
        sut.playComboMilestone()

        XCTAssertFalse(sut.debugIsEngineRunning)
    }

    func testPlayingIsSafeInATestProcessWithNoAudioRoute() {
        let sut = AudioService()

        // The simulator may refuse to start the engine. A failure there must
        // never propagate into the game.
        sut.playImpact(.low)
        sut.playImpact(.medium)
        sut.playImpact(.high)
        sut.playComboMilestone()
        sut.suspend()
    }

    func testVoiceCountAllowsOverlappingHits() {
        // One voice would cut each cue off with the next, which at 7 hits/s
        // would be audible as chopping.
        XCTAssertGreaterThan(GameConfiguration.Feedback.Audio.voiceCount, 1)
    }

    // MARK: - Helpers

    private static func samples(of buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channel = buffer.floatChannelData?[0] else { return [] }
        return (0..<Int(buffer.frameLength)).map { channel[$0] }
    }

    private static func peakAmplitude(of buffer: AVAudioPCMBuffer) -> Float {
        samples(of: buffer).map(abs).max() ?? 0
    }

    /// Time until the cue's envelope falls below `threshold` and stays there.
    private static func audibleDuration(
        of buffer: AVAudioPCMBuffer,
        threshold: Float
    ) -> TimeInterval {
        let values = samples(of: buffer)
        guard let lastLoud = values.lastIndex(where: { abs($0) > threshold }) else { return 0 }
        return Double(lastLoud) / buffer.format.sampleRate
    }
}
