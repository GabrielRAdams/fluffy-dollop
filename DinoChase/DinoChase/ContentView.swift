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
            case .paused:
                HUDView(game: game)
                PauseView(game: game)
            case .gameOver:
                GameOverView(game: game)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: game.phase)
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

            Text("Catch the cheeky monkeys 🐒 before time runs out!")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.95))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 6) {
                Text("Drag anywhere to steer your dino.")
                Text("Chain catches for combo bonuses 🔥")
                Text("Grab bananas 🍌 for extra time!")
            }
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundColor(.white.opacity(0.85))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)

            DifficultyPicker(game: game)

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

struct DifficultyPicker: View {
    @ObservedObject var game: GameState

    var body: some View {
        VStack(spacing: 6) {
            Text("DIFFICULTY")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
                .tracking(2)

            HStack(spacing: 10) {
                ForEach(GameState.Difficulty.allCases) { level in
                    let selected = game.difficulty == level
                    Button(action: { game.difficulty = level }) {
                        Text("\(level.emoji) \(level.label)")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(selected ? Color(red: 0.15, green: 0.35, blue: 0.15) : .white)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(
                                Capsule().fill(selected ? Color.yellow : Color.black.opacity(0.3))
                            )
                    }
                }
            }
        }
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

                Spacer()

                Button(action: { game.pause() }) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.black.opacity(0.35)))
                }
                .disabled(game.phase != .playing)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // Combo meter — appears while a streak is alive.
            if game.comboMultiplier >= 2 {
                ComboMeter(game: game)
                    .padding(.top, 8)
                    .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            // Transient flash (e.g. "+3s", "x4!").
            if let msg = game.flashMessage {
                Text(msg)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundColor(.yellow)
                    .shadow(color: .black.opacity(0.5), radius: 3, y: 2)
                    .transition(.scale.combined(with: .opacity))
                    .id(msg)
            }

            // Roar power-up button, bottom-center.
            RoarButton(game: game)
                .padding(.bottom, 40)
                .padding(.top, 8)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: game.comboMultiplier)
        .animation(.easeOut(duration: 0.2), value: game.flashMessage)
    }
}

struct RoarButton: View {
    @ObservedObject var game: GameState

    var body: some View {
        Button(action: { game.roar() }) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.35))
                    .frame(width: 84, height: 84)

                // Charge ring fills clockwise as you catch monkeys.
                Circle()
                    .trim(from: 0, to: game.roarCharge)
                    .stroke(game.roarReady ? Color.orange : Color.yellow,
                            style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .frame(width: 78, height: 78)
                    .rotationEffect(.degrees(-90))

                Text("🦖")
                    .font(.system(size: 40))

                if game.roarReady {
                    Text("ROAR")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(.orange)
                        .offset(y: 34)
                }
            }
            .scaleEffect(game.roarReady ? (pulse ? 1.12 : 1.0) : 1.0)
            .shadow(color: game.roarReady ? .orange.opacity(0.7) : .clear, radius: 12)
        }
        .disabled(!game.roarReady)
        .animation(.linear(duration: 0.2), value: game.roarCharge)
        .onChange(of: game.roarReady) { ready in
            pulse = false
            if ready {
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
    }

    @State private var pulse = false
}

struct ComboMeter: View {
    @ObservedObject var game: GameState

    var body: some View {
        VStack(spacing: 4) {
            Text("🔥 COMBO x\(game.comboMultiplier)")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundColor(.orange)
                .shadow(color: .black.opacity(0.4), radius: 2, y: 1)

            // Draining timer bar showing how long to land the next catch.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.3))
                    Capsule()
                        .fill(Color.orange)
                        .frame(width: geo.size.width * CGFloat(max(0, game.comboTimeRemaining / game.comboWindow)))
                }
            }
            .frame(width: 140, height: 8)
        }
    }
}

// MARK: - Pause

struct PauseView: View {
    @ObservedObject var game: GameState

    var body: some View {
        VStack(spacing: 24) {
            Text("PAUSED")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.4), radius: 4, y: 2)

            Button(action: { game.resume() }) {
                Text("RESUME")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(red: 0.15, green: 0.35, blue: 0.15))
                    .frame(width: 220, height: 60)
                    .background(RoundedRectangle(cornerRadius: 30).fill(Color.yellow))
            }

            Button(action: { game.toMenu() }) {
                Text("Quit to Menu")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.5).ignoresSafeArea())
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

            Text("You scored \(game.score) point\(game.score == 1 ? "" : "s")!")
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
