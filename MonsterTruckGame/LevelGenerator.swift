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
        case 0...5:
            // Flat terrain (more common now)
            return [makeFlat(width: CGFloat.random(in: 300...600))]
        case 6...8:
            // Regular ramps (good for speed and tricks)
            return [makeRamp(height: CGFloat.random(in: 80...200), width: CGFloat.random(in: 200...400))]
        case 9...10:
            // Big jumps (with ramps on both sides - no random holes!)
            return [makeBigJump()]
        default:
            // No more random gaps! Only jumps with ramps
            return [makeFlat(width: 400)]
        }
    }

    private func makeFlat(width: CGFloat) -> SKNode {
        let container = SKNode()

        // Main dirt ground
        let node = SKSpriteNode(color: SKColor(red: 0.55, green: 0.35, blue: 0.2, alpha: 1.0),
                                size: CGSize(width: width, height: 60))
        node.position = CGPoint(x: nextX + width / 2, y: groundY)
        node.physicsBody = SKPhysicsBody(rectangleOf: node.size)
        node.physicsBody?.isDynamic = false
        node.physicsBody?.categoryBitMask = PhysicsCategory.ground
        node.physicsBody?.friction = 2.0

        // Grass on top for detail
        let grass = SKSpriteNode(color: SKColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 1.0),
                                 size: CGSize(width: width, height: 12))
        grass.position = CGPoint(x: 0, y: 24)
        node.addChild(grass)

        container.addChild(node)
        nextX += width
        return container
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
        ramp.fillColor = SKColor(red: 0.8, green: 0.5, blue: 0.1, alpha: 1.0)  // Brown-orange ramp
        ramp.strokeColor = SKColor(red: 0.3, green: 0.2, blue: 0.1, alpha: 1.0)
        ramp.lineWidth = 3

        ramp.physicsBody = SKPhysicsBody(polygonFrom: path)
        ramp.physicsBody?.isDynamic = false
        ramp.physicsBody?.categoryBitMask = PhysicsCategory.ground
        ramp.physicsBody?.friction = 2.0  // Much more grip on ramps!

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
        upRamp.fillColor = SKColor(red: 0.9, green: 0.2, blue: 0.1, alpha: 1.0)  // Bright red jump!
        upRamp.strokeColor = SKColor(red: 0.5, green: 0.1, blue: 0.0, alpha: 1.0)
        upRamp.lineWidth = 3
        upRamp.physicsBody = SKPhysicsBody(polygonFrom: upPath)
        upRamp.physicsBody?.isDynamic = false
        upRamp.physicsBody?.categoryBitMask = PhysicsCategory.ground
        upRamp.physicsBody?.friction = 2.0  // High grip for jump ramps!

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
        downRamp.fillColor = SKColor(red: 0.9, green: 0.2, blue: 0.1, alpha: 1.0)  // Bright red landing!
        downRamp.strokeColor = SKColor(red: 0.5, green: 0.1, blue: 0.0, alpha: 1.0)
        downRamp.lineWidth = 3
        downRamp.physicsBody = SKPhysicsBody(polygonFrom: downPath)
        downRamp.physicsBody?.isDynamic = false
        downRamp.physicsBody?.categoryBitMask = PhysicsCategory.ground
        downRamp.physicsBody?.friction = 2.0  // High grip for landings!

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
        landing.physicsBody?.friction = 2.0  // High grip!

        let container = SKNode()
        container.addChild(marker)
        container.addChild(landing)
        nextX += 300

        return container
    }
}
