//
//  HapticService.swift
//  coufistgade
//
//  Centralised haptics (ARCHITECTURE §18).
//
//  UIKit feedback generators, not Core Haptics: §18 asks for the simplest that
//  fits, and the game needs three fixed taps rather than authored waveforms. A
//  CHHapticEngine would add a lifecycle to manage and a fallback path to write
//  for no gain the player could feel.
//
//  The generators are kept alive and prepared rather than created per hit —
//  a freshly created generator has to warm the Taptic Engine, which costs
//  enough latency to break the link between seeing and feeling the impact.
//

import UIKit

protocol HapticPlaying: AnyObject {
    var isEnabled: Bool { get set }
    func playImpact(_ intensity: ImpactIntensity)
    func playComboMilestone()
}

final class HapticService: HapticPlaying {

    /// Phase 14's haptics setting writes this. Default on.
    var isEnabled = true

    private var impactGenerators: [UIImpactFeedbackGenerator.FeedbackStyle:
                                    UIImpactFeedbackGenerator] = [:]
    private let notificationGenerator = UINotificationFeedbackGenerator()

    /// Injected so the rate limit can be tested without waiting in real time.
    private let now: () -> TimeInterval
    private var lastPlayTime: TimeInterval = -.greatestFiniteMagnitude

    init(now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.now = now
    }

    /// Warms the Taptic Engine ahead of the first hit.
    ///
    /// Called when the game screen appears: `prepare()` keeps the engine ready
    /// for a short window, so doing it at launch would be wasted.
    func prepare() {
        for style in Self.usedStyles {
            let generator = generator(for: style)
            generator.prepare()
        }
        notificationGenerator.prepare()
    }

    private static var usedStyles: [UIImpactFeedbackGenerator.FeedbackStyle] {
        ImpactIntensity.allCases.compactMap {
            GameConfiguration.Feedback.Haptics.style(for: $0)
        }
    }

    private func generator(
        for style: UIImpactFeedbackGenerator.FeedbackStyle
    ) -> UIImpactFeedbackGenerator {
        if let existing = impactGenerators[style] { return existing }
        let created = UIImpactFeedbackGenerator(style: style)
        impactGenerators[style] = created
        return created
    }

    // MARK: - Playing

    func playImpact(_ intensity: ImpactIntensity) {
        // GAMEPLAY §12: Low has no haptic. A nil style is the tier saying so,
        // not a missing case.
        guard let style = GameConfiguration.Feedback.Haptics.style(for: intensity) else { return }
        guard shouldPlay() else { return }

        let generator = generator(for: style)
        generator.impactOccurred()
        // Re-arm for the next hit, which is likely to be soon.
        generator.prepare()
    }

    func playComboMilestone() {
        guard shouldPlay() else { return }
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }

    #if DEBUG
    /// Number of haptics actually delivered. The generators give no feedback of
    /// their own, so this is the only way to assert the rate limit.
    private(set) var debugPlayCount = 0
    #endif

    /// Rate limit shared across every kind of haptic.
    ///
    /// GAMEPLAY §12: "Never trigger haptics every frame." The collision cooldown
    /// alone still permits ~7/s, which stops feeling like distinct taps and
    /// starts feeling like a buzz. One limiter for all sources, because a
    /// milestone landing on the same frame as an impact would otherwise
    /// double-fire.
    private func shouldPlay() -> Bool {
        guard isEnabled else { return false }
        let time = now()
        guard time - lastPlayTime >= GameConfiguration.Feedback.Haptics.minimumInterval else {
            return false
        }
        lastPlayTime = time
        #if DEBUG
        debugPlayCount += 1
        #endif
        return true
    }
}
