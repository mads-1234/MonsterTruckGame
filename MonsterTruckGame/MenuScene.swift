import SpriteKit
import GameController
import AVFoundation

class MenuScene: SKScene {

    private var controllerManager = ControllerManager()
    private var startLabel: SKLabelNode!
    private var musicPlayer: AVAudioPlayer?

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.05, green: 0.05, blue: 0.12, alpha: 1.0)

        setupBackground()
        setupKonrad()
        setupStartPrompt()
        setupControllerHint()
        setupMusic()

        controllerManager.delegate = self
    }

    private func setupBackground() {
        let bgTexture = SKTexture(imageNamed: "title_bg")
        bgTexture.filteringMode = .nearest
        let bg = SKSpriteNode(texture: bgTexture, size: size)
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bg.zPosition = -1
        addChild(bg)
    }

    private func setupKonrad() {
        let konradTexture = SKTexture(imageNamed: "konrad")
        konradTexture.filteringMode = .nearest
        let konrad = SKSpriteNode(texture: konradTexture, size: CGSize(width: 220, height: 220))
        konrad.position = CGPoint(x: size.width / 2, y: size.height / 2)
        konrad.zPosition = 2
        addChild(konrad)

        let bounce = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 8, duration: 0.8),
            SKAction.moveBy(x: 0, y: -8, duration: 0.8)
        ])
        konrad.run(SKAction.repeatForever(bounce))
    }

    private func setupStartPrompt() {
        let startShadow = SKLabelNode(text: "Trykk  X  for å kjøre!")
        startShadow.fontName = "Menlo-Bold"
        startShadow.fontSize = 38
        startShadow.fontColor = .black
        startShadow.position = CGPoint(x: size.width / 2 + 3, y: 78)
        startShadow.zPosition = 1
        addChild(startShadow)

        startLabel = SKLabelNode(text: "Trykk  X  for å kjøre!")
        startLabel.fontName = "Menlo-Bold"
        startLabel.fontSize = 38
        startLabel.fontColor = .white
        startLabel.position = CGPoint(x: size.width / 2, y: 80)
        startLabel.zPosition = 2
        addChild(startLabel)

        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.8),
            SKAction.fadeAlpha(to: 1.0, duration: 0.8)
        ])
        startLabel.run(SKAction.repeatForever(pulse))
        startShadow.run(SKAction.repeatForever(pulse.copy() as! SKAction))
    }

    private func setupControllerHint() {
        let hintShadow = SKLabelNode(text: "Koble til en kontroller for å spille")
        hintShadow.fontName = "Menlo-Bold"
        hintShadow.fontSize = 22
        hintShadow.fontColor = .black
        hintShadow.position = CGPoint(x: size.width / 2 + 2, y: 33)
        hintShadow.zPosition = 1
        addChild(hintShadow)

        let hint = SKLabelNode(text: "Koble til en kontroller for å spille")
        hint.fontName = "Menlo-Bold"
        hint.fontSize = 22
        hint.fontColor = SKColor(red: 0.6, green: 0.6, blue: 0.7, alpha: 1.0)
        hint.position = CGPoint(x: size.width / 2, y: 35)
        hint.zPosition = 2
        addChild(hint)
    }

    private func setupMusic() {
        if let musicPath = Bundle.main.path(forResource: "background_music", ofType: "mp3") {
            let musicURL = URL(fileURLWithPath: musicPath)
            do {
                musicPlayer = try AVAudioPlayer(contentsOf: musicURL)
                musicPlayer?.numberOfLoops = -1
                musicPlayer?.volume = 0.4
                musicPlayer?.play()
            } catch {
                print("Could not load music: \(error)")
            }
        }
    }

    private func startGame() {
        musicPlayer?.stop()
        let transition = SKTransition.fade(withDuration: 0.5)
        let gameScene = GameScene(size: size)
        gameScene.scaleMode = .aspectFill
        view?.presentScene(gameScene, transition: transition)
    }
}

// MARK: - Controller
extension MenuScene: ControllerManagerDelegate {
    func controllerDidConnect() {}
    func controllerDidDisconnect() {}
    func didPressAccelerate(_ value: Float) {}
    func didPressBrake(_ value: Float) {}
    func didPressJump() { startGame() }
    func didPressRestart() {}
    func didPressPause() {}
    func didLean(_ value: Float) {}
}
