import UIKit

/// Small wrapper around UIKit feedback generators. Generators are prepared up
/// front so the taptic engine is warm and latency stays low during play.
final class Haptics {
    static let shared = Haptics()

    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notify = UINotificationFeedbackGenerator()

    private init() {}

    func warmUp() {
        light.prepare()
        medium.prepare()
        heavy.prepare()
    }

    /// A catch thump that grows heavier with the combo multiplier.
    func catchThump(intensity: Int) {
        switch intensity {
        case ..<2:
            medium.impactOccurred()
            medium.prepare()
        case 2..<4:
            heavy.impactOccurred(intensity: 0.9)
            heavy.prepare()
        default:
            heavy.impactOccurred(intensity: 1.0)
            heavy.prepare()
        }
    }

    func tick() {
        light.impactOccurred(intensity: 0.7)
        light.prepare()
    }

    /// A big, satisfying jolt for unleashing the roar.
    func roar() {
        heavy.impactOccurred(intensity: 1.0)
        notify.notificationOccurred(.success)
        heavy.prepare()
    }

    func gameOver() {
        notify.notificationOccurred(.error)
    }
}
