import SpriteKit
import AVFoundation

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

    // Audio
    private var backgroundMusicPlayer: AVAudioPlayer?
    private var engineSoundPlayer: AVAudioPlayer?
    private var lastHornTime: TimeInterval = 0

    // MARK: - Scene Setup
    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)

        physicsWorld.gravity = CGVector(dx: 0, dy: -7.0)  // Reduced gravity for more air time
        physicsWorld.contactDelegate = self

        setupCamera()
        setupTerrain()
        setupTruck()
        setupHUD()
        setupBackground()
        setupAudio()

        controllerManager.delegate = self
    }

    private func setupCamera() {
        cameraNode = SKCameraNode()
        addChild(cameraNode)
        camera = cameraNode
    }

    private func setupBackground() {
        // Bright blue sky
        let sky = SKSpriteNode(color: SKColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0),
                               size: CGSize(width: 10000, height: 2000))
        sky.position = CGPoint(x: 0, y: 1000)
        sky.zPosition = -10
        addChild(sky)

        // Sun in the sky
        let sun = SKShapeNode(circleOfRadius: 80)
        sun.fillColor = SKColor(red: 1.0, green: 0.9, blue: 0.2, alpha: 1.0)
        sun.strokeColor = SKColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)
        sun.lineWidth = 3
        sun.position = CGPoint(x: -500, y: 800)
        sun.zPosition = -9
        addChild(sun)

        // Fluffy clouds
        for i in 0..<15 {
            let cloud = SKShapeNode(circleOfRadius: CGFloat.random(in: 40...80))
            cloud.fillColor = .white
            cloud.strokeColor = .clear
            cloud.position = CGPoint(x: CGFloat(i) * 700 - 1500,
                                    y: CGFloat.random(in: 600...900))
            cloud.alpha = 0.8
            cloud.zPosition = -8
            addChild(cloud)

            // Extra puffs for cloud shape
            let puff1 = SKShapeNode(circleOfRadius: CGFloat.random(in: 30...60))
            puff1.fillColor = .white
            puff1.strokeColor = .clear
            puff1.position = CGPoint(x: 50, y: 20)
            cloud.addChild(puff1)
        }

        // Distant mountains (darker, further back)
        for i in 0..<15 {
            let mountain = SKShapeNode()
            let path = CGMutablePath()
            let baseX = CGFloat(i) * 700 - 1000
            let height = CGFloat.random(in: 250...500)
            path.move(to: CGPoint(x: baseX, y: groundY + 30))
            path.addLine(to: CGPoint(x: baseX + 350, y: groundY + height))
            path.addLine(to: CGPoint(x: baseX + 700, y: groundY + 30))
            path.closeSubpath()
            mountain.path = path
            mountain.fillColor = SKColor(red: 0.2, green: 0.4, blue: 0.3, alpha: 0.7)
            mountain.strokeColor = SKColor(red: 0.15, green: 0.3, blue: 0.2, alpha: 1.0)
            mountain.lineWidth = 2
            mountain.zPosition = -6
            addChild(mountain)

            // Snow caps on tall mountains
            if height > 350 {
                let snowPath = CGMutablePath()
                snowPath.move(to: CGPoint(x: baseX + 300, y: groundY + height - 50))
                snowPath.addLine(to: CGPoint(x: baseX + 350, y: groundY + height))
                snowPath.addLine(to: CGPoint(x: baseX + 400, y: groundY + height - 50))
                snowPath.closeSubpath()
                let snow = SKShapeNode(path: snowPath)
                snow.fillColor = .white
                snow.strokeColor = .clear
                mountain.addChild(snow)
            }
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

    private func setupAudio() {
        // Background music
        if let musicPath = Bundle.main.path(forResource: "background_music", ofType: "mp3") {
            let musicURL = URL(fileURLWithPath: musicPath)
            do {
                backgroundMusicPlayer = try AVAudioPlayer(contentsOf: musicURL)
                backgroundMusicPlayer?.numberOfLoops = -1  // Loop forever
                backgroundMusicPlayer?.volume = 0.4  // 40% volume so it doesn't overpower sound effects
                backgroundMusicPlayer?.play()
                print("🎵 Background music started!")
            } catch {
                print("❌ Could not load background music: \(error)")
            }
        }

        // Engine sound
        if let enginePath = Bundle.main.path(forResource: "engine_sound", ofType: "mp3") {
            let engineURL = URL(fileURLWithPath: enginePath)
            do {
                engineSoundPlayer = try AVAudioPlayer(contentsOf: engineURL)
                engineSoundPlayer?.numberOfLoops = -1  // Loop while accelerating
                engineSoundPlayer?.volume = 0.0  // Start silent
                engineSoundPlayer?.prepareToPlay()
                engineSoundPlayer?.play()  // Play but silent, we'll adjust volume based on acceleration
                print("🚗 Engine sound loaded!")
            } catch {
                print("❌ Could not load engine sound: \(error)")
            }
        }
    }

    private func setupTerrain() {
        levelGenerator = LevelGenerator(sceneSize: size, groundY: groundY)
        let terrainNodes = levelGenerator.generateInitialTerrain()
        terrainNodes.forEach { addChild($0) }
    }

    private func setupTruck() {
        // Truck body (BRIGHT ORANGE MONSTER TRUCK!)
        truckBody = SKSpriteNode(color: .orange, size: CGSize(width: 120, height: 50))
        truckBody.position = CGPoint(x: 200, y: groundY + 100)
        truckBody.zPosition = 1
        truckBody.name = "truckBody"

        truckBody.physicsBody = SKPhysicsBody(rectangleOf: truckBody.size)
        truckBody.physicsBody?.mass = 1.5
        truckBody.physicsBody?.categoryBitMask = PhysicsCategory.truck
        truckBody.physicsBody?.contactTestBitMask = PhysicsCategory.ground | PhysicsCategory.boundary
        truckBody.physicsBody?.collisionBitMask = PhysicsCategory.ground
        truckBody.physicsBody?.allowsRotation = true
        addChild(truckBody)

        // Racing stripes for style!
        let stripe1 = SKSpriteNode(color: .white, size: CGSize(width: 110, height: 8))
        stripe1.position = CGPoint(x: 0, y: 10)
        stripe1.alpha = 0.8
        truckBody.addChild(stripe1)

        let stripe2 = SKSpriteNode(color: .white, size: CGSize(width: 110, height: 8))
        stripe2.position = CGPoint(x: 0, y: -10)
        stripe2.alpha = 0.8
        truckBody.addChild(stripe2)

        // Cab on top (RED for contrast!)
        let cab = SKSpriteNode(color: .red, size: CGSize(width: 60, height: 35))
        cab.position = CGPoint(x: -10, y: 22)
        truckBody.addChild(cab)

        // Windshield
        let windshield = SKSpriteNode(color: SKColor(red: 0.5, green: 0.7, blue: 1.0, alpha: 0.6),
                                      size: CGSize(width: 35, height: 28))
        windshield.position = CGPoint(x: 8, y: 0)
        cab.addChild(windshield)

        // Add Konrad as the driver (BIGGER and more visible!)
        let konrad = SKSpriteNode(imageNamed: "konrad")
        konrad.size = CGSize(width: 50, height: 60)  // Bigger!
        konrad.position = CGPoint(x: 5, y: 8)  // Centered better
        konrad.zPosition = 3  // On top of everything
        cab.addChild(konrad)

        // Monster truck wheels (bigger for more speed!)
        let wheelRadius: CGFloat = 28  // Increased from 22 to 28
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
        frontJoint.damping = 1.0  // Reduced from 5.0 - less resistance!
        frontJoint.frequency = 6.0  // Softer springs
        physicsWorld.add(frontJoint)

        let rearJoint = SKPhysicsJointSpring.joint(
            withBodyA: truckBody.physicsBody!,
            bodyB: rearWheel.physicsBody!,
            anchorA: CGPoint(x: truckBody.position.x - 45, y: truckBody.position.y - 25),
            anchorB: rearWheel.position
        )
        rearJoint.damping = 1.0  // Reduced from 5.0 - less resistance!
        rearJoint.frequency = 6.0  // Softer springs
        physicsWorld.add(rearJoint)

        lastRotation = truckBody.zRotation
    }

    private func makeWheel(radius: CGFloat) -> SKShapeNode {
        let wheel = SKShapeNode(circleOfRadius: radius)
        wheel.fillColor = .black  // Black tire
        wheel.strokeColor = .darkGray
        wheel.lineWidth = 4
        wheel.zPosition = 2
        wheel.name = "wheel"

        // Chrome rim in center
        let rim = SKShapeNode(circleOfRadius: radius * 0.5)
        rim.fillColor = .lightGray
        rim.strokeColor = .white
        rim.lineWidth = 2
        wheel.addChild(rim)

        // Tire tread lines for rotation feedback
        let tread1 = SKShapeNode(rectOf: CGSize(width: radius * 2 - 4, height: 4))
        tread1.fillColor = .darkGray
        wheel.addChild(tread1)

        let tread2 = SKShapeNode(rectOf: CGSize(width: 4, height: radius * 2 - 4))
        tread2.fillColor = .darkGray
        wheel.addChild(tread2)

        wheel.physicsBody = SKPhysicsBody(circleOfRadius: radius)
        wheel.physicsBody?.mass = 0.3  // Much lighter wheels!
        wheel.physicsBody?.categoryBitMask = PhysicsCategory.wheel
        wheel.physicsBody?.contactTestBitMask = PhysicsCategory.ground | PhysicsCategory.boundary
        wheel.physicsBody?.collisionBitMask = PhysicsCategory.ground
        wheel.physicsBody?.friction = 0.7  // Reduced from 0.9 for more speed
        wheel.physicsBody?.restitution = 0.3  // Increased bounce for more action

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

        playRandomHorn(currentTime: currentTime)
        applyDriving()
        applyAirControl()
        updateCamera()
        updateAirborneState()
        trackRotation()
        updateHUD()
        generateMoreTerrain()
    }

    private func playRandomHorn(currentTime: TimeInterval) {
        // Only honk while driving (not in air)
        guard !isAirborne else { return }

        // Check if enough time has passed since last horn (minimum 8 seconds)
        let timeSinceLastHorn = currentTime - lastHornTime
        guard timeSinceLastHorn > 8.0 else { return }

        // Random chance to honk (about 5% chance per second after cooldown)
        let randomValue = Double.random(in: 0...1)
        if randomValue < 0.05 {
            run(SKAction.playSoundFileNamed("horn_sound.mp3", waitForCompletion: false))
            lastHornTime = currentTime
            print("📯 HONK!")
        }
    }

    private func applyDriving() {
        guard let body = truckBody.physicsBody else { return }

        // Engine sound volume based on acceleration
        let targetVolume = accelerateInput > 0.1 ? CGFloat(accelerateInput) * 0.7 : 0.0
        engineSoundPlayer?.volume = Float(targetVolume)

        // Accelerate (High speed with good control!)
        if accelerateInput > 0.1 {
            let force = CGFloat(accelerateInput) * 560.0  // Reduced by 30% (was 800)

            // Apply force horizontally to work on ramps
            let horizontalForce = CGVector(dx: force, dy: 0)
            body.applyForce(horizontalForce)

            // BOTH wheels powered (4-wheel drive!) - NEGATIVE for forward motion
            let wheelSpeed = CGFloat(accelerateInput) * -42.0  // Reduced by 30% (was -60)
            if let rearWheelBody = rearWheel.physicsBody {
                rearWheelBody.angularVelocity = wheelSpeed
                rearWheelBody.friction = 3.0  // MUCH more grip!
            }
            if let frontWheelBody = frontWheel.physicsBody {
                frontWheelBody.angularVelocity = wheelSpeed
                frontWheelBody.friction = 3.0  // MUCH more grip!
            }
        } else {
            // High friction even when not accelerating for stability
            rearWheel.physicsBody?.friction = 2.0
            frontWheel.physicsBody?.friction = 2.0
        }

        // Brake
        if brakeInput > 0.1 {
            let currentVelocity = body.velocity
            body.velocity = CGVector(
                dx: currentVelocity.dx * CGFloat(1.0 - brakeInput * 0.05),
                dy: currentVelocity.dy
            )
        }

        // Speed cap (Fast but controllable!)
        let maxSpeed: CGFloat = 5600  // Reduced by 30% (was 8000)
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

        // Crash only if landing angle is VERY steep (much more forgiving!)
        // Changed from π/4 (45°) to π/2.5 (72°) for monster truck action!
        if normalizedAngle > .pi / 2.5 {
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

        // Play crash sound
        run(SKAction.playSoundFileNamed("crash_sound.mp3", waitForCompletion: false))

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

        let restartLabel = SKLabelNode(text: "Press A or B to restart")
        restartLabel.fontName = "AvenirNext-Medium"
        restartLabel.fontSize = 28
        restartLabel.fontColor = .white
        restartLabel.position = CGPoint(x: 0, y: -70)
        overlay.addChild(restartLabel)

        cameraNode.addChild(overlay)
        crashOverlay = overlay
    }

    private func restartGame() {
        print("🔄 Restarting game...")
        // Remove crash overlay
        crashOverlay?.removeFromParent()
        crashOverlay = nil

        // Create and present new scene
        let newScene = GameScene(size: size)
        newScene.scaleMode = .aspectFill
        view?.presentScene(newScene, transition: SKTransition.fade(withDuration: 0.3))
        print("✅ New scene presented")
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
        // If crashed, restart instead of jumping
        if isCrashed {
            print("🎮 A button pressed - Restarting!")
            restartGame()
            return
        }

        // Otherwise, jump (if not already in air)
        guard !isAirborne else { return }
        truckBody.physicsBody?.applyImpulse(CGVector(dx: 50, dy: 200))
    }

    func didPressRestart() {
        print("🎮 Restart button pressed! isCrashed: \(isCrashed)")
        if isCrashed {
            restartGame()
        } else {
            print("⚠️ Not crashed, restart ignored")
        }
    }

    func didPressPause() {
        pauseGame()
    }

    func didLean(_ value: Float) {
        leanInput = value
    }
}
