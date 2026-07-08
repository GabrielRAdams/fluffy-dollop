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

    // MARK: - Phase transitions

    func start() {
        score = 0
        timeRemaining = startingTime
        comboMultiplier = 1
        comboTimeRemaining = 0
        flashMessage = nil
        phase = .playing
        scene?.startNewGame()
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
