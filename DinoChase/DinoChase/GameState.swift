import SwiftUI
import SpriteKit

/// Shared, observable game state that bridges SwiftUI (menus / HUD) and the
/// SpriteKit `GameScene`. The scene mutates `score` / `timeRemaining`; SwiftUI
/// reads them to render overlays.
final class GameState: ObservableObject {
    enum Phase {
        case menu
        case playing
        case gameOver
    }

    @Published var phase: Phase = .menu
    @Published var score: Int = 0
    @Published var timeRemaining: Double = 20
    @Published private(set) var highScore: Int = UserDefaults.standard.integer(forKey: "DinoChaseHighScore")

    /// The single persistent scene instance, retained here so it survives
    /// SwiftUI view redraws.
    var scene: GameScene?

    /// Seconds granted per round at the start.
    let startingTime: Double = 20
    /// Seconds added to the clock for each monkey caught.
    let bonusPerCatch: Double = 3

    func start() {
        score = 0
        timeRemaining = startingTime
        phase = .playing
        scene?.startNewGame()
    }

    func toMenu() {
        phase = .menu
        scene?.resetToIdle()
    }

    func caughtMonkey() {
        score += 1
        timeRemaining += bonusPerCatch
    }

    func tick(_ delta: Double) {
        guard phase == .playing else { return }
        timeRemaining -= delta
        if timeRemaining <= 0 {
            timeRemaining = 0
            endGame()
        }
    }

    private func endGame() {
        if score > highScore {
            highScore = score
            UserDefaults.standard.set(highScore, forKey: "DinoChaseHighScore")
        }
        phase = .gameOver
        scene?.stopGame()
    }
}
