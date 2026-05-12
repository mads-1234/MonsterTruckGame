import SpriteKit
import AVFoundation

/// Bit masks for SpriteKit physics categories.
///
/// Used for `categoryBitMask`, `contactTestBitMask`, og `collisionBitMask`
/// på alle fysikk-kropper i spillet. Hver kategori er én bit slik at de
/// kan kombineres med OR (`|`).
///
/// Kollisjonsmatrise:
/// - `truck` og `wheel` kolliderer med `ground` (kjører på terrenget).
/// - `truck` og `wheel` *kontakter* `boundary` (death zone) — utløser krasj
///   via `SKPhysicsContactDelegate`, men kolliderer ikke fysisk.
/// - `truck` og `wheel` kolliderer ikke med hverandre — de er koblet med
///   spring joints og skal ikke "dytte" hverandre.
struct PhysicsCategory {
    static let none: UInt32     = 0
    /// Truck-karosseriet. Én kropp, koblet til hjul via spring joints.
    static let truck: UInt32    = 0b1
    /// Front- og bakhjul. Sirkulære kropper med friksjon — driver fremover
    /// ved å sette `angularVelocity` direkte (ikke moment).
    static let wheel: UInt32    = 0b10
    /// Alt terreng: flate biter, ramper, høyder. Statisk (`isDynamic = false`).
    static let ground: UInt32   = 0b100
    /// Death zone under terrenget (y = -200). Kontakt med truck/hjul
    /// utløser umiddelbar krasj.
    static let boundary: UInt32 = 0b1000
}

/// Hovedscene for kjøringen — eier truck-fysikk, kamera, parallax, HUD,
/// audio, og terreng-generator.
///
/// Levetid: opprettes av `MenuScene.startGame()` ved trykk på X, og
/// erstattes av en ny `GameScene`-instans ved restart (vi reseter ikke
/// state — vi bytter scene). Krasj-tilstand håndteres via `isCrashed`,
/// som stopper alt arbeid i `update(_:)` til spilleren trykker Y.
class GameScene: SKScene {

    // MARK: - Properties
    private var truckBody: SKSpriteNode!
    private var frontWheel: SKSpriteNode!
    private var rearWheel: SKSpriteNode!
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
    private var airTimeLabel: SKLabelNode!
    private var crashOverlay: SKNode?

    // Background layers (for parallax)
    private var skyFill: SKSpriteNode!
    private var groundFill: SKSpriteNode!
    private var mountainNodes: [SKSpriteNode] = []
    private var cloudNodes: [SKSpriteNode] = []
    private var sunNode: SKSpriteNode!

    // Audio
    private var backgroundMusicPlayer: AVAudioPlayer?
    private var engineSoundPlayer: AVAudioPlayer?
    private var lastHornTime: TimeInterval = 0

    // MARK: - Scene Setup

    /// Bootstrapper hele scenen: bakgrunn, terreng, truck, HUD, audio,
    /// og kobler controller-delegate. Kalt automatisk av SpriteKit når
    /// scenen presenteres i en `SKView`.
    ///
    /// Setter `physicsWorld.contactDelegate = self` slik at death zone-
    /// kollisjoner trigger `didBegin(_:)` i extension under.
    override func didMove(to view: SKView) {
        // Deep retro blue sky
        backgroundColor = SKColor(red: 0.18, green: 0.32, blue: 0.72, alpha: 1.0)

        physicsWorld.gravity = CGVector(dx: 0, dy: -7.0)
        physicsWorld.contactDelegate = self

        setupCamera()
        setupBackground()
        setupTerrain()
        setupTruck()
        setupHUD()
        setupAudio()

        controllerManager.delegate = self
    }

    private func setupCamera() {
        cameraNode = SKCameraNode()
        addChild(cameraNode)
        camera = cameraNode
    }

    private func setupBackground() {
        // Large sky fill that moves with camera (prevents any white/empty gaps)
        skyFill = SKSpriteNode(color: SKColor(red: 0.18, green: 0.32, blue: 0.72, alpha: 1.0),
                               size: CGSize(width: 4000, height: 3000))
        skyFill.position = CGPoint(x: 0, y: 800)
        skyFill.zPosition = -20
        addChild(skyFill)

        // Underground fill (brown dirt color) to fill below terrain
        groundFill = SKSpriteNode(color: SKColor(red: 0.35, green: 0.22, blue: 0.12, alpha: 1.0),
                                  size: CGSize(width: 4000, height: 1000))
        groundFill.position = CGPoint(x: 0, y: groundY - 530)
        groundFill.zPosition = -20
        addChild(groundFill)

        // Sun sprite
        let sunTexture = SKTexture(imageNamed: "sun")
        sunTexture.filteringMode = .nearest
        sunNode = SKSpriteNode(texture: sunTexture, size: CGSize(width: 160, height: 160))
        sunNode.position = CGPoint(x: -400, y: 750)
        sunNode.zPosition = -9
        addChild(sunNode)

        // Clouds
        let cloudTexture = SKTexture(imageNamed: "cloud")
        cloudTexture.filteringMode = .nearest
        for i in 0..<20 {
            let scale = CGFloat.random(in: 0.8...1.5)
            let cloud = SKSpriteNode(texture: cloudTexture,
                                     size: CGSize(width: 128 * scale, height: 64 * scale))
            cloud.position = CGPoint(x: CGFloat(i) * 500 - 2000,
                                    y: CGFloat.random(in: 550...850))
            cloud.alpha = 0.9
            cloud.zPosition = -8
            addChild(cloud)
            cloudNodes.append(cloud)
        }

        // Mountains (repeating sprite strips)
        let mtTexture = SKTexture(imageNamed: "mountains")
        mtTexture.filteringMode = .nearest
        for i in 0..<12 {
            let mt = SKSpriteNode(texture: mtTexture, size: CGSize(width: 1536, height: 400))
            mt.position = CGPoint(x: CGFloat(i) * 1500 - 2000, y: groundY + 170)
            mt.zPosition = -6
            addChild(mt)
            mountainNodes.append(mt)
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
        if let musicPath = Bundle.main.path(forResource: "background_music", ofType: "mp3") {
            let musicURL = URL(fileURLWithPath: musicPath)
            do {
                backgroundMusicPlayer = try AVAudioPlayer(contentsOf: musicURL)
                backgroundMusicPlayer?.numberOfLoops = -1
                backgroundMusicPlayer?.volume = 0.4
                backgroundMusicPlayer?.play()
            } catch {
                print("Could not load background music: \(error)")
            }
        }

        if let enginePath = Bundle.main.path(forResource: "engine_sound", ofType: "mp3") {
            let engineURL = URL(fileURLWithPath: enginePath)
            do {
                engineSoundPlayer = try AVAudioPlayer(contentsOf: engineURL)
                engineSoundPlayer?.numberOfLoops = -1
                engineSoundPlayer?.volume = 0.0
                engineSoundPlayer?.prepareToPlay()
                engineSoundPlayer?.play()
            } catch {
                print("Could not load engine sound: \(error)")
            }
        }
    }

    private func setupTerrain() {
        levelGenerator = LevelGenerator(sceneSize: size, groundY: groundY)
        let terrainNodes = levelGenerator.generateInitialTerrain()
        terrainNodes.forEach { addChild($0) }
    }

    private func setupTruck() {
        let bodyTexture = SKTexture(imageNamed: "truck_body")
        bodyTexture.filteringMode = .nearest
        truckBody = SKSpriteNode(texture: bodyTexture, size: CGSize(width: 120, height: 50))
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

        // Konrad as the driver
        let konrad = SKSpriteNode(imageNamed: "konrad")
        konrad.size = CGSize(width: 50, height: 60)
        konrad.position = CGPoint(x: -5, y: 30)
        konrad.zPosition = 3
        truckBody.addChild(konrad)

        // Pixel art wheels
        let wheelRadius: CGFloat = 28
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
        frontJoint.damping = 1.0
        frontJoint.frequency = 6.0
        physicsWorld.add(frontJoint)

        let rearJoint = SKPhysicsJointSpring.joint(
            withBodyA: truckBody.physicsBody!,
            bodyB: rearWheel.physicsBody!,
            anchorA: CGPoint(x: truckBody.position.x - 45, y: truckBody.position.y - 25),
            anchorB: rearWheel.position
        )
        rearJoint.damping = 1.0
        rearJoint.frequency = 6.0
        physicsWorld.add(rearJoint)

        lastRotation = truckBody.zRotation
    }

    private func makeWheel(radius: CGFloat) -> SKSpriteNode {
        let wheelTexture = SKTexture(imageNamed: "wheel")
        wheelTexture.filteringMode = .nearest
        let wheel = SKSpriteNode(texture: wheelTexture, size: CGSize(width: radius * 2, height: radius * 2))
        wheel.zPosition = 2
        wheel.name = "wheel"

        wheel.physicsBody = SKPhysicsBody(circleOfRadius: radius)
        wheel.physicsBody?.mass = 0.3
        wheel.physicsBody?.categoryBitMask = PhysicsCategory.wheel
        wheel.physicsBody?.contactTestBitMask = PhysicsCategory.ground | PhysicsCategory.boundary
        wheel.physicsBody?.collisionBitMask = PhysicsCategory.ground
        wheel.physicsBody?.friction = 0.7
        wheel.physicsBody?.restitution = 0.3

        return wheel
    }

    private func setupHUD() {
        // Score (top left)
        scoreLabel = SKLabelNode(text: "POENG: 0")
        scoreLabel.fontName = "Menlo-Bold"
        scoreLabel.fontSize = 36
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.position = CGPoint(x: -size.width / 2 + 40, y: size.height / 2 - 60)
        scoreLabel.zPosition = 100
        cameraNode.addChild(scoreLabel)

        // Combo (below score)
        comboLabel = SKLabelNode(text: "")
        comboLabel.fontName = "Menlo-Bold"
        comboLabel.fontSize = 32
        comboLabel.fontColor = .yellow
        comboLabel.horizontalAlignmentMode = .left
        comboLabel.position = CGPoint(x: -size.width / 2 + 40, y: size.height / 2 - 100)
        comboLabel.zPosition = 100
        cameraNode.addChild(comboLabel)

        // Air time (below combo, shows when airborne)
        airTimeLabel = SKLabelNode(text: "")
        airTimeLabel.fontName = "Menlo-Bold"
        airTimeLabel.fontSize = 28
        airTimeLabel.fontColor = SKColor(red: 0.5, green: 0.9, blue: 1.0, alpha: 1.0)
        airTimeLabel.horizontalAlignmentMode = .left
        airTimeLabel.position = CGPoint(x: -size.width / 2 + 40, y: size.height / 2 - 138)
        airTimeLabel.zPosition = 100
        cameraNode.addChild(airTimeLabel)

        // Trick popup (center)
        trickLabel = SKLabelNode(text: "")
        trickLabel.fontName = "Menlo-Bold"
        trickLabel.fontSize = 48
        trickLabel.fontColor = .orange
        trickLabel.position = CGPoint(x: 0, y: 100)
        trickLabel.zPosition = 100
        cameraNode.addChild(trickLabel)

        // Speed (top right)
        speedLabel = SKLabelNode(text: "")
        speedLabel.fontName = "Menlo-Bold"
        speedLabel.fontSize = 24
        speedLabel.fontColor = .white
        speedLabel.horizontalAlignmentMode = .right
        speedLabel.position = CGPoint(x: size.width / 2 - 40, y: size.height / 2 - 60)
        speedLabel.zPosition = 100
        cameraNode.addChild(speedLabel)
    }

    // MARK: - Game Loop

    /// Per-frame oppdatering kalt av SpriteKit (~60 Hz).
    ///
    /// Rekkefølgen er bevisst: input/driving før luft-kontroll og kamera,
    /// så parallax (som leser kamera-posisjonen), så terreng-spawn til slutt
    /// så den nye terrengen ikke forskyves av samme frames kamerabevegelse.
    ///
    /// Hele kroppen short-circuiter når `isCrashed` er sann — scenen står
    /// stille og venter på restart.
    override func update(_ currentTime: TimeInterval) {
        guard !isCrashed else { return }

        playRandomHorn(currentTime: currentTime)
        applyDriving()
        applyAirControl()
        updateCamera()
        updateParallax()
        updateAirborneState()
        trackRotation()
        trackHeight()
        updateHUD()
        generateMoreTerrain()
    }

    private func playRandomHorn(currentTime: TimeInterval) {
        guard !isAirborne else { return }

        let timeSinceLastHorn = currentTime - lastHornTime
        guard timeSinceLastHorn > 8.0 else { return }

        let randomValue = Double.random(in: 0...1)
        if randomValue < 0.05 {
            run(SKAction.playSoundFileNamed("horn_sound.mp3", waitForCompletion: false))
            lastHornTime = currentTime
        }
    }

    private func applyDriving() {
        guard let body = truckBody.physicsBody else { return }

        let targetVolume = accelerateInput > 0.1 ? CGFloat(accelerateInput) * 0.7 : 0.0
        engineSoundPlayer?.volume = Float(targetVolume)

        if accelerateInput > 0.1 {
            let force = CGFloat(accelerateInput) * 600.0
            let horizontalForce = CGVector(dx: force, dy: 0)
            body.applyForce(horizontalForce)

            let wheelSpeed = CGFloat(accelerateInput) * -35.0
            if let rearWheelBody = rearWheel.physicsBody {
                rearWheelBody.angularVelocity = wheelSpeed
                rearWheelBody.friction = 3.0
            }
            if let frontWheelBody = frontWheel.physicsBody {
                frontWheelBody.angularVelocity = wheelSpeed
                frontWheelBody.friction = 3.0
            }
        } else {
            rearWheel.physicsBody?.friction = 2.0
            frontWheel.physicsBody?.friction = 2.0
        }

        if brakeInput > 0.1 {
            let currentVelocity = body.velocity
            body.velocity = CGVector(
                dx: currentVelocity.dx * CGFloat(1.0 - brakeInput * 0.05),
                dy: currentVelocity.dy
            )
        }

        let maxSpeed: CGFloat = 4500
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

    private func updateParallax() {
        let camX = cameraNode.position.x
        let camY = cameraNode.position.y

        // Sky and ground fill follow camera
        skyFill.position = CGPoint(x: camX, y: camY + 400)
        groundFill.position = CGPoint(x: camX, y: groundY - 530)

        // Sun moves slowly with camera (far background parallax)
        sunNode.position.x = camX * 0.05 - 400

        // Mountains parallax (move at 20% of camera speed)
        for (i, mt) in mountainNodes.enumerated() {
            let baseX = CGFloat(i) * 1500 - 2000
            mt.position.x = baseX + camX * 0.2
        }

        // Clouds parallax (move at 10% of camera speed)
        for (i, cloud) in cloudNodes.enumerated() {
            let baseX = CGFloat(i) * 500 - 2000
            cloud.position.x = baseX + camX * 0.1
        }
    }

    /// Detekterer om trucken er i lufta basert på hjul-kontakter.
    ///
    /// Vi spør hjulenes fysikk-kropper hvor mange andre kropper de er i
    /// kontakt med. Null kontakter = i lufta. Dette er mer pålitelig enn
    /// å bruke `SKPhysicsContactDelegate`, fordi vi ikke trenger å spore
    /// begin/end events selv.
    ///
    /// Overganger trigger `TrickSystem.startAirborne()` / `handleLanding()`.
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

    /// Akkumulerer rotasjon mens trucken er i lufta — brukes til salto-deteksjon.
    ///
    /// `zRotation` er kontinuerlig (kan bli > 2π), men frame-til-frame-delta
    /// kan hoppe over wraparound. Vi normaliserer derfor delta til [-π, π]
    /// før vi sender det til `TrickSystem.addRotation`, slik at en passering
    /// av ±π ikke registreres som en hel runde med motsatt fortegn.
    private func trackRotation() {
        guard isAirborne else {
            lastRotation = truckBody.zRotation
            return
        }
        let delta = truckBody.zRotation - lastRotation

        var normalizedDelta = delta
        if normalizedDelta > .pi { normalizedDelta -= 2 * .pi }
        if normalizedDelta < -.pi { normalizedDelta += 2 * .pi }

        trickSystem.addRotation(normalizedDelta)
        lastRotation = truckBody.zRotation
    }

    private func trackHeight() {
        guard isAirborne else { return }
        let heightAboveGround = truckBody.position.y - groundY
        trickSystem.updateHeight(heightAboveGround)
    }

    /// Avgjør om landingen er trygg eller en krasj, og rapporterer triks.
    ///
    /// Vi normaliserer `zRotation` til intervallet [0, π] — vi bryr oss
    /// kun om hvor mye trucken vipper, ikke hvilken vei. Terskelen π/1.8
    /// (~100°) er bevisst slack: spilleren skal kunne lande litt skjevt
    /// og fortsatt overleve. Strengere terskler (π/2 og strengere) føltes
    /// frustrerende i testing — se `PROGRESS.md` for tuning-historikk.
    private func handleLanding() {
        let angle = abs(truckBody.zRotation.truncatingRemainder(dividingBy: .pi * 2))
        let normalizedAngle = min(angle, .pi * 2 - angle)

        if normalizedAngle > .pi / 1.8 {
            triggerCrash()
            return
        }

        let results = trickSystem.land(landingAngle: normalizedAngle)
        if !results.isEmpty {
            showTrickPopup(results)
        }
    }

    private func showTrickPopup(_ results: [TrickResult]) {
        for (index, result) in results.enumerated() {
            let comboText = result.comboMultiplier > 1 ? " x\(result.comboMultiplier)" : ""
            let text = "\(result.type.rawValue) +\(result.points)\(comboText)"
            let label = SKLabelNode(text: text)
            label.fontName = "Menlo-Bold"
            label.fontSize = 44
            label.zPosition = 100
            label.position = CGPoint(x: 0, y: 150 + CGFloat(index) * 55)

            // Color based on trick value
            if result.points >= 1000 {
                label.fontColor = SKColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0) // Red for huge
            } else if result.points >= 400 {
                label.fontColor = SKColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0) // Orange for big
            } else {
                label.fontColor = .yellow
            }

            // Shadow for readability
            let shadow = SKLabelNode(text: text)
            shadow.fontName = "Menlo-Bold"
            shadow.fontSize = 44
            shadow.fontColor = .black
            shadow.position = CGPoint(x: 2, y: -2)
            shadow.zPosition = -1
            label.addChild(shadow)

            cameraNode.addChild(label)

            // Scale pop + float up + fade
            label.setScale(0.5)
            let popUp = SKAction.group([
                SKAction.scale(to: 1.0, duration: 0.2),
                SKAction.moveBy(x: 0, y: 100, duration: 2.0),
                SKAction.sequence([
                    SKAction.wait(forDuration: 1.2),
                    SKAction.fadeOut(withDuration: 0.8)
                ])
            ])
            label.run(SKAction.sequence([popUp, SKAction.removeFromParent()]))
        }
    }

    private func triggerCrash() {
        guard !isCrashed else { return }
        isCrashed = true
        trickSystem.crash()

        run(SKAction.playSoundFileNamed("crash_sound.mp3", waitForCompletion: false))

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

        showCrashOverlay()
    }

    private func showCrashOverlay() {
        let overlay = SKNode()
        overlay.zPosition = 200

        let bg = SKSpriteNode(color: SKColor(red: 0, green: 0, blue: 0, alpha: 0.7),
                              size: CGSize(width: 700, height: 400))
        overlay.addChild(bg)

        let crashLabel = SKLabelNode(text: "KRASJET!")
        crashLabel.fontName = "Menlo-Bold"
        crashLabel.fontSize = 64
        crashLabel.fontColor = .red
        crashLabel.position = CGPoint(x: 0, y: 80)
        overlay.addChild(crashLabel)

        let scoreText = SKLabelNode(text: "POENG: \(trickSystem.totalScore)")
        scoreText.fontName = "Menlo-Bold"
        scoreText.fontSize = 40
        scoreText.fontColor = .white
        scoreText.position = CGPoint(x: 0, y: 15)
        overlay.addChild(scoreText)

        let comboText = SKLabelNode(text: "BESTE KOMBO: x\(trickSystem.bestCombo)")
        comboText.fontName = "Menlo-Bold"
        comboText.fontSize = 28
        comboText.fontColor = .yellow
        comboText.position = CGPoint(x: 0, y: -30)
        overlay.addChild(comboText)

        let restartLabel = SKLabelNode(text: "Trykk  Y  for å starte på nytt")
        restartLabel.fontName = "Menlo-Bold"
        restartLabel.fontSize = 28
        restartLabel.fontColor = SKColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1.0)
        restartLabel.position = CGPoint(x: 0, y: -90)
        overlay.addChild(restartLabel)

        // Pulse the restart hint
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.4, duration: 0.6),
            SKAction.fadeAlpha(to: 1.0, duration: 0.6)
        ])
        restartLabel.run(SKAction.repeatForever(pulse))

        cameraNode.addChild(overlay)
        crashOverlay = overlay
    }

    /// Starter en helt ny `GameScene` framfor å nullstille tilstand.
    ///
    /// Enklere og mer pålitelig enn manuell reset: alle physics bodies,
    /// timers og noder forsvinner med den gamle scenen. SpriteKit holder
    /// `SKView` i live mellom transisjoner.
    private func restartGame() {
        crashOverlay?.removeFromParent()
        crashOverlay = nil

        let newScene = GameScene(size: size)
        newScene.scaleMode = .aspectFill
        view?.presentScene(newScene, transition: SKTransition.fade(withDuration: 0.3))
    }

    private func updateHUD() {
        scoreLabel.text = "POENG: \(trickSystem.totalScore)"

        if trickSystem.currentCombo > 1 {
            comboLabel.text = "KOMBO x\(trickSystem.currentCombo)"
        } else {
            comboLabel.text = ""
        }

        // Show air time indicator while airborne
        if isAirborne {
            airTimeLabel.text = "I LUFTA"
        } else {
            airTimeLabel.text = ""
        }

        if let velocity = truckBody.physicsBody?.velocity {
            let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
            let kmh = Int(speed * 0.12)
            speedLabel.text = "\(kmh) km/h"
        }
    }

    private func generateMoreTerrain() {
        let cameraRight = cameraNode.position.x + size.width
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
        // If crashed, restart
        if isCrashed {
            restartGame()
            return
        }

        guard !isAirborne else { return }
        truckBody.physicsBody?.applyImpulse(CGVector(dx: 80, dy: 350))
    }

    func didPressRestart() {
        // Always allow restart (B / Circle button)
        restartGame()
    }

    func didPressPause() {
        pauseGame()
    }

    func didLean(_ value: Float) {
        leanInput = value
    }
}
