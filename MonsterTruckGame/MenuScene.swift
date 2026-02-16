import SpriteKit
import GameController

class MenuScene: SKScene {

    private var controllerManager = ControllerManager()
    private var startLabel: SKLabelNode!
    private var konradNode: SKNode!

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.15, green: 0.15, blue: 0.25, alpha: 1.0)

        setupKonrad()
        setupTitle()
        setupStartPrompt()
        setupControllerHint()

        controllerManager.delegate = self
    }

    private func setupKonrad() {
        // Konrad character - drawn with SpriteKit shapes as placeholder
        konradNode = SKNode()
        konradNode.position = CGPoint(x: size.width / 2, y: size.height / 2 + 40)

        // Head
        let head = SKShapeNode(circleOfRadius: 80)
        head.fillColor = .init(red: 1.0, green: 0.85, blue: 0.7, alpha: 1.0)
        head.strokeColor = .darkGray
        head.lineWidth = 3
        head.position = CGPoint(x: 0, y: 80)
        konradNode.addChild(head)

        // Eyes
        for xOff: CGFloat in [-30, 30] {
            let eye = SKShapeNode(circleOfRadius: 15)
            eye.fillColor = .white
            eye.strokeColor = .darkGray
            eye.lineWidth = 2
            eye.position = CGPoint(x: xOff, y: 95)
            konradNode.addChild(eye)

            let pupil = SKShapeNode(circleOfRadius: 7)
            pupil.fillColor = .black
            pupil.position = CGPoint(x: xOff + 3, y: 93)
            konradNode.addChild(pupil)
        }

        // Smile
        let smilePath = CGMutablePath()
        smilePath.addArc(center: CGPoint(x: 0, y: 65), radius: 35,
                         startAngle: .pi * 0.2, endAngle: .pi * 0.8,
                         clockwise: true)
        let smile = SKShapeNode(path: smilePath)
        smile.strokeColor = .darkGray
        smile.lineWidth = 3
        konradNode.addChild(smile)

        // Helmet
        let helmetPath = CGMutablePath()
        helmetPath.addArc(center: CGPoint(x: 0, y: 100), radius: 85,
                          startAngle: .pi * 0.05, endAngle: .pi * 0.95,
                          clockwise: false)
        let helmet = SKShapeNode(path: helmetPath)
        helmet.strokeColor = .red
        helmet.lineWidth = 8
        konradNode.addChild(helmet)

        // Body
        let body = SKShapeNode(rectOf: CGSize(width: 100, height: 100), cornerRadius: 10)
        body.fillColor = .blue
        body.strokeColor = .darkGray
        body.lineWidth = 2
        body.position = CGPoint(x: 0, y: -30)
        konradNode.addChild(body)

        // Racing number on body
        let number = SKLabelNode(text: "1")
        number.fontName = "AvenirNext-Bold"
        number.fontSize = 50
        number.fontColor = .white
        number.position = CGPoint(x: 0, y: -48)
        konradNode.addChild(number)

        // Name label
        let nameLabel = SKLabelNode(text: "KONRAD")
        nameLabel.fontName = "AvenirNext-Bold"
        nameLabel.fontSize = 32
        nameLabel.fontColor = .yellow
        nameLabel.position = CGPoint(x: 0, y: -120)
        konradNode.addChild(nameLabel)

        addChild(konradNode)

        // Idle animation - slight bounce
        let bounce = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 10, duration: 0.8),
            SKAction.moveBy(x: 0, y: -10, duration: 0.8)
        ])
        konradNode.run(SKAction.repeatForever(bounce))
    }

    private func setupTitle() {
        let title = SKLabelNode(text: "MONSTER TRUCK MAYHEM")
        title.fontName = "AvenirNext-Heavy"
        title.fontSize = 72
        title.fontColor = .red
        title.position = CGPoint(x: size.width / 2, y: size.height - 120)
        addChild(title)

        let subtitle = SKLabelNode(text: "Featuring Konrad!")
        subtitle.fontName = "AvenirNext-Medium"
        subtitle.fontSize = 32
        subtitle.fontColor = .orange
        subtitle.position = CGPoint(x: size.width / 2, y: size.height - 170)
        addChild(subtitle)
    }

    private func setupStartPrompt() {
        startLabel = SKLabelNode(text: "Press X to Race!")
        startLabel.fontName = "AvenirNext-Bold"
        startLabel.fontSize = 40
        startLabel.fontColor = .white
        startLabel.position = CGPoint(x: size.width / 2, y: 100)
        addChild(startLabel)

        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.8),
            SKAction.fadeAlpha(to: 1.0, duration: 0.8)
        ])
        startLabel.run(SKAction.repeatForever(pulse))
    }

    private func setupControllerHint() {
        let hint = SKLabelNode(text: "Connect a PlayStation controller to play")
        hint.fontName = "AvenirNext-Regular"
        hint.fontSize = 24
        hint.fontColor = .gray
        hint.position = CGPoint(x: size.width / 2, y: 50)
        addChild(hint)
    }

    private func startGame() {
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
