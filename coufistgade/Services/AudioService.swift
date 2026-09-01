//
//  AudioService.swift
//  coufistgade
//
//  Centralised audio (ARCHITECTURE §17), synthesised rather than sampled.
//
//  The project ships no audio assets, and GAMEPLAY §12 requires three tiers of
//  collision sound. Rather than leave audio unimplemented or add placeholder
//  files, the cues are generated once at startup into PCM buffers and played
//  from memory. Tuning a cue means changing a number in GameConfiguration, not
//  re-exporting a file.
//
//  This is a deliberate trade: synthesised tones are cleaner and more tunable
//  than stand-in samples, but a recorded impact will always have more character.
//  Swapping in real assets later replaces `makeBuffer` only — the protocol,
//  the voice pool, and every call site stay as they are.
//
//  ARCHITECTURE §17 offers AVAudioPlayer or AVAudioEngine and asks for the
//  simplest that fits. AVAudioPlayer plays files, not generated buffers, so
//  the engine is the simpler choice *given* synthesis.
//

import AVFoundation
import os

/// What the game needs from audio. A protocol so the scene can be driven
/// silently in tests without an audio engine.
protocol AudioPlaying: AnyObject {
    var isEnabled: Bool { get set }
    func playImpact(_ intensity: ImpactIntensity)
    func playComboMilestone()
    func playAchievementUnlock()
}

final class AudioService: AudioPlaying {

    private static let logger = Logger(subsystem: "com.cclv.coufistgade", category: "Audio")

    /// Phase 14's sound setting writes this. Default on.
    var isEnabled = true

    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    /// Round-robin voices, so overlapping hits layer instead of cutting off.
    private var players: [AVAudioPlayerNode] = []
    private var nextVoice = 0

    private let format: AVAudioFormat
    private var impactBuffers: [ImpactIntensity: AVAudioPCMBuffer] = [:]
    private var comboBuffer: AVAudioPCMBuffer?
    private var achievementBuffer: AVAudioPCMBuffer?
    private var isRunning = false

    init(sampleRate: Double = 44_100) {
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
            ?? AVAudioFormat()
        configureSession()
        buildGraph()
        renderBuffers()
    }

    deinit {
        engine.stop()
    }

    // MARK: - Setup

    /// Ambient and mixable: a casual game must not stop the player's music, and
    /// it should stay silent under the ring/silent switch like other games.
    private func configureSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            Self.logger.error("Audio session unavailable: \(error.localizedDescription)")
        }
    }

    private func buildGraph() {
        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: format)

        for _ in 0..<GameConfiguration.Feedback.Audio.voiceCount {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: mixer, format: format)
            players.append(player)
        }
    }

    private func renderBuffers() {
        let config = GameConfiguration.Feedback.Audio.self
        for intensity in ImpactIntensity.allCases {
            impactBuffers[intensity] = makeBuffer(
                frequency: config.frequency(for: intensity),
                amplitude: config.amplitude(for: intensity),
                duration: config.duration(for: intensity)
            )
        }
        comboBuffer = makeBuffer(
            frequency: config.comboFrequency,
            amplitude: config.comboAmplitude,
            duration: config.comboDuration
        )
        achievementBuffer = makeBuffer(
            frequency: config.achievementFrequency,
            amplitude: config.achievementAmplitude,
            duration: config.achievementDuration
        )
    }

    /// One percussive cue: a sine with a fast exponential decay.
    ///
    /// The decay is what makes it read as an impact rather than a beep, and the
    /// short fade-in removes the click a hard start produces at zero crossing.
    private func makeBuffer(
        frequency: Double,
        amplitude: Double,
        duration: Double
    ) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0]
        else { return nil }

        buffer.frameLength = frameCount
        let decayRate = GameConfiguration.Feedback.Audio.decayRate
        let attackFrames = max(1.0, sampleRate * 0.002)

        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let envelope = exp(-decayRate * time)
            let attack = min(1.0, Double(frame) / attackFrames)
            let value = sin(2 * .pi * frequency * time) * amplitude * envelope * attack
            channel[frame] = Float(value)
        }
        return buffer
    }

    // MARK: - Playing

    func playImpact(_ intensity: ImpactIntensity) {
        guard let buffer = impactBuffers[intensity] else { return }
        play(buffer)
    }

    func playComboMilestone() {
        guard let buffer = comboBuffer else { return }
        play(buffer)
    }

    func playAchievementUnlock() {
        guard let buffer = achievementBuffer else { return }
        play(buffer)
    }

    private func play(_ buffer: AVAudioPCMBuffer) {
        guard isEnabled, !players.isEmpty else { return }
        // Started lazily: an engine running while the game is silent wastes
        // power, and starting can fail on a device with no route.
        guard startIfNeeded() else { return }

        let player = players[nextVoice % players.count]
        nextVoice += 1

        // Interrupting this voice is intended — it is the oldest of the pool.
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: [.interrupts])
        player.play()
    }

    @discardableResult
    private func startIfNeeded() -> Bool {
        if isRunning, engine.isRunning { return true }
        do {
            try engine.start()
            isRunning = true
            return true
        } catch {
            // A failed engine must never take the game down with it.
            Self.logger.error("Audio engine failed to start: \(error.localizedDescription)")
            isRunning = false
            return false
        }
    }

    #if DEBUG
    /// Buffer inspection, so the synthesis can be verified as audible. Every
    /// other test uses a spy, which proves only that a call was made.
    func debugBuffer(for intensity: ImpactIntensity) -> AVAudioPCMBuffer? {
        impactBuffers[intensity]
    }

    func debugComboBuffer() -> AVAudioPCMBuffer? { comboBuffer }

    func debugAchievementBuffer() -> AVAudioPCMBuffer? { achievementBuffer }

    var debugIsEngineRunning: Bool { engine.isRunning }
    #endif

    /// Stops the engine when the game screen goes away.
    func suspend() {
        engine.pause()
        isRunning = false
    }
}
