import UIKit
import SpriteKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let skView = view as? SKView ?? {
            let sv = SKView(frame: view.bounds)
            sv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(sv)
            return sv
        }() as SKView? else { return }

        skView.ignoresSiblingOrder = true
        skView.showsFPS = false
        skView.showsNodeCount = false

        let menuScene = MenuScene(size: CGSize(width: 1920, height: 1080))
        menuScene.scaleMode = .aspectFill
        skView.presentScene(menuScene)
    }

    override var prefersStatusBarHidden: Bool { true }
}
