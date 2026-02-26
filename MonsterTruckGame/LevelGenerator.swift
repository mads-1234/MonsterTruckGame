import SpriteKit

struct TerrainSegment {
    let node: SKNode
    let width: CGFloat
}

class LevelGenerator {

    private let sceneSize: CGSize
    private let groundY: CGFloat
    private var nextX: CGFloat = 0

    // Cached textures for pixel art
    private let dirtTexture: SKTexture
    private let grassTexture: SKTexture
    private let rampTexture: SKTexture
    private let rampBigTexture: SKTexture

    init(sceneSize: CGSize, groundY: CGFloat) {
        self.sceneSize = sceneSize
        self.groundY = groundY

        dirtTexture = SKTexture(imageNamed: "ground_dirt")
        dirtTexture.filteringMode = .nearest
        grassTexture = SKTexture(imageNamed: "ground_grass")
        grassTexture.filteringMode = .nearest
        rampTexture = SKTexture(imageNamed: "ramp_surface")
        rampTexture.filteringMode = .nearest
        rampBigTexture = SKTexture(imageNamed: "ramp_big")
        rampBigTexture.filteringMode = .nearest
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
        let roll = Int.random(in: 0...20)

        switch roll {
        case 0...12:
            // Flat terrain (65%)
            return [makeFlat(width: CGFloat.random(in: 300...600))]
        case 13...15:
            // Small ramps (15%)
            return [makeRamp(height: CGFloat.random(in: 60...150), width: CGFloat.random(in: 250...400))]
        case 16...18:
            // Hill (up + flat top + down) (15%)
            return [makeHill()]
        case 19...20:
            // Big hill (10%)
            return [makeBigHill()]
        default:
            return [makeFlat(width: 400)]
        }
    }

    private func makeFlat(width: CGFloat) -> SKNode {
        let container = SKNode()
        let tileSize: CGFloat = 64

        // Invisible physics body spanning the full width
        let physicsNode = SKNode()
        physicsNode.position = CGPoint(x: nextX + width / 2, y: groundY)
        physicsNode.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: width, height: 60))
        physicsNode.physicsBody?.isDynamic = false
        physicsNode.physicsBody?.categoryBitMask = PhysicsCategory.ground
        physicsNode.physicsBody?.friction = 2.0
        container.addChild(physicsNode)

        // Tiled sprites
        let tilesNeeded = Int(ceil(width / tileSize))
        for i in 0..<tilesNeeded {
            let tileX = nextX + CGFloat(i) * tileSize + tileSize / 2

            // Grass tile (top)
            let grass = SKSpriteNode(texture: grassTexture, size: CGSize(width: tileSize + 1, height: tileSize))
            grass.position = CGPoint(x: tileX, y: groundY + 16)
            grass.zPosition = -1
            container.addChild(grass)

            // Dirt tiles filling downward
            for row in 0..<4 {
                let dirt = SKSpriteNode(texture: dirtTexture, size: CGSize(width: tileSize + 1, height: tileSize))
                dirt.position = CGPoint(x: tileX, y: groundY - 16 - CGFloat(row) * tileSize)
                dirt.zPosition = -1
                container.addChild(dirt)
            }
        }

        nextX += width
        return container
    }

    /// Simple straight ramp — triangle going up to the right, then flat connects after
    private func makeRamp(height: CGFloat, width: CGFloat) -> SKNode {
        let container = SKNode()
        container.position = CGPoint(x: nextX, y: groundY)

        // Straight ramp path with generous overlap
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -6, y: -40))
        path.addLine(to: CGPoint(x: -6, y: 0))
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: width + 6, y: height))
        path.addLine(to: CGPoint(x: width + 6, y: -40))
        path.closeSubpath()

        let ramp = SKShapeNode(path: path)
        ramp.fillColor = .white
        ramp.fillTexture = rampTexture
        ramp.strokeColor = .clear  // No outline
        ramp.lineWidth = 0

        ramp.physicsBody = SKPhysicsBody(polygonFrom: path)
        ramp.physicsBody?.isDynamic = false
        ramp.physicsBody?.categoryBitMask = PhysicsCategory.ground
        ramp.physicsBody?.friction = 2.0

        container.addChild(ramp)

        // Underground fill
        addUndergroundFill(to: container, startX: -6, width: width + 12)

        nextX += width

        return container
    }

    /// Hill: up-ramp → flat top → down-ramp, NO gap, continuous ground
    private func makeHill() -> SKNode {
        let container = SKNode()
        container.position = CGPoint(x: nextX, y: groundY)

        let rampWidth: CGFloat = 200
        let topWidth: CGFloat = 150
        let hillHeight: CGFloat = CGFloat.random(in: 120...200)
        let totalWidth = rampWidth + topWidth + rampWidth

        // Single polygon: up-slope, flat top, down-slope, filled bottom
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -6, y: -40))
        path.addLine(to: CGPoint(x: -6, y: 0))
        path.addLine(to: CGPoint(x: rampWidth, y: hillHeight))
        path.addLine(to: CGPoint(x: rampWidth + topWidth, y: hillHeight))
        path.addLine(to: CGPoint(x: totalWidth + 6, y: 0))
        path.addLine(to: CGPoint(x: totalWidth + 6, y: -40))
        path.closeSubpath()

        let hill = SKShapeNode(path: path)
        hill.fillColor = .white
        hill.fillTexture = rampTexture
        hill.strokeColor = .clear
        hill.lineWidth = 0

        hill.physicsBody = SKPhysicsBody(polygonFrom: path)
        hill.physicsBody?.isDynamic = false
        hill.physicsBody?.categoryBitMask = PhysicsCategory.ground
        hill.physicsBody?.friction = 2.0

        container.addChild(hill)

        // Underground fill across entire hill
        addUndergroundFill(to: container, startX: 0, width: totalWidth)

        nextX += totalWidth

        return container
    }

    /// Big hill: steeper, taller, red texture — great for big air tricks
    private func makeBigHill() -> SKNode {
        let container = SKNode()
        container.position = CGPoint(x: nextX, y: groundY)

        let rampWidth: CGFloat = 250
        let topWidth: CGFloat = 80
        let hillHeight: CGFloat = CGFloat.random(in: 220...320)
        let totalWidth = rampWidth + topWidth + rampWidth

        let path = CGMutablePath()
        path.move(to: CGPoint(x: -6, y: -40))
        path.addLine(to: CGPoint(x: -6, y: 0))
        path.addLine(to: CGPoint(x: rampWidth, y: hillHeight))
        path.addLine(to: CGPoint(x: rampWidth + topWidth, y: hillHeight))
        path.addLine(to: CGPoint(x: totalWidth + 6, y: 0))
        path.addLine(to: CGPoint(x: totalWidth + 6, y: -40))
        path.closeSubpath()

        let hill = SKShapeNode(path: path)
        hill.fillColor = .white
        hill.fillTexture = rampBigTexture
        hill.strokeColor = .clear
        hill.lineWidth = 0

        hill.physicsBody = SKPhysicsBody(polygonFrom: path)
        hill.physicsBody?.isDynamic = false
        hill.physicsBody?.categoryBitMask = PhysicsCategory.ground
        hill.physicsBody?.friction = 2.0

        container.addChild(hill)

        // Underground fill
        addUndergroundFill(to: container, startX: 0, width: totalWidth)

        nextX += totalWidth

        return container
    }

    /// Adds dirt tile fill below terrain segments
    private func addUndergroundFill(to container: SKNode, startX: CGFloat, width: CGFloat) {
        let tileSize: CGFloat = 64
        let tilesNeeded = Int(ceil(width / tileSize))
        for i in 0..<tilesNeeded {
            let tileX = startX + CGFloat(i) * tileSize + tileSize / 2
            for row in 0..<4 {
                let dirt = SKSpriteNode(texture: dirtTexture, size: CGSize(width: tileSize + 1, height: tileSize))
                dirt.position = CGPoint(x: tileX, y: -40 - CGFloat(row) * tileSize)
                dirt.zPosition = -2
                container.addChild(dirt)
            }
        }
    }
}
