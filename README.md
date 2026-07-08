# 🦖 Dino Chase

A cute, fast little arcade game for iPhone and iPad: **you're a dinosaur, and
you chase a cheeky monkey.** Steer your dino by dragging your finger around the
screen. Catch the monkey before the timer runs out — every catch adds a few
seconds back on the clock and makes the monkey a little faster and craftier.
How many can you bag before time's up?

Built with **SwiftUI** (menus + HUD) and **SpriteKit** (gameplay). No image
assets required — the characters are emoji, so it runs anywhere with zero setup.

## Gameplay

- **Steer:** Drag anywhere on screen. The dino accelerates toward your finger
  with a bit of momentum, so it feels weighty rather than robotic.
- **Goal:** Get close enough to the monkey to catch it. +1 score, +3 seconds.
- **The monkey:** Runs directly away from you when you get close, jukes
  sideways to dodge, avoids getting cornered against the walls, and idly
  wanders when you're far away.
- **Difficulty ramp:** Each catch bumps the monkey's top speed, so a long run
  gets progressively harder.
- **Round:** Starts at 20 seconds. Reach 0 and it's game over. High score is
  saved between sessions.

## Project layout

```
DinoChase/
├── DinoChase.xcodeproj/          # Xcode project
└── DinoChase/
    ├── DinoChaseApp.swift        # App entry point (SwiftUI lifecycle)
    ├── ContentView.swift         # Hosts SpriteView + menu/HUD/game-over overlays
    ├── GameState.swift           # Observable state bridging SwiftUI and SpriteKit
    ├── GameScene.swift           # The playfield: movement, monkey AI, catching
    ├── Assets.xcassets/          # App icon + accent color
    └── Info.plist
```

## Running it

1. Open `DinoChase/DinoChase.xcodeproj` in **Xcode 15** or newer.
2. Select an iPhone simulator (or your own device).
3. Press **Run** (⌘R).

> If you build to a physical device, set your own Development Team under
> *Signing & Capabilities* — the project ships with automatic signing and a
> placeholder bundle identifier (`com.example.DinoChase`).

Requires **iOS 16.0+**. Portrait orientation on iPhone; all orientations on
iPad.

## Tuning

Most of the "game feel" lives as constants near the top of `GameScene.swift`
— `dinoMaxSpeed`, `dinoAccel`, `monkeyMaxSpeed`, `monkeyFleeRadius`,
`catchDistance` — and the round length / time bonuses live in `GameState.swift`
(`startingTime`, `bonusPerCatch`). Tweak away.
