import SpriteKit

struct TerrainSegment {
    let node: SKNode
    let width: CGFloat
}

class LevelGenerator {

    private let sceneSize: CGSize
    private let groundY: CGFloat
    private var nextX: CGFloat = 0

    init(sceneSize: CGSize, groundY: CGFloat) {
        self.sceneSize = sceneSize
        self.groundY = groundY
    }

    func generateInitialTerrain() -> [SKNode] {
        nextX = 0
        var nodes: [SKNode] = []

        // Flat starting area
        nodes.append(makeFlat(width: 800))

        // Generate segments to fill screen + buffer
        for _ in 0..<20 {
            nodes.append(contentsOf: generateNextSegment())
        }

        return nodes
    }

    func generateNextSegment() -> [SKNode] {
        let roll = Int.random(in: 0...10)

        switch roll {
        case 0...4:
            return [makeFlat(width: CGFloat.random(in: 200...500))]
        case 5...7:
            return [makeRamp(height: CGFloat.random(in: 80...200), width: CGFloat.random(in: 150...300))]
        case 8...9:
            return [makeBigJump()]
        default:
            return [makeGap(width: CGFloat.random(in: 100...250))]
        }
    }

    private func makeFlat(width: CGFloat) -> SKNode {
        let node = SKSpriteNode(color: .brown, size: CGSize(width: width, height: 60))
        node.position = CGPoint(x: nextX + width / 2, y: groundY)
        node.physicsBody = SKPhysicsBody(rectangleOf: node.size)
        node.physicsBody?.isDynamic = false
        node.physicsBody?.categoryBitMask = PhysicsCategory.ground
        node.physicsBody?.friction = 0.8
        nextX += width
        return node
    }

    private func makeRamp(height: CGFloat, width: CGFloat) -> SKNode {
        let container = SKNode()
        container.position = CGPoint(x: nextX, y: groundY)

        // Ramp surface using a triangle path
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: -30))
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: width, y: -30))
        path.closeSubpath()

        let ramp = SKShapeNode(path: path)
        ramp.fillColor = .orange
        ramp.strokeColor = .darkGray
        ramp.lineWidth = 2

        ramp.physicsBody = SKPhysicsBody(polygonFrom: path)
        ramp.physicsBody?.isDynamic = false
        ramp.physicsBody?.categoryBitMask = PhysicsCategory.ground
        ramp.physicsBody?.friction = 0.6

        container.addChild(ramp)
        nextX += width

        return container
    }

    private func makeBigJump() -> SKNode {
        let container = SKNode()
        container.position = CGPoint(x: nextX, y: groundY)

        // Up-ramp
        let rampWidth: CGFloat = 200
        let rampHeight: CGFloat = 250

        let upPath = CGMutablePath()
        upPath.move(to: CGPoint(x: 0, y: -30))
        upPath.addLine(to: CGPoint(x: rampWidth, y: rampHeight))
        upPath.addLine(to: CGPoint(x: rampWidth, y: -30))
        upPath.closeSubpath()

        let upRamp = SKShapeNode(path: upPath)
        upRamp.fillColor = .red
        upRamp.strokeColor = .darkGray
        upRamp.lineWidth = 2
        upRamp.physicsBody = SKPhysicsBody(polygonFrom: upPath)
        upRamp.physicsBody?.isDynamic = false
        upRamp.physicsBody?.categoryBitMask = PhysicsCategory.ground
        upRamp.physicsBody?.friction = 0.5

        container.addChild(upRamp)

        // Gap
        let gapWidth: CGFloat = 400

        // Down-ramp / landing
        let downPath = CGMutablePath()
        downPath.move(to: CGPoint(x: rampWidth + gapWidth, y: rampHeight * 0.5))
        downPath.addLine(to: CGPoint(x: rampWidth + gapWidth + rampWidth, y: -30))
        downPath.addLine(to: CGPoint(x: rampWidth + gapWidth, y: -30))
        downPath.closeSubpath()

        let downRamp = SKShapeNode(path: downPath)
        downRamp.fillColor = .red
        downRamp.strokeColor = .darkGray
        downRamp.lineWidth = 2
        downRamp.physicsBody = SKPhysicsBody(polygonFrom: downPath)
        downRamp.physicsBody?.isDynamic = false
        downRamp.physicsBody?.categoryBitMask = PhysicsCategory.ground
        downRamp.physicsBody?.friction = 0.6

        container.addChild(downRamp)

        nextX += rampWidth * 2 + gapWidth

        return container
    }

    private func makeGap(width: CGFloat) -> SKNode {
        // Just advance the x position - no ground here
        let marker = SKNode()
        marker.position = CGPoint(x: nextX + width / 2, y: groundY - 200)
        nextX += width

        // Add a landing platform after gap
        let landing = SKSpriteNode(color: .brown, size: CGSize(width: 300, height: 60))
        landing.position = CGPoint(x: nextX + 150, y: groundY)
        landing.physicsBody = SKPhysicsBody(rectangleOf: landing.size)
        landing.physicsBody?.isDynamic = false
        landing.physicsBody?.categoryBitMask = PhysicsCategory.ground
        landing.physicsBody?.friction = 0.8

        let container = SKNode()
        container.addChild(marker)
        container.addChild(landing)
        nextX += 300

        return container
    }
}
