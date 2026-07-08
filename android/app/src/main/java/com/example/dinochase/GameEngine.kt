package com.example.dinochase

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.random.Random

/** A fleeing monkey: position, velocity, facing and a pop-in scale. */
class Monkey(
    var pos: Offset,
    var vel: Offset = Offset.Zero,
    var scale: Float = 1f,
    var facing: Float = 1f,
)

/** A short-lived visual particle (catch sparkle, roar text). */
class Particle(
    var pos: Offset,
    val vel: Offset,
    var life: Float,
    val maxLife: Float,
    val text: String,
    val size: Float,
)

/** A collectible banana with a bob offset and remaining lifetime. */
class Banana(val pos: Offset, var life: Float, val phase: Float)

/** An expanding roar shockwave ring. */
class Shockwave(val pos: Offset, var age: Float)

/** A static jungle decoration. */
class Decoration(val pos: Offset, val text: String, val size: Float, val alpha: Float)

/**
 * All gameplay simulation. Holds mutable entity state and advances it each
 * frame; the Compose layer reads these lists to draw. Ported from the iOS
 * `GameScene`, adapted to a top-left, y-down coordinate space.
 */
class GameEngine(private val state: GameState) {

    var size = Size(1080f, 1920f)
        private set

    // Player
    var dinoPos = Offset(540f, 1200f)
    var dinoVel = Offset.Zero
    var dinoScale = 1f
    var dinoFacing = 1f

    val monkeys = mutableListOf<Monkey>()
    val bananas = mutableListOf<Banana>()
    val particles = mutableListOf<Particle>()
    val shockwaves = mutableListOf<Shockwave>()
    val decorations = mutableListOf<Decoration>()

    var targetPoint: Offset? = null
    var shakeOffset = Offset.Zero
        private set

    var running = false
    var paused = false

    private var monkeyMaxSpeed = 300f
    private var bananaSpawnTimer = 0f
    private var freezeTimer = 0f
    private var shakeTimer = 0f
    private var shakeStrength = 0f
    private var elapsed = 0f

    // Tuning — dino
    private val dinoAccel = 2600f
    private val dinoMaxSpeed = 520f
    private val dinoDrag = 3f
    private val catchDistance = 46f
    private val bananaCollectDistance = 44f

    // Tuning — monkey
    private val monkeyFleeRadius = 300f

    // Tuning — bananas
    private val bananaInterval = 3.5f
    private val maxBananas = 3
    private val bananaLifetime = 6.5f

    // MARK: - Setup

    fun setSize(newSize: Size) {
        if (newSize.width <= 0 || newSize.height <= 0) return
        val first = decorations.isEmpty()
        size = newSize
        if (first) {
            buildDecorations()
            resetToIdle()
        }
    }

    private fun buildDecorations() {
        decorations.clear()
        val decos = listOf("🌴", "🌿", "🪨", "🌳", "🌵", "🍃")
        repeat(14) {
            decorations.add(
                Decoration(
                    pos = Offset(Random.nextFloat() * size.width, Random.nextFloat() * size.height),
                    text = decos.random(),
                    size = 28f + Random.nextFloat() * 26f,
                    alpha = 0.5f,
                )
            )
        }
    }

    // MARK: - Control

    fun resetToIdle() {
        running = false
        paused = false
        targetPoint = null
        dinoVel = Offset.Zero
        dinoScale = 1f
        monkeys.clear()
        bananas.clear()
        particles.clear()
        shockwaves.clear()
        freezeTimer = 0f
        dinoPos = Offset(size.width * 0.5f, size.height * 0.65f)
        spawnMonkey(Offset(size.width * 0.5f, size.height * 0.3f))
    }

    fun startNewGame() {
        monkeyMaxSpeed = state.difficulty.monkeyBaseSpeed
        bananaSpawnTimer = 0f
        resetToIdle()
        running = true
    }

    fun stopGame() {
        running = false
        paused = false
        targetPoint = null
    }

    fun triggerRoar(duration: Double) {
        if (!running) return
        freezeTimer = duration.toFloat()
        shake(20f)
        shockwaves.add(Shockwave(dinoPos, 0f))
        particles.add(
            Particle(dinoPos.copy(y = dinoPos.y - 60f), Offset(0f, -60f), 0.6f, 0.6f, "ROAR!", 96f)
        )
        for (m in monkeys) m.vel = Offset.Zero
    }

    // MARK: - Main step

    fun update(dtRaw: Double) {
        val dt = dtRaw.toFloat().coerceIn(0f, 1f / 30f)
        if (dt <= 0f) return
        elapsed += dt

        updateShake(dt)
        easeScales(dt)
        updateParticles(dt)
        updateShockwaves(dt)

        // Menu / paused: keep the idle monkey wandering so the scene feels alive.
        if (!running || paused) {
            for (m in monkeys) wander(m, dt)
            return
        }

        if (freezeTimer > 0f) freezeTimer = (freezeTimer - dt).coerceAtLeast(0f)

        state.tick(dt.toDouble())
        if (!running) return  // tick may have ended the game

        adjustMonkeyPopulation()
        updateDino(dt)
        for (m in monkeys) updateMonkey(m, dt)
        updateBananas(dt)
        checkCatches()
        checkBananaPickups()
    }

    private fun updateDino(dt: Float) {
        targetPoint?.let { t ->
            val dir = normalize(t - dinoPos)
            dinoVel += dir * (dinoAccel * dt)
        }
        dinoVel -= dinoVel * (dinoDrag * dt)
        dinoVel = clampSpeed(dinoVel, dinoMaxSpeed)

        dinoPos = keepInBounds(dinoPos + dinoVel * dt, 30f)
        if (abs(dinoVel.x) > 20f) dinoFacing = if (dinoVel.x < 0f) -1f else 1f
    }

    private fun updateMonkey(m: Monkey, dt: Float) {
        // Frozen by a roar: hold position (bar a shiver) and don't flee.
        if (freezeTimer > 0f) {
            m.vel -= m.vel * (12f * dt)
            m.pos = keepInBounds(m.pos + m.vel * dt, 24f)
            return
        }

        val toDino = dinoPos - m.pos
        val dist = length(toDino)
        var desired: Offset

        if (dist < monkeyFleeRadius) {
            val away = normalize(-toDino)
            val urgency = 1f - dist / monkeyFleeRadius
            desired = away * monkeyMaxSpeed
            val perp = Offset(-away.y, away.x)
            val juke = sin(elapsed * 3f + m.pos.x * 0.01f) * urgency
            desired += perp * (monkeyMaxSpeed * juke * 0.6f)
        } else {
            desired = Offset(
                sin(elapsed * 1.3f + m.pos.y * 0.01f),
                cos(elapsed * 0.9f + m.pos.x * 0.01f)
            ) * (monkeyMaxSpeed * 0.35f)
        }

        desired += wallAvoidance(m.pos)

        m.vel += (desired - m.vel) * (6f * dt)
        m.vel = clampSpeed(m.vel, monkeyMaxSpeed)
        m.pos = keepInBounds(m.pos + m.vel * dt, 24f)
        if (abs(m.vel.x) > 15f) m.facing = if (m.vel.x < 0f) -1f else 1f
    }

    /** Idle wander used on the menu screen (dino stationary). */
    private fun wander(m: Monkey, dt: Float) {
        val desired = Offset(sin(elapsed * 1.1f), cos(elapsed * 0.8f)) * 90f + wallAvoidance(m.pos)
        m.vel += (desired - m.vel) * (3f * dt)
        m.vel = clampSpeed(m.vel, 120f)
        m.pos = keepInBounds(m.pos + m.vel * dt, 24f)
        if (abs(m.vel.x) > 15f) m.facing = if (m.vel.x < 0f) -1f else 1f
    }

    private fun wallAvoidance(p: Offset): Offset {
        val margin = 80f
        val strength = 260f
        var push = Offset.Zero
        if (p.x < margin) push += Offset(strength * (1 - p.x / margin), 0f)
        if (p.x > size.width - margin) push += Offset(-strength * (1 - (size.width - p.x) / margin), 0f)
        if (p.y < margin) push += Offset(0f, strength * (1 - p.y / margin))
        if (p.y > size.height - margin) push += Offset(0f, -strength * (1 - (size.height - p.y) / margin))
        return push
    }

    // MARK: - Monkey population

    private fun adjustMonkeyPopulation() {
        val target = (1 + state.score / 5).coerceAtMost(4)
        while (monkeys.size < target) spawnMonkey(farthestSpawnPoint())
    }

    private fun spawnMonkey(at: Offset) {
        monkeys.add(Monkey(pos = at, scale = 0.1f))
    }

    private fun farthestSpawnPoint(): Offset {
        var best = Offset(size.width * 0.5f, size.height * 0.3f)
        var bestDist = 0f
        repeat(10) {
            val c = Offset(
                40f + Random.nextFloat() * (size.width - 80f),
                40f + Random.nextFloat() * (size.height - 80f)
            )
            val d = length(c - dinoPos)
            if (d > bestDist) { bestDist = d; best = c }
        }
        return best
    }

    // MARK: - Catching

    private fun checkCatches() {
        val ramp = state.difficulty.speedRamp
        for (m in monkeys) {
            if (length(m.pos - dinoPos) < catchDistance) {
                state.caughtMonkey()
                monkeyMaxSpeed = (monkeyMaxSpeed + ramp).coerceAtMost(600f)
                spawnCatchBurst(m.pos)
                shake(10f)
                dinoScale = 1.25f

                val p = farthestSpawnPoint()
                m.pos = p
                m.vel = Offset.Zero
                m.scale = 0.1f
            }
        }
    }

    // MARK: - Bananas

    private fun updateBananas(dt: Float) {
        bananaSpawnTimer += dt
        if (bananaSpawnTimer >= bananaInterval && bananas.size < maxBananas) {
            bananaSpawnTimer = 0f
            bananas.add(
                Banana(
                    pos = Offset(
                        50f + Random.nextFloat() * (size.width - 100f),
                        90f + Random.nextFloat() * (size.height - 180f)
                    ),
                    life = bananaLifetime,
                    phase = Random.nextFloat() * 6.28f
                )
            )
        }
        val it = bananas.iterator()
        while (it.hasNext()) {
            val b = it.next()
            b.life -= dt
            if (b.life <= 0f) it.remove()
        }
    }

    private fun checkBananaPickups() {
        val it = bananas.iterator()
        while (it.hasNext()) {
            val b = it.next()
            if (length(b.pos - dinoPos) < bananaCollectDistance) {
                state.collectedBanana()
                spawnCatchBurst(b.pos, small = true)
                it.remove()
            }
        }
    }

    // MARK: - Juice

    private fun spawnCatchBurst(at: Offset, small: Boolean = false) {
        val glyphs = listOf("⭐️", "✨", "💥", "🍌")
        val n = if (small) 5 else 8
        repeat(n) {
            val angle = Random.nextFloat() * 6.283f
            val speed = 80f + Random.nextFloat() * 140f
            particles.add(
                Particle(
                    pos = at,
                    vel = Offset(cos(angle) * speed, sin(angle) * speed),
                    life = 0.5f,
                    maxLife = 0.5f,
                    text = glyphs.random(),
                    size = 36f + Random.nextFloat() * 24f
                )
            )
        }
    }

    private fun updateParticles(dt: Float) {
        val it = particles.iterator()
        while (it.hasNext()) {
            val p = it.next()
            p.life -= dt
            if (p.life <= 0f) { it.remove(); continue }
            p.pos += p.vel * dt
        }
    }

    private fun updateShockwaves(dt: Float) {
        val it = shockwaves.iterator()
        while (it.hasNext()) {
            val s = it.next()
            s.age += dt
            if (s.age >= 0.5f) it.remove()
        }
    }

    private fun easeScales(dt: Float) {
        dinoScale += (1f - dinoScale) * (10f * dt)
        for (m in monkeys) m.scale += (1f - m.scale) * (12f * dt)
    }

    private fun shake(strength: Float) {
        shakeStrength = strength
        shakeTimer = 0.18f
    }

    private fun updateShake(dt: Float) {
        if (shakeTimer <= 0f) { shakeOffset = Offset.Zero; return }
        shakeTimer -= dt
        val mag = shakeStrength * (shakeTimer / 0.18f).coerceAtLeast(0f)
        shakeOffset = Offset(
            (Random.nextFloat() * 2 - 1) * mag,
            (Random.nextFloat() * 2 - 1) * mag
        )
    }

    // MARK: - Vector helpers

    private fun length(v: Offset) = hypot(v.x, v.y)

    private fun normalize(v: Offset): Offset {
        val len = sqrt(v.x * v.x + v.y * v.y)
        return if (len > 0.0001f) v / len else Offset.Zero
    }

    private fun clampSpeed(v: Offset, max: Float): Offset {
        val spd = length(v)
        return if (spd > max) v / spd * max else v
    }

    private fun keepInBounds(p: Offset, margin: Float): Offset {
        val x = p.x.coerceIn(margin, size.width - margin)
        val y = p.y.coerceIn(margin, size.height - margin)
        return Offset(x, y)
    }
}
