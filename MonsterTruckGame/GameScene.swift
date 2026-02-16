import SpriteKit

struct PhysicsCategory {
    static let none: UInt32     = 0
    static let truck: UInt32    = 0b1
    static let wheel: UInt32    = 0b10
    static let ground: UInt32   = 0b100
    static let boundary: UInt32 = 0b1000
}

class GameScene: SKScene {

    // MARK: - Properties
    private var truckBody: SKSpriteNode!
    private var frontWheel: SKShapeNode!
    private var rearWheel: SKShapeNode!
    private var cameraNode: SKCameraNode!
    private var controllerManager = ControllerManager()
    private var trickSystem = TrickSystem()
    private var levelGenerator: LevelGenerator!

    private let groundY: CGFloat = 200
    private var accelerateInput: Float = 0
    private var brakeInput: Float = 0
    private var leanInput: Float = 0
    private var isAirborne = false
    private var isCrashed = false
    private var lastRotation: CGFloat = 0

    // UI
    private var scoreLabel: SKLabelNode!
    private var comboLabel: SKLabelNode!
    private var trickLabel: SKLabelNode!
    private var speedLabel: SKLabelNode!
    private var crashOverlay: SKNode?

    // MARK: - Scene Setup
    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)

        physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)
        physicsWorld.contactDelegate = self

        setupCamera()
        setupTerrain()
        setupTruck()
        setupHUD()
        setupBackground()

        controllerManager.delegate = self
    }

    private func setupCamera() {
        cameraNode = SKCameraNode()
        addChild(cameraNode)
        camera = cameraNode
    }

    private func setupBackground() {
        // Sky gradient - simple colored rectangles
        let sky = SKSpriteNode(color: SKColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0),
                               size: CGSize(width: 5000, height: 2000))
        sky.position = CGPoint(x: 0, y: 1000)
        sky.zPosition = -10
        addChild(sky)

        // Mountains in background
        for i in 0..<10 {
            let mountain = SKShapeNode()
            let path = CGMutablePath()
            let baseX = CGFloat(i) * 600 - 500
            let height = CGFloat.random(in: 200...400)
            path.move(to: CGPoint(x: baseX, y: groundY + 30))
            path.addLine(to: CGPoint(x: baseX + 300, y: groundY + height))
            path.addLine(to: CGPoint(x: baseX + 600, y: groundY + 30))
            path.closeSubpath()
            mountain.path = path
            mountain.fillColor = SKColor(red: 0.3, green: 0.5, blue: 0.3, alpha: 0.5)
            mountain.strokeColor = .clear
            mountain.zPosition = -5
            addChild(mountain)
        }

        // Death zone below terrain
        let deathZone = SKSpriteNode(color: .clear, size: CGSize(width: 50000, height: 50))
        deathZone.position = CGPoint(x: 0, y: -200)
        deathZone.physicsBody = SKPhysicsBody(rectangleOf: deathZone.size)
        deathZone.physicsBody?.isDynamic = false
        deathZone.physicsBody?.categoryBitMask = PhysicsCategory.boundary
        deathZone.physicsBody?.contactTestBitMask = PhysicsCategory.truck | PhysicsCategory.wheel
        deathZone.name = "deathZone"
        addChild(deathZone)
    }

    private func setupTerrain() {
        levelGenerator = LevelGenerator(sceneSize: size, groundY: groundY)
        let terrainNodes = levelGenerator.generateInitialTerrain()
        terrainNodes.forEach { addChild($0) }
    }

    private func setupTruck() {
        // Truck body
        truckBody = SKSpriteNode(color: .green, size: CGSize(width: 120, height: 50))
        truckBody.position = CGPoint(x: 200, y: groundY + 100)
        truckBody.zPosition = 1
        truckBody.name = "truckBody"

        truckBody.physicsBody = SKPhysicsBody(rectangleOf: truckBody.size)
        truckBody.physicsBody?.mass = 5.0
        truckBody.physicsBody?.categoryBitMask = PhysicsCategory.truck
        truckBody.physicsBody?.contactTestBitMask = PhysicsCategory.ground | PhysicsCategory.boundary
        truckBody.physicsBody?.collisionBitMask = PhysicsCategory.ground
        truckBody.physicsBody?.allowsRotation = true
        addChild(truckBody)

        // Cab on top
        let cab = SKSpriteNode(color: .darkGray, size: CGSize(width: 60, height: 35))
        cab.position = CGPoint(x: -10, y: 22)
        truckBody.addChild(cab)

        // Monster truck wheels
        let wheelRadius: CGFloat = 22
        frontWheel = makeWheel(radius: wheelRadius)
        frontWheel.position = CGPoint(x: 250, y: groundY + 60)
        addChild(frontWheel)

        rearWheel = makeWheel(radius: wheelRadius)
        rearWheel.position = CGPoint(x: 150, y: groundY + 60)
        addChild(rearWheel)

        // Attach wheels with spring joints
        let frontJoint = SKPhysicsJointSpring.joint(
            withBodyA: truckBody.physicsBody!,
            bodyB: frontWheel.physicsBody!,
            anchorA: CGPoint(x: truckBody.position.x + 45, y: truckBody.position.y - 25),
            anchorB: frontWheel.position
        )
        frontJoint.damping = 5.0
        frontJoint.frequency = 8.0
        physicsWorld.add(frontJoint)

        let rearJoint = SKPhysicsJointSpring.joint(
            withBodyA: truckBody.physicsBody!,
            bodyB: rearWheel.physicsBody!,
            anchorA: CGPoint(x: truckBody.position.x - 45, y: truckBody.position.y - 25),
            anchorB: rearWheel.position
        )
        rearJoint.damping = 5.0
        rearJoint.frequency = 8.0
        physicsWorld.add(rearJoint)

        lastRotation = truckBody.zRotation
    }

    private func makeWheel(radius: CGFloat) -> SKShapeNode {
        let wheel = SKShapeNode(circleOfRadius: radius)
        wheel.fillColor = .darkGray
        wheel.strokeColor = .black
        wheel.lineWidth = 3
        wheel.zPosition = 2
        wheel.name = "wheel"

        // Tire tread line for visual rotation feedback
        let tread = SKShapeNode(rectOf: CGSize(width: radius * 2 - 4, height: 3))
        tread.fillColor = .gray
        wheel.addChild(tread)

        wheel.physicsBody = SKPhysicsBody(circleOfRadius: radius)
        wheel.physicsBody?.mass = 1.0
        wheel.physicsBody?.categoryBitMask = PhysicsCategory.wheel
        wheel.physicsBody?.contactTestBitMask = PhysicsCategory.ground | PhysicsCategory.boundary
        wheel.physicsBody?.collisionBitMask = PhysicsCategory.ground
        wheel.physicsBody?.friction = 0.9
        wheel.physicsBody?.restitution = 0.2

        return wheel
    }

    private func setupHUD() {
        scoreLabel = SKLabelNode(text: "Score: 0")
        scoreLabel.fontName = "AvenirNext-Bold"
        scoreLabel.fontSize = 36
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.position = CGPoint(x: -size.width / 2 + 40, y: size.height / 2 - 60)
        scoreLabel.zPosition = 100
        cameraNode.addChild(scoreLabel)

        comboLabel = SKLabelNode(text: "")
        comboLabel.fontName = "AvenirNext-Bold"
        comboLabel.fontSize = 28
        comboLabel.fontColor = .yellow
        comboLabel.horizontalAlignmentMode = .left
        comboLabel.position = CGPoint(x: -size.width / 2 + 40, y: size.height / 2 - 100)
        comboLabel.zPosition = 100
        cameraNode.addChild(comboLabel)

        trickLabel = SKLabelNode(text: "")
        trickLabel.fontName = "AvenirNext-Heavy"
        trickLabel.fontSize = 48
        trickLabel.fontColor = .orange
        trickLabel.position = CGPoint(x: 0, y: 100)
        trickLabel.zPosition = 100
        cameraNode.addChild(trickLabel)

        speedLabel = SKLabelNode(text: "")
        speedLabel.fontName = "AvenirNext-Medium"
        speedLabel.fontSize = 24
        speedLabel.fontColor = .white
        speedLabel.horizontalAlignmentMode = .right
        speedLabel.position = CGPoint(x: size.width / 2 - 40, y: size.height / 2 - 60)
        speedLabel.zPosition = 100
        cameraNode.addChild(speedLabel)
    }

    // MARK: - Game Loop
    override func update(_ currentTime: TimeInterval) {
        guard !isCrashed else { return }

        applyDriving()
        applyAirControl()
        updateCamera()
        updateAirborneState()
        trackRotation()
        updateHUD()
        generateMoreTerrain()
    }

    private func applyDriving() {
        guard let body = truckBody.physicsBody else { return }

        // Accelerate
        if accelerateInput > 0.1 {
            let force = CGFloat(accelerateInput) * 80.0
            let direction = CGVector(
                dx: cos(truckBody.zRotation) * force,
                dy: sin(truckBody.zRotation) * force
            )
            body.applyForce(direction)
        }

        // Brake
        if brakeInput > 0.1 {
            let currentVelocity = body.velocity
            body.velocity = CGVector(
                dx: currentVelocity.dx * CGFloat(1.0 - brakeInput * 0.05),
                dy: currentVelocity.dy
            )
        }

        // Speed cap
        let maxSpeed: CGFloat = 800
        let speed = sqrt(body.velocity.dx * body.velocity.dx + body.velocity.dy * body.velocity.dy)
        if speed > maxSpeed {
            let scale = maxSpeed / speed
            body.velocity = CGVector(dx: body.velocity.dx * scale, dy: body.velocity.dy * scale)
        }
    }

    private func applyAirControl() {
        guard isAirborne, abs(leanInput) > 0.1 else { return }
        let torque = CGFloat(leanInput) * -3.0
        truckBody.physicsBody?.applyTorque(torque)
    }

    private func updateCamera() {
        let targetX = truckBody.position.x + 300
        let targetY = max(truckBody.position.y + 100, groundY + size.height / 2 - 200)

        cameraNode.position.x += (targetX - cameraNode.position.x) * 0.1
        cameraNode.position.y += (targetY - cameraNode.position.y) * 0.05
    }

    private func updateAirborneState() {
        let wheelContacts = (frontWheel.physicsBody?.allContactedBodies().count ?? 0) +
                           (rearWheel.physicsBody?.allContactedBodies().count ?? 0)
        let wasAirborne = isAirborne
        isAirborne = wheelContacts == 0

        if !wasAirborne && isAirborne {
            trickSystem.startAirborne()
        } else if wasAirborne && !isAirborne {
            handleLanding()
        }
    }

    private func trackRotation() {
        guard isAirborne else {
            lastRotation = truckBody.zRotation
            return
        }
        let delta = truckBody.zRotation - lastRotation

        // Normalize delta to handle wrapping
        var normalizedDelta = delta
        if normalizedDelta > .pi { normalizedDelta -= 2 * .pi }
        if normalizedDelta < -.pi { normalizedDelta += 2 * .pi }

        trickSystem.addRotation(normalizedDelta)
        lastRotation = truckBody.zRotation
    }

    private func handleLanding() {
        let angle = abs(truckBody.zRotation.truncatingRemainder(dividingBy: .pi * 2))
        let normalizedAngle = min(angle, .pi * 2 - angle)

        // Crash if landing angle is too steep (not roughly level)
        if normalizedAngle > .pi / 4 {
            triggerCrash()
            return
        }

        let results = trickSystem.land()
        if !results.isEmpty {
            showTrickPopup(results)
        }
    }

    private func showTrickPopup(_ results: [TrickResult]) {
        for (index, result) in results.enumerated() {
            let text = "\(result.type.rawValue) +\(result.points)"
            let label = SKLabelNode(text: text)
            label.fontName = "AvenirNext-Heavy"
            label.fontSize = 44
            label.fontColor = .yellow
            label.position = CGPoint(x: 0, y: 150 + CGFloat(index) * 50)
            label.zPosition = 100
            cameraNode.addChild(label)

            let fadeUp = SKAction.group([
                SKAction.moveBy(x: 0, y: 80, duration: 1.5),
                SKAction.sequence([
                    SKAction.wait(forDuration: 0.8),
                    SKAction.fadeOut(withDuration: 0.7)
                ])
            ])
            label.run(SKAction.sequence([fadeUp, SKAction.removeFromParent()]))
        }
    }

    private func triggerCrash() {
        guard !isCrashed else { return }
        isCrashed = true
        trickSystem.crash()

        // Crash visual
        let explosion = SKShapeNode(circleOfRadius: 60)
        explosion.fillColor = .orange
        explosion.strokeColor = .red
        explosion.lineWidth = 4
        explosion.position = truckBody.position
        explosion.zPosition = 5
        addChild(explosion)

        let boom = SKAction.sequence([
            SKAction.scale(to: 2.0, duration: 0.3),
            SKAction.fadeOut(withDuration: 0.3),
            SKAction.removeFromParent()
        ])
        explosion.run(boom)

        // Show crash overlay
        showCrashOverlay()
    }

    private func showCrashOverlay() {
        let overlay = SKNode()
        overlay.zPosition = 200

        let bg = SKSpriteNode(color: SKColor(red: 0, green: 0, blue: 0, alpha: 0.6),
                              size: CGSize(width: 600, height: 300))
        overlay.addChild(bg)

        let crashLabel = SKLabelNode(text: "CRASHED!")
        crashLabel.fontName = "AvenirNext-Heavy"
        crashLabel.fontSize = 64
        crashLabel.fontColor = .red
        crashLabel.position = CGPoint(x: 0, y: 40)
        overlay.addChild(crashLabel)

        let scoreText = SKLabelNode(text: "Score: \(trickSystem.totalScore)")
        scoreText.fontName = "AvenirNext-Bold"
        scoreText.fontSize = 36
        scoreText.fontColor = .white
        scoreText.position = CGPoint(x: 0, y: -20)
        overlay.addChild(scoreText)

        let restartLabel = SKLabelNode(text: "Press ○ to restart")
        restartLabel.fontName = "AvenirNext-Medium"
        restartLabel.fontSize = 28
        restartLabel.fontColor = .gray
        restartLabel.position = CGPoint(x: 0, y: -70)
        overlay.addChild(restartLabel)

        cameraNode.addChild(overlay)
        crashOverlay = overlay
    }

    private func restartGame() {
        let newScene = GameScene(size: size)
        newScene.scaleMode = .aspectFill
        view?.presentScene(newScene, transition: SKTransition.fade(withDuration: 0.3))
    }

    private func updateHUD() {
        scoreLabel.text = "Score: \(trickSystem.totalScore)"

        if trickSystem.currentCombo > 1 {
            comboLabel.text = "Combo x\(trickSystem.currentCombo)"
        } else {
            comboLabel.text = ""
        }

        if let velocity = truckBody.physicsBody?.velocity {
            let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
            let kmh = Int(speed * 0.36)
            speedLabel.text = "\(kmh) km/h"
        }
    }

    private func generateMoreTerrain() {
        let cameraRight = cameraNode.position.x + size.width
        // Generate terrain ahead of camera - check periodically
        if Int(cameraRight) % 500 < 20 {
            let newSegments = levelGenerator.generateNextSegment()
            newSegments.forEach { addChild($0) }
        }
    }

    private func pauseGame() {
        isPaused = !isPaused
    }
}

// MARK: - Physics Contact
extension GameScene: SKPhysicsContactDelegate {

    func didBegin(_ contact: SKPhysicsContact) {
        let names = [contact.bodyA.node?.name, contact.bodyB.node?.name]

        if names.contains("deathZone") {
            triggerCrash()
        }
    }
}

// MARK: - Controller Input
extension GameScene: ControllerManagerDelegate {

    func controllerDidConnect() {}
    func controllerDidDisconnect() {}

    func didPressAccelerate(_ value: Float) {
        accelerateInput = value
    }

    func didPressBrake(_ value: Float) {
        brakeInput = value
    }

    func didPressJump() {
        guard !isCrashed, !isAirborne else { return }
        truckBody.physicsBody?.applyImpulse(CGVector(dx: 50, dy: 200))
    }

    func didPressRestart() {
        if isCrashed {
            restartGame()
        }
    }

    func didPressPause() {
        pauseGame()
    }

    func didLean(_ value: Float) {
        leanInput = value
    }
}
