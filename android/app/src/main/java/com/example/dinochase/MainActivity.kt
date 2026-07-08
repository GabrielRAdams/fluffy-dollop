package com.example.dinochase

import android.content.Context
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        // Games shouldn't dim/sleep mid-play.
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        val prefs = getSharedPreferences("dinochase", Context.MODE_PRIVATE)
        val haptics = Haptics(this)
        val state = GameState(haptics, prefs)
        state.engine = GameEngine(state)

        setContent { GameScreen(state) }
    }
}
