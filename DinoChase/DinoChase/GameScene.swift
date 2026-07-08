import SpriteKit

/// The playfield. A player-steered dinosaur chases an AI monkey that flees.
/// Catch the monkey to score points and add time.
final class GameScene: SKScene {

    weak var gameState: GameState?

    // Actors
    private var dino: SKLabelNode!
    private var dinoShadow: SKShapeNode!
    private var monkey: SKLabelNode!
    private var monkeyShadow: SKShapeNode!

    // Steering: the point the player is currently dragging toward.
    private var targetPoint: CGPoint?

    // Velocities
    private var dinoVelocity = CGVector(dx: 0, dy: 0)
    private var monkeyVelocity = CGVector(dx: 0, dy: 0)

    // Tuning
    private let dinoAccel: CGFloat = 2600      // points/s^2 toward finger
    private let dinoMaxSpeed: CGFloat = 520     // points/s
    private let dinoDrag: CGFloat = 3.0         // velocity damping
    private var monkeyMaxSpeed: CGFloat = 300   // ramps up per catch
    private let monkeyFleeRadius: CGFloat = 300 // starts fleeing within this range
    private let catchDistance: CGFloat = 46

    private var lastUpdate: TimeInterval = 0
    private var isRunning = false

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.53, green: 0.81, blue: 0.55, alpha: 1.0) // jungle green
        buildBackground()
        buildActors()
        resetToIdle()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        // Keep decorations sensible if the view resizes (rotation, etc.).
        removeChildren(in: children.filter { $0.name == "decoration" })
        if dino != nil { buildBackground() }
    }

    // MARK: - Scene building

    private func buildBackground() {
        // Scatter some simple jungle decorations.
        let decos = ["🌴", "🌿", "🪨", "🌳", "🌵", "🍃"]
        let count = 14
        for _ in 0..<count {
            let node = SKLabelNode(text: decos.randomElement())
            node.name = "decoration"
            node.fontSize = CGFloat.random(in: 28...54)
            node.alpha = 0.5
            node.zPosition = -10
            node.position = CGPoint(x: CGFloat.random(in: 0...size.width),
                                    y: CGFloat.random(in: 0...size.height))
            addChild(node)
        }
    }

    private func buildActors() {
        // Shadows give the emoji actors a grounded feel.
        dinoShadow = makeShadow(width: 44)
        addChild(dinoShadow)
        monkeyShadow = makeShadow(width: 30)
        addChild(monkeyShadow)

        dino = SKLabelNode(text: "🦖")
        dino.fontSize = 56
        dino.verticalAlignmentMode = .center
        dino.horizontalAlignmentMode = .center
        dino.zPosition = 10
        addChild(dino)

        monkey = SKLabelNode(text: "🐒")
        monkey.fontSize = 40
        monkey.verticalAlignmentMode = .center
        monkey.horizontalAlignmentMode = .center
        monkey.zPosition = 9
        addChild(monkey)
    }

    private func makeShadow(width: CGFloat) -> SKShapeNode {
        let node = SKShapeNode(ellipseOf: CGSize(width: width, height: width * 0.4))
        node.fillColor = SKColor.black.withAlphaComponent(0.18)
        node.strokeColor = .clear
        node.zPosition = 1
        return node
    }

    // MARK: - Game control (called from GameState)

    func resetToIdle() {
        isRunning = false
        targetPoint = nil
        dinoVelocity = .zero
        monkeyVelocity = .zero
        guard dino != nil else { return }
        dino.position = CGPoint(x: size.width * 0.5, y: size.height * 0.35)
        monkey.position = CGPoint(x: size.width * 0.5, y: size.height * 0.7)
        syncShadows()
        dino.setScale(1.0)
        monkey.setScale(1.0)
    }

    func startNewGame() {
        monkeyMaxSpeed = 300
        resetToIdle()
        isRunning = true
    }

    func stopGame() {
        isRunning = false
        targetPoint = nil
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        targetPoint = t.location(in: self)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        targetPoint = t.location(in: self)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        targetPoint = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        targetPoint = nil
    }

    // MARK: - Main loop

    override func update(_ currentTime: TimeInterval) {
        let delta = lastUpdate == 0 ? 0 : min(currentTime - lastUpdate, 1.0 / 30.0)
        lastUpdate = currentTime

        guard isRunning, delta > 0 else { return }

        gameState?.tick(delta)
        guard isRunning else { return } // tick may have ended the game

        updateDino(delta: CGFloat(delta))
        updateMonkey(delta: CGFloat(delta))
        syncShadows()
        checkCatch()
    }

    private func updateDino(delta: CGFloat) {
        if let target = targetPoint {
            let dir = normalize(CGVector(dx: target.x - dino.position.x,
                                         dy: target.y - dino.position.y))
            dinoVelocity.dx += dir.dx * dinoAccel * delta
            dinoVelocity.dy += dir.dy * dinoAccel * delta
        }
        // Drag / damping.
        dinoVelocity.dx -= dinoVelocity.dx * dinoDrag * delta
        dinoVelocity.dy -= dinoVelocity.dy * dinoDrag * delta

        clampSpeed(&dinoVelocity, max: dinoMaxSpeed)

        dino.position.x += dinoVelocity.dx * delta
        dino.position.y += dinoVelocity.dy * delta
        keepInBounds(&dino.position, margin: 30)

        // Face travel direction (flip horizontally).
        if abs(dinoVelocity.dx) > 20 {
            dino.xScale = dinoVelocity.dx < 0 ? -1 : 1
        }
    }

    private func updateMonkey(delta: CGFloat) {
        let toDino = CGVector(dx: dino.position.x - monkey.position.x,
                              dy: dino.position.y - monkey.position.y)
        let dist = length(toDino)

        var desired = CGVector(dx: 0, dy: 0)

        if dist < monkeyFleeRadius {
            // Flee directly away from the dino, more urgently when close.
            let away = normalize(CGVector(dx: -toDino.dx, dy: -toDino.dy))
            let urgency = 1.0 - (dist / monkeyFleeRadius) // 0..1
            desired.dx = away.dx * monkeyMaxSpeed
            desired.dy = away.dy * monkeyMaxSpeed
            // Add a perpendicular juke so the monkey dodges rather than runs
            // straight into a corner.
            let perp = CGVector(dx: -away.dy, dy: away.dx)
            let juke = sin(CGFloat(lastUpdate) * 3.0) * urgency
            desired.dx += perp.dx * monkeyMaxSpeed * juke * 0.6
            desired.dy += perp.dy * monkeyMaxSpeed * juke * 0.6
        } else {
            // Wander idly when the dino is far away.
            let wander = CGVector(dx: sin(CGFloat(lastUpdate) * 1.3),
                                  dy: cos(CGFloat(lastUpdate) * 0.9))
            desired.dx = wander.dx * monkeyMaxSpeed * 0.35
            desired.dy = wander.dy * monkeyMaxSpeed * 0.35
        }

        // Steer away from walls so the monkey doesn't trap itself.
        desired.dx += wallAvoidance().dx
        desired.dy += wallAvoidance().dy

        // Ease toward desired velocity.
        monkeyVelocity.dx += (desired.dx - monkeyVelocity.dx) * 6 * delta
        monkeyVelocity.dy += (desired.dy - monkeyVelocity.dy) * 6 * delta
        clampSpeed(&monkeyVelocity, max: monkeyMaxSpeed)

        monkey.position.x += monkeyVelocity.dx * delta
        monkey.position.y += monkeyVelocity.dy * delta
        keepInBounds(&monkey.position, margin: 24)

        if abs(monkeyVelocity.dx) > 15 {
            monkey.xScale = monkeyVelocity.dx < 0 ? -1 : 1
        }
    }

    private func wallAvoidance() -> CGVector {
        let margin: CGFloat = 80
        let strength: CGFloat = 260
        var push = CGVector(dx: 0, dy: 0)
        let p = monkey.position
        if p.x < margin { push.dx += strength * (1 - p.x / margin) }
        if p.x > size.width - margin { push.dx -= strength * (1 - (size.width - p.x) / margin) }
        if p.y < margin { push.dy += strength * (1 - p.y / margin) }
        if p.y > size.height - margin { push.dy -= strength * (1 - (size.height - p.y) / margin) }
        return push
    }

    private func checkCatch() {
        let d = distance(dino.position, monkey.position)
        guard d < catchDistance else { return }

        gameState?.caughtMonkey()
        monkeyMaxSpeed = min(monkeyMaxSpeed + 26, 560) // gets harder each catch
        spawnCatchBurst(at: monkey.position)
        respawnMonkey()
    }

    private func respawnMonkey() {
        // Place the monkey far from the dino for a fair restart.
        var best = monkey.position
        var bestDist: CGFloat = 0
        for _ in 0..<8 {
            let candidate = CGPoint(x: CGFloat.random(in: 40...(size.width - 40)),
                                    y: CGFloat.random(in: 40...(size.height - 40)))
            let dd = distance(candidate, dino.position)
            if dd > bestDist { bestDist = dd; best = candidate }
        }
        monkey.position = best
        monkeyVelocity = .zero

        // Little pop-in animation.
        monkey.setScale(0.1)
        monkey.run(.sequence([.scale(to: 1.15, duration: 0.12), .scale(to: 1.0, duration: 0.08)]))
    }

    private func spawnCatchBurst(at point: CGPoint) {
        // Star burst using a few short-lived emoji.
        for _ in 0..<8 {
            let spark = SKLabelNode(text: ["⭐️", "✨", "💥", "🍌"].randomElement())
            spark.fontSize = CGFloat.random(in: 18...30)
            spark.position = point
            spark.zPosition = 20
            addChild(spark)
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let dist = CGFloat.random(in: 40...110)
            let move = SKAction.move(by: CGVector(dx: cos(angle) * dist, dy: sin(angle) * dist),
                                     duration: 0.5)
            move.timingMode = .easeOut
            spark.run(.sequence([.group([move, .fadeOut(withDuration: 0.5)]), .removeFromParent()]))
        }
        // Dino chomp squash.
        dino.run(.sequence([.scale(to: 1.25, duration: 0.08), .scale(to: 1.0, duration: 0.1)]))
    }

    private func syncShadows() {
        guard dino != nil else { return }
        dinoShadow.position = CGPoint(x: dino.position.x, y: dino.position.y - 26)
        monkeyShadow.position = CGPoint(x: monkey.position.x, y: monkey.position.y - 18)
    }

    // MARK: - Vector helpers

    private func normalize(_ v: CGVector) -> CGVector {
        let len = length(v)
        guard len > 0.0001 else { return CGVector(dx: 0, dy: 0) }
        return CGVector(dx: v.dx / len, dy: v.dy / len)
    }

    private func length(_ v: CGVector) -> CGFloat {
        sqrt(v.dx * v.dx + v.dy * v.dy)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private func clampSpeed(_ v: inout CGVector, max maxSpeed: CGFloat) {
        let spd = length(v)
        if spd > maxSpeed {
            v.dx = v.dx / spd * maxSpeed
            v.dy = v.dy / spd * maxSpeed
        }
    }

    private func keepInBounds(_ p: inout CGPoint, margin: CGFloat) {
        p.x = min(max(p.x, margin), size.width - margin)
        p.y = min(max(p.y, margin), size.height - margin)
    }
}
