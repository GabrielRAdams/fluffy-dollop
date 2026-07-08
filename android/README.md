# 🦖 Dino Chase — Android

A native Android port of Dino Chase, built with **Kotlin + Jetpack Compose**.
The whole game — steering, monkey AI, combos, bananas, the roar power-up,
difficulty, pause, haptics, and the particle/shake juice — is rendered on a
Compose `Canvas` driven by a `withFrameNanos` game loop. No game engine or
image assets required; the characters are system emoji.

## Requirements

- **Android Studio** (Koala / 2024.1 or newer recommended)
- **Android SDK** with platform 34 and build-tools (Android Studio installs
  these for you)
- A phone running **Android 7.0 (API 24)** or newer, or an emulator

## Build & install from Android Studio

1. Open Android Studio → **Open** → select this `android/` folder.
2. Let it sync Gradle (it downloads the Android Gradle Plugin and Compose the
   first time — needs internet).
3. Plug in your phone with **USB debugging** enabled (Settings → Developer
   options → USB debugging), and accept the "Allow debugging?" prompt.
4. Pick your device in the toolbar dropdown and press **Run ▶**.

## Build & install from the command line

From inside `android/`:

```bash
# Build a debug APK
./gradlew assembleDebug

# …or build and install straight to a connected device
./gradlew installDebug
```

The APK lands at `app/build/outputs/apk/debug/app-debug.apk`. To install an
existing APK manually:

```bash
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

> **Note:** the first Gradle run downloads the Gradle 8.7 distribution and all
> dependencies, so it needs network access. `local.properties` (pointing at your
> SDK) is generated automatically by Android Studio; if you build purely from
> the CLI, set `ANDROID_HOME` or create `android/local.properties` with
> `sdk.dir=/path/to/Android/sdk`.

## How to play

Drag anywhere to steer your dino toward the monkeys. Catch them to score and
add time; chain catches within the combo window for a multiplier. Grab bananas
🍌 for bonus time, and once the roar meter fills, tap the 🦖 button to freeze
every monkey for a few seconds. Pick Easy / Normal / Hard on the menu. See the
[root README](../README.md) for the full feature rundown.

## Project layout

```
android/
├── settings.gradle.kts / build.gradle.kts   # Gradle setup (Kotlin DSL)
├── gradlew, gradle/wrapper/                  # Gradle wrapper (8.7)
└── app/
    ├── build.gradle.kts                      # App module + Compose deps
    └── src/main/
        ├── AndroidManifest.xml
        ├── java/com/example/dinochase/
        │   ├── MainActivity.kt               # Activity; wires state + engine
        │   ├── GameState.kt                  # Observable state, scoring, phases
        │   ├── GameEngine.kt                 # Physics: movement, AI, bananas, juice
        │   ├── GameScreen.kt                 # Compose UI: canvas renderer + overlays
        │   └── Haptics.kt                     # Vibrator wrapper
        └── res/                              # Launcher icons, theme, strings
```
