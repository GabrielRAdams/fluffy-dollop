import SwiftUI
import SpriteKit

/// Root view. Hosts the SpriteKit game and overlays SwiftUI menus/HUD on top.
struct ContentView: View {
    @StateObject private var game = GameState()

    var body: some View {
        ZStack {
            SpriteView(scene: game.scene ?? makeScene())
                .ignoresSafeArea()

            switch game.phase {
            case .menu:
                StartMenuView(game: game)
            case .playing:
                HUDView(game: game)
            case .gameOver:
                GameOverView(game: game)
            }
        }
    }

    private func makeScene() -> GameScene {
        let s = GameScene(size: UIScreen.main.bounds.size)
        s.scaleMode = .resizeFill
        s.gameState = game
        game.scene = s
        return s
    }
}

// MARK: - Start Menu

struct StartMenuView: View {
    @ObservedObject var game: GameState

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("🦖")
                .font(.system(size: 96))
                .shadow(radius: 8)

            Text("DINO CHASE")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.4), radius: 4, y: 2)

            Text("Catch the cheeky monkey 🐒 before time runs out!")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.95))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 6) {
                Text("Drag anywhere to steer your dino.")
                Text("Every catch adds time — and the monkey gets faster!")
            }
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundColor(.white.opacity(0.85))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)

            if game.highScore > 0 {
                Text("🏆 Best: \(game.highScore)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.yellow)
            }

            Button(action: { game.start() }) {
                Text("PLAY")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(red: 0.15, green: 0.35, blue: 0.15))
                    .frame(width: 220, height: 64)
                    .background(
                        RoundedRectangle(cornerRadius: 32)
                            .fill(Color.yellow)
                            .shadow(color: .black.opacity(0.3), radius: 6, y: 4)
                    )
            }
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.25).ignoresSafeArea())
    }
}

// MARK: - In-game HUD

struct HUDView: View {
    @ObservedObject var game: GameState

    var body: some View {
        VStack {
            HStack(alignment: .top) {
                Label("\(game.score)", systemImage: "star.fill")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(Color.black.opacity(0.35)))

                Spacer()

                Text(String(format: "⏱ %.0f", max(0, game.timeRemaining)))
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(game.timeRemaining < 5 ? .red : .white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(Color.black.opacity(0.35)))
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Spacer()
        }
    }
}

// MARK: - Game Over

struct GameOverView: View {
    @ObservedObject var game: GameState

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text(game.score > 0 ? "🎉" : "😅")
                .font(.system(size: 80))

            Text("GAME OVER")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.4), radius: 4, y: 2)

            Text("You caught \(game.score) monke\(game.score == 1 ? "y" : "ys")!")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            if game.score >= game.highScore && game.score > 0 {
                Text("🏆 NEW BEST!")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(.yellow)
            } else {
                Text("🏆 Best: \(game.highScore)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.yellow)
            }

            Button(action: { game.start() }) {
                Text("PLAY AGAIN")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(red: 0.15, green: 0.35, blue: 0.15))
                    .frame(width: 240, height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 30)
                            .fill(Color.yellow)
                            .shadow(color: .black.opacity(0.3), radius: 6, y: 4)
                    )
            }
            .padding(.top, 8)

            Button(action: { game.toMenu() }) {
                Text("Main Menu")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.4).ignoresSafeArea())
    }
}

#Preview {
    ContentView()
}
