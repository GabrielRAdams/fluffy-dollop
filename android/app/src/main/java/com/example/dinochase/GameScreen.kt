package com.example.dinochase

import android.graphics.Paint
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.runtime.withFrameNanos

private val JungleTop = Color(0xFF8BD48E)
private val JungleBottom = Color(0xFF2E7D4F)
private val ButtonYellow = Color(0xFFFFE13B)
private val DeepGreen = Color(0xFF265926)

@Composable
fun GameScreen(state: GameState) {
    val engine = state.engine
    var frame by remember { mutableIntStateOf(0) }

    // Fixed-timestep-ish loop driven by the display's frame clock.
    LaunchedEffect(Unit) {
        var last = 0L
        while (true) {
            withFrameNanos { t ->
                val dt = if (last == 0L) 0.0 else (t - last) / 1_000_000_000.0
                last = t
                engine.update(dt)
                frame++
            }
        }
    }

    Box(Modifier.fillMaxSize()) {
        GameCanvas(engine) { frame }

        when (state.phase) {
            GameState.Phase.MENU -> StartMenu(state)
            GameState.Phase.PLAYING -> Hud(state)
            GameState.Phase.PAUSED -> { Hud(state); PauseOverlay(state) }
            GameState.Phase.GAME_OVER -> GameOverOverlay(state)
        }
    }
}

@Composable
private fun GameCanvas(engine: GameEngine, frame: () -> Int) {
    val emojiPaint = remember {
        Paint(Paint.ANTI_ALIAS_FLAG).apply { textAlign = Paint.Align.CENTER }
    }
    val shadowPaint = remember {
        Paint(Paint.ANTI_ALIAS_FLAG).apply { color = android.graphics.Color.argb(46, 0, 0, 0) }
    }
    val ringPaint = remember {
        Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    }

    Canvas(
        modifier = Modifier
            .fillMaxSize()
            .onSizeChanged { engine.setSize(Size(it.width.toFloat(), it.height.toFloat())) }
            .pointerInput(Unit) {
                awaitPointerEventScope {
                    while (true) {
                        val event = awaitPointerEvent()
                        val change = event.changes.lastOrNull()
                        engine.targetPoint = if (change != null && change.pressed) change.position else null
                    }
                }
            }
    ) {
        frame() // subscribe so the canvas redraws every frame

        drawRect(Brush.verticalGradient(listOf(JungleTop, JungleBottom)))

        drawIntoCanvas { canvas ->
            val nc = canvas.nativeCanvas
            nc.save()
            nc.translate(engine.shakeOffset.x, engine.shakeOffset.y)

            fun emoji(text: String, cx: Float, cy: Float, sizePx: Float, facing: Float = 1f) {
                emojiPaint.textSize = sizePx
                emojiPaint.alpha = 255
                val fm = emojiPaint.fontMetrics
                val baseline = cy - (fm.ascent + fm.descent) / 2f
                nc.save()
                if (facing < 0f) nc.scale(-1f, 1f, cx, cy)
                nc.drawText(text, cx, baseline, emojiPaint)
                nc.restore()
            }

            fun shadow(cx: Float, cy: Float, w: Float) {
                val h = w * 0.4f
                nc.drawOval(cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2, shadowPaint)
            }

            // Decorations
            for (d in engine.decorations) {
                emojiPaint.textSize = d.size
                emojiPaint.alpha = (d.alpha * 255).toInt()
                val fm = emojiPaint.fontMetrics
                nc.drawText(d.text, d.pos.x, d.pos.y - (fm.ascent + fm.descent) / 2f, emojiPaint)
            }
            emojiPaint.alpha = 255

            // Shockwaves (roar)
            for (s in engine.shockwaves) {
                val progress = s.age / 0.5f
                ringPaint.color = android.graphics.Color.argb(
                    ((1f - progress) * 230).toInt().coerceIn(0, 255), 255, 255, 255
                )
                ringPaint.strokeWidth = 8f
                nc.drawCircle(s.pos.x, s.pos.y, 30f + progress * 390f, ringPaint)
            }

            // Bananas (with a gentle bob)
            for (b in engine.bananas) {
                val bob = kotlin.math.sin(b.phase + (6.5f - b.life) * 4f) * 8f
                val fade = if (b.life < 0.4f) (b.life / 0.4f).coerceIn(0f, 1f) else 1f
                emojiPaint.alpha = (fade * 255).toInt()
                emoji("🍌", b.pos.x, b.pos.y + bob, 34f)
            }
            emojiPaint.alpha = 255

            // Monkeys + shadows
            for (m in engine.monkeys) {
                shadow(m.pos.x, m.pos.y + 18f, 30f)
                emoji("🐒", m.pos.x, m.pos.y, 40f * m.scale, m.facing)
            }

            // Dino + shadow
            shadow(engine.dinoPos.x, engine.dinoPos.y + 26f, 44f)
            emoji("🦖", engine.dinoPos.x, engine.dinoPos.y, 56f * engine.dinoScale, engine.dinoFacing)

            // Particles
            for (p in engine.particles) {
                val a = (p.life / p.maxLife).coerceIn(0f, 1f)
                if (p.text.length > 1 && p.text[0].isLetter()) {
                    emojiPaint.color = android.graphics.Color.WHITE
                    emojiPaint.isFakeBoldText = true
                }
                emojiPaint.textSize = p.size
                emojiPaint.alpha = (a * 255).toInt()
                val fm = emojiPaint.fontMetrics
                nc.drawText(p.text, p.pos.x, p.pos.y - (fm.ascent + fm.descent) / 2f, emojiPaint)
                emojiPaint.isFakeBoldText = false
                emojiPaint.color = android.graphics.Color.BLACK
            }
            emojiPaint.alpha = 255

            nc.restore()
        }
    }
}

// MARK: - Overlays

@Composable
private fun StartMenu(state: GameState) {
    Column(
        Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.25f)).padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text("🦖", fontSize = 88.sp)
        Text("DINO CHASE", color = Color.White, fontSize = 44.sp, fontWeight = FontWeight.Black)
        Spacer(Modifier.height(12.dp))
        Text(
            "Catch the cheeky monkeys 🐒 before time runs out!",
            color = Color.White, fontSize = 17.sp, textAlign = TextAlign.Center, fontWeight = FontWeight.Medium
        )
        Spacer(Modifier.height(8.dp))
        Text("Drag to steer · Chain catches for combos 🔥", color = Color.White.copy(0.85f), fontSize = 13.sp, textAlign = TextAlign.Center)
        Text("Grab bananas 🍌 · Fill the roar meter to freeze monkeys!", color = Color.White.copy(0.85f), fontSize = 13.sp, textAlign = TextAlign.Center)
        Spacer(Modifier.height(20.dp))

        DifficultyPicker(state)
        Spacer(Modifier.height(16.dp))

        if (state.highScore > 0) {
            Text("🏆 Best: ${state.highScore}", color = ButtonYellow, fontSize = 20.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(12.dp))
        }

        PillButton("PLAY", width = 220, height = 62) { state.start() }
    }
}

@Composable
private fun DifficultyPicker(state: GameState) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text("DIFFICULTY", color = Color.White.copy(0.8f), fontSize = 12.sp, fontWeight = FontWeight.Bold, letterSpacing = 2.sp)
        Spacer(Modifier.height(6.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            for (level in GameState.Difficulty.entries) {
                val selected = state.difficulty == level
                Box(
                    Modifier
                        .clip(RoundedCornerShape(50))
                        .background(if (selected) ButtonYellow else Color.Black.copy(0.3f))
                        .clickable { state.chooseDifficulty(level) }
                        .padding(horizontal = 14.dp, vertical = 9.dp)
                ) {
                    Text(
                        "${level.emoji} ${level.label}",
                        color = if (selected) DeepGreen else Color.White,
                        fontSize = 15.sp, fontWeight = FontWeight.Bold
                    )
                }
            }
        }
    }
}

@Composable
private fun Hud(state: GameState) {
    Column(Modifier.fillMaxSize().padding(16.dp)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.Top) {
            Badge("⭐ ${state.score}")
            Badge("⏱ ${state.timeRemaining.toInt().coerceAtLeast(0)}", danger = state.timeRemaining < 5)
            Box(
                Modifier.size(44.dp).clip(CircleShape).background(Color.Black.copy(0.35f))
                    .clickable(enabled = state.phase == GameState.Phase.PLAYING) { state.pause() },
                contentAlignment = Alignment.Center
            ) { Text("⏸", color = Color.White, fontSize = 20.sp) }
        }

        if (state.comboMultiplier >= 2) {
            Spacer(Modifier.height(10.dp))
            ComboMeter(state)
        }

        Spacer(Modifier.weight(1f))

        state.flashMessage?.let {
            Text(it, color = ButtonYellow, fontSize = 28.sp, fontWeight = FontWeight.Black, modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Center)
            Spacer(Modifier.height(10.dp))
        }

        Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
            RoarButton(state)
        }
        Spacer(Modifier.height(24.dp))
    }
}

@Composable
private fun Badge(text: String, danger: Boolean = false) {
    Box(
        Modifier.clip(RoundedCornerShape(50)).background(Color.Black.copy(0.35f)).padding(horizontal = 14.dp, vertical = 8.dp)
    ) {
        Text(text, color = if (danger) Color(0xFFFF5252) else Color.White, fontSize = 22.sp, fontWeight = FontWeight.Black)
    }
}

@Composable
private fun ComboMeter(state: GameState) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
        Text("🔥 COMBO x${state.comboMultiplier}", color = Color(0xFFFF9800), fontSize = 20.sp, fontWeight = FontWeight.Black)
        Spacer(Modifier.height(4.dp))
        val fraction = (state.comboTimeRemaining / state.comboWindow).coerceIn(0.0, 1.0).toFloat()
        Box(Modifier.width(140.dp).height(8.dp).clip(RoundedCornerShape(50)).background(Color.Black.copy(0.3f))) {
            Box(Modifier.fillMaxWidth(fraction).height(8.dp).clip(RoundedCornerShape(50)).background(Color(0xFFFF9800)))
        }
    }
}

@Composable
private fun RoarButton(state: GameState) {
    val ready = state.roarReady
    Box(
        Modifier
            .size(84.dp)
            .scale(if (ready) 1.08f else 1f)
            .clip(CircleShape)
            .background(Color.Black.copy(0.35f))
            .clickable(enabled = ready) { state.roar() },
        contentAlignment = Alignment.Center
    ) {
        Canvas(Modifier.size(78.dp)) {
            drawArc(
                color = if (ready) Color(0xFFFF9800) else ButtonYellow,
                startAngle = -90f,
                sweepAngle = (360f * state.roarCharge).toFloat(),
                useCenter = false,
                style = androidx.compose.ui.graphics.drawscope.Stroke(width = 7.dp.toPx(), cap = androidx.compose.ui.graphics.StrokeCap.Round)
            )
        }
        Text("🦖", fontSize = 38.sp)
        if (ready) {
            Text("ROAR", color = Color(0xFFFF9800), fontSize = 11.sp, fontWeight = FontWeight.Black, modifier = Modifier.padding(top = 60.dp))
        }
    }
}

@Composable
private fun PauseOverlay(state: GameState) {
    Column(
        Modifier.fillMaxSize().background(Color.Black.copy(0.5f)),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center
    ) {
        Text("PAUSED", color = Color.White, fontSize = 40.sp, fontWeight = FontWeight.Black)
        Spacer(Modifier.height(24.dp))
        PillButton("RESUME", width = 220, height = 58) { state.resume() }
        Spacer(Modifier.height(14.dp))
        Text("Quit to Menu", color = Color.White.copy(0.9f), fontSize = 18.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.clickable { state.toMenu() })
    }
}

@Composable
private fun GameOverOverlay(state: GameState) {
    val isBest = state.score >= state.highScore && state.score > 0
    Column(
        Modifier.fillMaxSize().background(Color.Black.copy(0.45f)).padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center
    ) {
        Text(if (state.score > 0) "🎉" else "😅", fontSize = 72.sp)
        Text("GAME OVER", color = Color.White, fontSize = 40.sp, fontWeight = FontWeight.Black)
        Spacer(Modifier.height(10.dp))
        Text("You scored ${state.score} point${if (state.score == 1) "" else "s"}!", color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.SemiBold)
        Spacer(Modifier.height(8.dp))
        Text(if (isBest) "🏆 NEW BEST!" else "🏆 Best: ${state.highScore}", color = ButtonYellow, fontSize = if (isBest) 24.sp else 18.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(24.dp))
        PillButton("PLAY AGAIN", width = 240, height = 58) { state.start() }
        Spacer(Modifier.height(14.dp))
        Text("Main Menu", color = Color.White.copy(0.9f), fontSize = 18.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.clickable { state.toMenu() })
    }
}

@Composable
private fun PillButton(label: String, width: Int, height: Int, onClick: () -> Unit) {
    Box(
        Modifier
            .width(width.dp).height(height.dp)
            .clip(RoundedCornerShape(50))
            .background(ButtonYellow)
            .clickable { onClick() },
        contentAlignment = Alignment.Center
    ) {
        Text(label, color = DeepGreen, fontSize = 24.sp, fontWeight = FontWeight.Black)
    }
}
