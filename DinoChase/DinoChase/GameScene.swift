import SpriteKit

/// One fleeing monkey: its emoji node, ground shadow, and current velocity.
private final class MonkeyActor {
    let node: SKLabelNode
    let shadow: SKShapeNode
    var velocity = CGVector(dx: 0, dy: 0)

    init(node: SKLabelNode, shadow: SKShapeNode) {
        self.node = node
        self.shadow = shadow
    }
}

/// The playfield. A player-steered dinosaur chases AI monkeys that flee.
/// Catch monkeys and grab bananas to score points and add time.
final class GameScene: SKScene {

    weak var gameState: GameState?

    // Player
    private var dino: SKLabelNode!
    private var dinoShadow: SKShapeNode!
    private var dinoVelocity = CGVector(dx: 0, dy: 0)

    // Monkeys
    private var monkeys: [MonkeyActor] = []

    // Bananas
    private var bananas: [SKLabelNode] = []
    private var bananaSpawnTimer: TimeInterval = 0

    // Camera (used for screen shake)
    private let cam = SKCameraNode()

    // Steering: the point the player is currently dragging toward.
    private var targetPoint: CGPoint?

    // Tuning — dino
    private let dinoAccel: CGFloat = 2600
    private let dinoMaxSpeed: CGFloat = 520
    private let dinoDrag: CGFloat = 3.0
    private let catchDistance: CGFloat = 46
    private let bananaCollectDistance: CGFloat = 44

    // Tuning — monkey
    private var monkeyMaxSpeed: CGFloat = 300
    private let monkeyFleeRadius: CGFloat = 300

    // Tuning — bananas
    private let bananaInterval: TimeInterval = 3.5
    private let maxBananas = 3
    private let bananaLifetime: TimeInterval = 6.5

    private var lastUpdate: TimeInterval = 0
    private var isRunning = false
    private var isPaused_ = false

    /// While > 0 the roar is active and every monkey is frozen in place.
    private var freezeTimer: TimeInterval = 0

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.53, green: 0.81, blue: 0.55, alpha: 1.0) // jungle green
        Haptics.shared.warmUp()

        camera = cam
        if cam.parent == nil { addChild(cam) }
        centerCamera()

        buildBackground()
        buildDino()
        resetToIdle()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        centerCamera()
        removeChildren(in: children.filter { $0.name == "decoration" })
        if dino != nil { buildBackground() }
    }

    private func centerCamera() {
        cam.position = CGPoint(x: size.width / 2, y: size.height / 2)
    }

    // MARK: - Scene building

    private func buildBackground() {
        let decos = ["🌴", "🌿", "🪨", "🌳", "🌵", "🍃"]
        for _ in 0..<14 {
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

    private func buildDino() {
        dinoShadow = makeShadow(width: 44)
        addChild(dinoShadow)

        dino = SKLabelNode(text: "🦖")
        dino.fontSize = 56
        dino.verticalAlignmentMode = .center
        dino.horizontalAlignmentMode = .center
        dino.zPosition = 10
        addChild(dino)
    }

    private func makeMonkey() -> MonkeyActor {
        let shadow = makeShadow(width: 30)
        addChild(shadow)

        let node = SKLabelNode(text: "🐒")
        node.fontSize = 40
        node.verticalAlignmentMode = .center
        node.horizontalAlignmentMode = .center
        node.zPosition = 9
        addChild(node)

        return MonkeyActor(node: node, shadow: shadow)
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
        isPaused_ = false
        targetPoint = nil
        dinoVelocity = .zero
        clearMonkeys()
        clearBananas()

        guard dino != nil else { return }
        dino.position = CGPoint(x: size.width * 0.5, y: size.height * 0.35)
        dino.setScale(1.0)
        syncDinoShadow()

        // One idle monkey wandering on the menu screen.
        spawnMonkey(near: CGPoint(x: size.width * 0.5, y: size.height * 0.7))
    }

    func startNewGame() {
        monkeyMaxSpeed = gameState?.difficulty.monkeyBaseSpeed ?? 300
        bananaSpawnTimer = 0
        freezeTimer = 0
        resetToIdle()
        isRunning = true
    }

    /// Freeze every monkey in place for `duration` seconds and play the roar
    /// shockwave. Frozen monkeys are sitting ducks — clean up the combo!
    func triggerRoar(duration: TimeInterval) {
        guard isRunning else { return }
        freezeTimer = duration
        shakeCamera(strength: 20)
        spawnShockwave(at: dino.position)

        for monkey in monkeys {
            monkey.velocity = .zero
            // A scared little wobble for the duration of the freeze.
            let wobble = SKAction.sequence([
                .rotate(toAngle: 0.18, duration: 0.08),
                .rotate(toAngle: -0.18, duration: 0.16),
                .rotate(toAngle: 0, duration: 0.08)
            ])
            monkey.node.run(.repeat(wobble, count: Int(duration / 0.32) + 1), withKey: "scared")
        }
    }

    func stopGame() {
        isRunning = false
        isPaused_ = false
        targetPoint = nil
    }

    func setPaused(_ paused: Bool) {
        isPaused_ = paused
        if paused { targetPoint = nil }
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isPaused_, let t = touches.first else { return }
        targetPoint = t.location(in: self)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isPaused_, let t = touches.first else { return }
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

        guard isRunning, !isPaused_, delta > 0 else { return }

        gameState?.tick(delta)
        guard isRunning else { return } // tick may have ended the game

        if freezeTimer > 0 { freezeTimer = max(0, freezeTimer - delta) }

        adjustMonkeyPopulation()
        updateDino(delta: CGFloat(delta))
        for monkey in monkeys { updateMonkey(monkey, delta: CGFloat(delta)) }
        updateBananas(delta: delta)

        syncDinoShadow()
        checkCatches()
        checkBananaPickups()
    }

    private func updateDino(delta: CGFloat) {
        if let target = targetPoint {
            let dir = normalize(CGVector(dx: target.x - dino.position.x,
                                         dy: target.y - dino.position.y))
            dinoVelocity.dx += dir.dx * dinoAccel * delta
            dinoVelocity.dy += dir.dy * dinoAccel * delta
        }
        dinoVelocity.dx -= dinoVelocity.dx * dinoDrag * delta
        dinoVelocity.dy -= dinoVelocity.dy * dinoDrag * delta
        clampSpeed(&dinoVelocity, max: dinoMaxSpeed)

        dino.position.x += dinoVelocity.dx * delta
        dino.position.y += dinoVelocity.dy * delta
        keepInBounds(&dino.position, margin: 30)

        if abs(dinoVelocity.dx) > 20 {
            dino.xScale = dinoVelocity.dx < 0 ? -abs(dino.xScale) : abs(dino.xScale)
        }
    }

    private func updateMonkey(_ monkey: MonkeyActor, delta: CGFloat) {
        let m = monkey.node

        // Frozen by a roar: hold position (bar a tiny shiver) and don't flee.
        if freezeTimer > 0 {
            monkey.velocity.dx -= monkey.velocity.dx * 12 * delta
            monkey.velocity.dy -= monkey.velocity.dy * 12 * delta
            m.position.x += monkey.velocity.dx * delta
            m.position.y += monkey.velocity.dy * delta
            monkey.shadow.position = CGPoint(x: m.position.x, y: m.position.y - 18)
            return
        }

        let toDino = CGVector(dx: dino.position.x - m.position.x,
                              dy: dino.position.y - m.position.y)
        let dist = length(toDino)

        var desired = CGVector(dx: 0, dy: 0)

        if dist < monkeyFleeRadius {
            let away = normalize(CGVector(dx: -toDino.dx, dy: -toDino.dy))
            let urgency = 1.0 - (dist / monkeyFleeRadius)
            desired.dx = away.dx * monkeyMaxSpeed
            desired.dy = away.dy * monkeyMaxSpeed
            // Perpendicular juke so the monkey dodges rather than running
            // straight into a corner.
            let perp = CGVector(dx: -away.dy, dy: away.dx)
            let juke = sin(CGFloat(lastUpdate) * 3.0 + m.position.x * 0.01) * urgency
            desired.dx += perp.dx * monkeyMaxSpeed * juke * 0.6
            desired.dy += perp.dy * monkeyMaxSpeed * juke * 0.6
        } else {
            let wander = CGVector(dx: sin(CGFloat(lastUpdate) * 1.3 + m.position.y * 0.01),
                                  dy: cos(CGFloat(lastUpdate) * 0.9 + m.position.x * 0.01))
            desired.dx = wander.dx * monkeyMaxSpeed * 0.35
            desired.dy = wander.dy * monkeyMaxSpeed * 0.35
        }

        let avoid = wallAvoidance(for: m.position)
        desired.dx += avoid.dx
        desired.dy += avoid.dy

        monkey.velocity.dx += (desired.dx - monkey.velocity.dx) * 6 * delta
        monkey.velocity.dy += (desired.dy - monkey.velocity.dy) * 6 * delta
        clampSpeed(&monkey.velocity, max: monkeyMaxSpeed)

        m.position.x += monkey.velocity.dx * delta
        m.position.y += monkey.velocity.dy * delta
        keepInBounds(&m.position, margin: 24)

        if abs(monkey.velocity.dx) > 15 {
            m.xScale = monkey.velocity.dx < 0 ? -abs(m.xScale) : abs(m.xScale)
        }
        monkey.shadow.position = CGPoint(x: m.position.x, y: m.position.y - 18)
    }

    private func wallAvoidance(for p: CGPoint) -> CGVector {
        let margin: CGFloat = 80
        let strength: CGFloat = 260
        var push = CGVector(dx: 0, dy: 0)
        if p.x < margin { push.dx += strength * (1 - p.x / margin) }
        if p.x > size.width - margin { push.dx -= strength * (1 - (size.width - p.x) / margin) }
        if p.y < margin { push.dy += strength * (1 - p.y / margin) }
        if p.y > size.height - margin { push.dy -= strength * (1 - (size.height - p.y) / margin) }
        return push
    }

    // MARK: - Monkey population

    /// Scale the number of monkeys with the score: one more every 5 catches,
    /// up to four on the field at once.
    private func adjustMonkeyPopulation() {
        let score = gameState?.score ?? 0
        let target = min(1 + score / 5, 4)
        while monkeys.count < target {
            spawnMonkey(near: farthestSpawnPoint())
        }
    }

    private func spawnMonkey(near point: CGPoint) {
        let monkey = makeMonkey()
        monkey.node.position = point
        monkey.shadow.position = CGPoint(x: point.x, y: point.y - 18)
        monkey.node.setScale(0.1)
        monkey.node.run(.sequence([.scale(to: 1.15, duration: 0.12),
                                   .scale(to: 1.0, duration: 0.08)]))
        monkeys.append(monkey)
    }

    private func clearMonkeys() {
        for monkey in monkeys {
            monkey.node.removeFromParent()
            monkey.shadow.removeFromParent()
        }
        monkeys.removeAll()
    }

    // MARK: - Catching

    private func checkCatches() {
        let ramp = gameState?.difficulty.speedRamp ?? 26
        for monkey in monkeys where distance(dino.position, monkey.node.position) < catchDistance {
            gameState?.caughtMonkey()
            monkeyMaxSpeed = min(monkeyMaxSpeed + ramp, 600)
            spawnCatchBurst(at: monkey.node.position)
            shakeCamera(strength: 10)

            // Respawn this monkey far from the dino for a fair restart.
            let p = farthestSpawnPoint()
            monkey.node.removeAction(forKey: "scared")
            monkey.node.zRotation = 0
            monkey.node.position = p
            monkey.shadow.position = CGPoint(x: p.x, y: p.y - 18)
            monkey.velocity = .zero
            monkey.node.setScale(0.1)
            monkey.node.run(.sequence([.scale(to: 1.15, duration: 0.12),
                                       .scale(to: 1.0, duration: 0.08)]))

            dino.run(.sequence([.scale(to: 1.25, duration: 0.08),
                                .scale(to: 1.0, duration: 0.1)]))
        }
    }

    private func farthestSpawnPoint() -> CGPoint {
        var best = CGPoint(x: size.width * 0.5, y: size.height * 0.7)
        var bestDist: CGFloat = 0
        for _ in 0..<10 {
            let candidate = CGPoint(x: CGFloat.random(in: 40...(size.width - 40)),
                                    y: CGFloat.random(in: 40...(size.height - 40)))
            let dd = dino != nil ? distance(candidate, dino.position) : 999
            if dd > bestDist { bestDist = dd; best = candidate }
        }
        return best
    }

    // MARK: - Bananas

    private func updateBananas(delta: TimeInterval) {
        bananaSpawnTimer += delta
        if bananaSpawnTimer >= bananaInterval && bananas.count < maxBananas {
            bananaSpawnTimer = 0
            spawnBanana()
        }
    }

    private func spawnBanana() {
        let banana = SKLabelNode(text: "🍌")
        banana.fontSize = 34
        banana.verticalAlignmentMode = .center
        banana.horizontalAlignmentMode = .center
        banana.zPosition = 8
        banana.position = CGPoint(x: CGFloat.random(in: 50...(size.width - 50)),
                                  y: CGFloat.random(in: 90...(size.height - 90)))
        banana.setScale(0.1)
        addChild(banana)
        bananas.append(banana)

        // Pop in, bob gently, then fade out and despawn after its lifetime.
        let bob = SKAction.repeatForever(.sequence([
            .moveBy(x: 0, y: 8, duration: 0.5),
            .moveBy(x: 0, y: -8, duration: 0.5)
        ]))
        banana.run(.scale(to: 1.0, duration: 0.15))
        banana.run(bob, withKey: "bob")
        banana.run(.sequence([
            .wait(forDuration: bananaLifetime),
            .fadeOut(withDuration: 0.3),
            .run { [weak self, weak banana] in
                guard let banana = banana else { return }
                self?.bananas.removeAll { $0 === banana }
                banana.removeFromParent()
            }
        ]))
    }

    private func checkBananaPickups() {
        for banana in bananas where banana.parent != nil &&
            distance(dino.position, banana.position) < bananaCollectDistance {
            gameState?.collectedBanana()
            bananas.removeAll { $0 === banana }
            banana.removeAllActions()
            banana.run(.sequence([
                .group([.scale(to: 1.6, duration: 0.2), .fadeOut(withDuration: 0.2)]),
                .removeFromParent()
            ]))
        }
    }

    private func clearBananas() {
        for banana in bananas { banana.removeFromParent() }
        bananas.removeAll()
        bananaSpawnTimer = 0
    }

    // MARK: - Juice

    private func spawnCatchBurst(at point: CGPoint) {
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
    }

    /// An expanding ring radiating out from the dino when it roars.
    private func spawnShockwave(at point: CGPoint) {
        let ring = SKShapeNode(circleOfRadius: 30)
        ring.position = point
        ring.strokeColor = SKColor.white.withAlphaComponent(0.9)
        ring.lineWidth = 8
        ring.fillColor = .clear
        ring.zPosition = 25
        addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 14, duration: 0.5), .fadeOut(withDuration: 0.5)]),
            .removeFromParent()
        ]))

        let roarText = SKLabelNode(text: "ROAR!")
        roarText.fontName = "AvenirNext-Heavy"
        roarText.fontSize = 44
        roarText.fontColor = .white
        roarText.position = CGPoint(x: point.x, y: point.y + 50)
        roarText.zPosition = 26
        addChild(roarText)
        roarText.run(.sequence([
            .group([.moveBy(x: 0, y: 40, duration: 0.6), .fadeOut(withDuration: 0.6)]),
            .removeFromParent()
        ]))
    }

    private func shakeCamera(strength: CGFloat) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        var actions: [SKAction] = []
        for i in 0..<6 {
            let decay = strength * (1 - CGFloat(i) / 6)
            let dx = CGFloat.random(in: -decay...decay)
            let dy = CGFloat.random(in: -decay...decay)
            actions.append(.move(to: CGPoint(x: center.x + dx, y: center.y + dy), duration: 0.03))
        }
        actions.append(.move(to: center, duration: 0.03))
        cam.run(.sequence(actions))
    }

    private func syncDinoShadow() {
        guard dino != nil else { return }
        dinoShadow.position = CGPoint(x: dino.position.x, y: dino.position.y - 26)
    }

    // MARK: - Vector helpers

    private func normalize(_ v: CGVector) -> CGVector {
        let len = length(v)
        guard len > 0.0001 else { return CGVector(dx: 0, dy: 0) }
        return CGVector(dx: v.dx / len, dy: v.dy / len)
    }

    private func length(_ v: CGVector) -> CGFloat { sqrt(v.dx * v.dx + v.dy * v.dy) }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

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
