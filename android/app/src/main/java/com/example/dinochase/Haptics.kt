package com.example.dinochase

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/**
 * Thin wrapper around the platform vibrator. Effects are short and punchy to
 * match the arcade feel; amplitude scales with combo size where supported.
 */
class Haptics(context: Context) {

    private val vibrator: Vibrator? = run {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
            manager?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }

    private fun buzz(ms: Long, amplitude: Int) {
        val v = vibrator ?: return
        if (!v.hasVibrator()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val amp = amplitude.coerceIn(1, 255)
            v.vibrate(VibrationEffect.createOneShot(ms, amp))
        } else {
            @Suppress("DEPRECATION")
            v.vibrate(ms)
        }
    }

    /** Catch thump — heavier with the combo multiplier. */
    fun catchThump(intensity: Int) {
        when {
            intensity < 2 -> buzz(28, 150)
            intensity < 4 -> buzz(40, 210)
            else -> buzz(55, 255)
        }
    }

    fun tick() = buzz(15, 90)

    fun roar() = buzz(70, 255)

    fun gameOver() {
        val v = vibrator ?: return
        if (!v.hasVibrator()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            v.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 60, 40, 90), -1))
        } else {
            @Suppress("DEPRECATION")
            v.vibrate(longArrayOf(0, 60, 40, 90), -1)
        }
    }
}
