import SwiftUI
import SpriteKit

/// Shared, observable game state that bridges SwiftUI (menus / HUD) and the
/// SpriteKit `GameScene`. The scene mutates `score` / `timeRemaining`; SwiftUI
/// reads them to render overlays.
final class GameState: ObservableObject {
    enum Phase {
        case menu
        case playing
        case paused
        case gameOver
    }

    /// Difficulty tunes the round length and how fast / aggressive the monkeys
    /// are. Persisted so the player's choice sticks between launches.
    enum Difficulty: Int, CaseIterable, Identifiable {
        case easy, normal, hard
        var id: Int { rawValue }

        var label: String {
            switch self {
            case .easy: return "Easy"
            case .normal: return "Normal"
            case .hard: return "Hard"
            }
        }
        var emoji: String {
            switch self {
            case .easy: return "🌱"
            case .normal: return "🔥"
            case .hard: return "💀"
            }
        }
        var startingTime: Double {
            switch self {
            case .easy: return 30
            case .normal: return 20
            case .hard: return 15
            }
        }
        var monkeyBaseSpeed: CGFloat {
            switch self {
            case .easy: return 250
            case .normal: return 300
            case .hard: return 360
            }
        }
        var speedRamp: CGFloat {
            switch self {
            case .easy: return 18
            case .normal: return 26
            case .hard: return 34
            }
        }
    }

    @Published var phase: Phase = .menu
    @Published var score: Int = 0
    @Published var timeRemaining: Double = 20
    @Published private(set) var highScore: Int = UserDefaults.standard.integer(forKey: "DinoChaseHighScore")

    // Combo / streak: catch monkeys in quick succession to build a multiplier.
    @Published var comboMultiplier: Int = 1
    @Published var comboTimeRemaining: Double = 0
    /// Time window (seconds) to land the next catch before the combo resets.
    let comboWindow: Double = 2.5

    /// Transient banner text (e.g. "+3s", "x4!") shown briefly in the HUD.
    @Published var flashMessage: String? = nil

    // Roar power-up: fills as you catch monkeys; when full, unleash it to
    // briefly freeze every monkey on the field.
    @Published var roarCharge: Double = 0            // 0...1
    @Published var isRoaring: Bool = false
    let catchesPerRoar: Double = 3
    let roarDuration: Double = 3.0
    var roarReady: Bool { roarCharge >= 1 }

    /// Selected difficulty, restored from and saved to UserDefaults.
    @Published var difficulty: Difficulty {
        didSet { UserDefaults.standard.set(difficulty.rawValue, forKey: "DinoChaseDifficulty") }
    }

    /// The single persistent scene instance, retained here so it survives
    /// SwiftUI view redraws.
    var scene: GameScene?

    /// Seconds granted per round at the start.
    let startingTime: Double = 20
    /// Base seconds added to the clock for each monkey caught.
    let bonusPerCatch: Double = 3
    /// Seconds added when a banana is collected.
    let bananaBonus: Double = 2

    private var flashClearWorkItem: DispatchWorkItem?

    init() {
        let saved = UserDefaults.standard.integer(forKey: "DinoChaseDifficulty")
        difficulty = Difficulty(rawValue: saved) ?? .normal
    }

    // MARK: - Phase transitions

    func start() {
        score = 0
        timeRemaining = difficulty.startingTime
        comboMultiplier = 1
        comboTimeRemaining = 0
        roarCharge = 0
        isRoaring = false
        flashMessage = nil
        phase = .playing
        scene?.startNewGame()
    }

    // MARK: - Roar power-up

    func roar() {
        guard phase == .playing, roarReady else { return }
        roarCharge = 0
        isRoaring = true
        Haptics.shared.roar()
        flash("🦖 ROAAAR!")
        scene?.triggerRoar(duration: roarDuration)
        // Clear the roaring flag once the freeze wears off.
        DispatchQueue.main.asyncAfter(deadline: .now() + roarDuration) { [weak self] in
            self?.isRoaring = false
        }
    }

    func toMenu() {
        phase = .menu
        scene?.resetToIdle()
    }

    func pause() {
        guard phase == .playing else { return }
        phase = .paused
        scene?.setPaused(true)
    }

    func resume() {
        guard phase == .paused else { return }
        phase = .playing
        scene?.setPaused(false)
    }

    // MARK: - Scoring

    func caughtMonkey() {
        // Extend the combo if still within the window; otherwise start fresh.
        if comboTimeRemaining > 0 {
            comboMultiplier = min(comboMultiplier + 1, 9)
        } else {
            comboMultiplier = 1
        }
        comboTimeRemaining = comboWindow

        score += comboMultiplier
        timeRemaining += bonusPerCatch
        roarCharge = min(1.0, roarCharge + 1.0 / catchesPerRoar)

        Haptics.shared.catchThump(intensity: comboMultiplier)

        if comboMultiplier >= 2 {
            flash("x\(comboMultiplier)!  +\(comboMultiplier)")
        } else {
            flash("+\(bonusPerCatch.clean)s")
        }
    }

    func collectedBanana() {
        score += 1
        timeRemaining += bananaBonus
        Haptics.shared.tick()
        flash("🍌 +\(bananaBonus.clean)s")
    }

    // MARK: - Ticking

    func tick(_ delta: Double) {
        guard phase == .playing else { return }

        timeRemaining -= delta
        if comboTimeRemaining > 0 {
            comboTimeRemaining -= delta
            if comboTimeRemaining <= 0 {
                comboTimeRemaining = 0
                comboMultiplier = 1
            }
        }

        if timeRemaining <= 0 {
            timeRemaining = 0
            endGame()
        }
    }

    // MARK: - Helpers

    private func flash(_ text: String) {
        flashMessage = text
        flashClearWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.flashMessage = nil }
        flashClearWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: work)
    }

    private func endGame() {
        if score > highScore {
            highScore = score
            UserDefaults.standard.set(highScore, forKey: "DinoChaseHighScore")
        }
        Haptics.shared.gameOver()
        phase = .gameOver
        scene?.stopGame()
    }
}

private extension Double {
    /// "3" not "3.0" — for tidy HUD strings.
    var clean: String {
        self == rounded() ? String(Int(self)) : String(format: "%.1f", self)
    }
}
