# 🦖 Dino Chase

A cute, fast little arcade game for iPhone and iPad: **you're a dinosaur, and
you chase a cheeky monkey.** Steer your dino by dragging your finger around the
screen. Catch the monkey before the timer runs out — every catch adds a few
seconds back on the clock and makes the monkey a little faster and craftier.
How many can you bag before time's up?

Built with **SwiftUI** (menus + HUD) and **SpriteKit** (gameplay). No image
assets required — the characters are emoji, so it runs anywhere with zero setup.

> **📱 Two platforms:** this repo ships the game for **both iOS and Android**.
> The iOS app (SwiftUI + SpriteKit) lives in [`DinoChase/`](DinoChase); a native
> **Android** port (Kotlin + Jetpack Compose) lives in [`android/`](android) —
> see [`android/README.md`](android/README.md) to build and install it on a
> phone. Both share the same gameplay, tuning, and feature set.

## Gameplay

- **Steer:** Drag anywhere on screen. The dino accelerates toward your finger
  with a bit of momentum, so it feels weighty rather than robotic.
- **Goal:** Get close enough to a monkey to catch it. Catching adds to your
  score and puts 3 seconds back on the clock.
- **The monkeys:** Run directly away when you get close, juke sideways to
  dodge, avoid getting cornered against the walls, and idly wander when you're
  far away.
- **Combos 🔥:** Land catches within 2.5 seconds of each other to build a
  streak multiplier (up to x9). The combo meter shows how long you have before
  it resets, and each catch scores points equal to the current multiplier.
- **Bananas 🍌:** Spawn around the field — grab them for a point and +2 seconds.
- **Roar power-up 🦖:** Catching monkeys charges the roar meter. When it's full,
  tap the roar button to freeze every monkey on the field for a few seconds —
  perfect for cleaning up a big combo. Comes with a shockwave, a hefty haptic
  jolt, and a screen shake.
- **Escalation:** Each catch bumps the monkeys' top speed, and every 5 points
  adds another monkey to the field (up to four at once).
- **Difficulty:** Choose Easy 🌱 / Normal 🔥 / Hard 💀 on the menu — it changes
  the round length and how fast and aggressive the monkeys are. Your choice is
  remembered between launches.
- **Feel:** Haptic feedback on catches (heavier with bigger combos), a catch
  particle burst, and a screen shake.
- **Pause:** Tap the pause button any time to resume or quit to the menu.
- **Round:** Starts at 15–30 seconds depending on difficulty. Reach 0 and it's
  game over. High score is saved between sessions.

## Project layout

```
DinoChase/
├── DinoChase.xcodeproj/          # Xcode project
└── DinoChase/
    ├── DinoChaseApp.swift        # App entry point (SwiftUI lifecycle)
    ├── ContentView.swift         # Hosts SpriteView + menu/HUD/pause/game-over overlays
    ├── GameState.swift           # Observable state: score, timer, combos, roar, difficulty
    ├── GameScene.swift           # The playfield: movement, monkey AI, bananas, roar, juice
    ├── Haptics.swift             # Taptic feedback wrapper
    ├── Assets.xcassets/          # App icon (dino-chases-monkey) + accent color
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
`catchDistance`, `bananaInterval`, `maxBananas` — and the round length, time
bonuses, and combo window live in `GameState.swift` (`startingTime`,
`bonusPerCatch`, `bananaBonus`, `comboWindow`). Tweak away.
