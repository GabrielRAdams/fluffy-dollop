package com.example.dinochase

import android.content.SharedPreferences
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/**
 * Observable game state shared between the Compose UI (menus / HUD) and the
 * [GameEngine]. The engine mutates score / time / combo as play unfolds; the UI
 * reads them to render overlays. Mirrors the iOS `GameState`.
 */
class GameState(
    private val haptics: Haptics,
    private val prefs: SharedPreferences,
) {
    enum class Phase { MENU, PLAYING, PAUSED, GAME_OVER }

    /** Difficulty tunes round length and monkey speed / aggression. */
    enum class Difficulty(
        val label: String,
        val emoji: String,
        val startingTime: Double,
        val monkeyBaseSpeed: Float,
        val speedRamp: Float,
    ) {
        EASY("Easy", "🌱", 30.0, 250f, 18f),
        NORMAL("Normal", "🔥", 20.0, 300f, 26f),
        HARD("Hard", "💀", 15.0, 360f, 34f),
    }

    var phase by mutableStateOf(Phase.MENU)
    var score by mutableStateOf(0)
    var timeRemaining by mutableStateOf(20.0)
    var highScore by mutableStateOf(prefs.getInt(KEY_HIGH, 0))
        private set

    var comboMultiplier by mutableStateOf(1)
    var comboTimeRemaining by mutableStateOf(0.0)
    val comboWindow = 2.5

    var roarCharge by mutableStateOf(0.0)   // 0..1
    val roarReady: Boolean get() = roarCharge >= 1.0

    var flashMessage by mutableStateOf<String?>(null)

    var difficulty by mutableStateOf(
        Difficulty.entries.getOrElse(prefs.getInt(KEY_DIFF, Difficulty.NORMAL.ordinal)) { Difficulty.NORMAL }
    )
        private set

    /** Wired up by [GameEngine] once both objects exist. */
    lateinit var engine: GameEngine

    private val bonusPerCatch = 3.0
    private val bananaBonus = 2.0
    private val catchesPerRoar = 3.0
    val roarDuration = 3.0

    private var flashTimer = 0.0

    // MARK: - Menu / difficulty

    fun chooseDifficulty(d: Difficulty) {
        difficulty = d
        prefs.edit().putInt(KEY_DIFF, d.ordinal).apply()
    }

    // MARK: - Phase transitions

    fun start() {
        score = 0
        timeRemaining = difficulty.startingTime
        comboMultiplier = 1
        comboTimeRemaining = 0.0
        roarCharge = 0.0
        flashMessage = null
        flashTimer = 0.0
        phase = Phase.PLAYING
        engine.startNewGame()
    }

    fun toMenu() {
        phase = Phase.MENU
        engine.resetToIdle()
    }

    fun pause() {
        if (phase != Phase.PLAYING) return
        phase = Phase.PAUSED
        engine.paused = true
    }

    fun resume() {
        if (phase != Phase.PAUSED) return
        phase = Phase.PLAYING
        engine.paused = false
    }

    fun roar() {
        if (phase != Phase.PLAYING || !roarReady) return
        roarCharge = 0.0
        haptics.roar()
        flash("🦖 ROAAAR!")
        engine.triggerRoar(roarDuration)
    }

    // MARK: - Scoring (called from the engine)

    fun caughtMonkey() {
        comboMultiplier = if (comboTimeRemaining > 0) (comboMultiplier + 1).coerceAtMost(9) else 1
        comboTimeRemaining = comboWindow

        score += comboMultiplier
        timeRemaining += bonusPerCatch
        roarCharge = (roarCharge + 1.0 / catchesPerRoar).coerceAtMost(1.0)

        haptics.catchThump(comboMultiplier)
        flash(if (comboMultiplier >= 2) "x$comboMultiplier!  +$comboMultiplier" else "+${bonusPerCatch.clean()}s")
    }

    fun collectedBanana() {
        score += 1
        timeRemaining += bananaBonus
        haptics.tick()
        flash("🍌 +${bananaBonus.clean()}s")
    }

    // MARK: - Ticking

    fun tick(dt: Double) {
        if (phase != Phase.PLAYING) return

        timeRemaining -= dt
        if (comboTimeRemaining > 0) {
            comboTimeRemaining -= dt
            if (comboTimeRemaining <= 0) {
                comboTimeRemaining = 0.0
                comboMultiplier = 1
            }
        }
        if (flashTimer > 0) {
            flashTimer -= dt
            if (flashTimer <= 0) flashMessage = null
        }

        if (timeRemaining <= 0) {
            timeRemaining = 0.0
            endGame()
        }
    }

    private fun flash(text: String) {
        flashMessage = text
        flashTimer = 0.9
    }

    private fun endGame() {
        if (score > highScore) {
            highScore = score
            prefs.edit().putInt(KEY_HIGH, highScore).apply()
        }
        haptics.gameOver()
        phase = Phase.GAME_OVER
        engine.stopGame()
    }

    private fun Double.clean(): String =
        if (this == kotlin.math.floor(this)) toInt().toString() else "%.1f".format(this)

    companion object {
        private const val KEY_HIGH = "DinoChaseHighScore"
        private const val KEY_DIFF = "DinoChaseDifficulty"
    }
}
