import Foundation

enum TrickType: String {
    case backflip = "Backflip"
    case frontflip = "Frontflip"
    case doubleBackflip = "Double Backflip"
    case doubleFrontflip = "Double Frontflip"
    case tripleFlip = "Triple Flip"

    var basePoints: Int {
        switch self {
        case .backflip: return 100
        case .frontflip: return 100
        case .doubleBackflip: return 300
        case .doubleFrontflip: return 300
        case .tripleFlip: return 600
        }
    }
}

struct TrickResult {
    let type: TrickType
    let points: Int
    let comboMultiplier: Int
}

class TrickSystem {

    private(set) var totalScore: Int = 0
    private(set) var currentCombo: Int = 0
    private var totalRotation: CGFloat = 0
    private var isAirborne = false
    private var tricksThisJump: [TrickType] = []

    // Track rotation while airborne
    func startAirborne() {
        isAirborne = true
        totalRotation = 0
        tricksThisJump = []
    }

    func addRotation(_ delta: CGFloat) {
        guard isAirborne else { return }
        totalRotation += delta
    }

    // Called on successful landing - returns tricks performed
    func land() -> [TrickResult] {
        guard isAirborne else { return [] }
        isAirborne = false

        let tricks = evaluateTricks()

        if tricks.isEmpty {
            currentCombo = 0
        } else {
            currentCombo += 1
        }

        var results: [TrickResult] = []
        for trick in tricks {
            let multiplier = max(1, currentCombo)
            let points = trick.basePoints * multiplier
            totalScore += points
            results.append(TrickResult(
                type: trick,
                points: points,
                comboMultiplier: multiplier
            ))
        }

        totalRotation = 0
        return results
    }

    // Called on crash
    func crash() {
        isAirborne = false
        totalRotation = 0
        currentCombo = 0
        tricksThisJump = []
    }

    func reset() {
        totalScore = 0
        currentCombo = 0
        totalRotation = 0
        isAirborne = false
        tricksThisJump = []
    }

    private func evaluateTricks() -> [TrickType] {
        let fullRotations = totalRotation / (.pi * 2)
        let absRotations = abs(fullRotations)
        let isBackward = fullRotations < 0

        var tricks: [TrickType] = []

        if absRotations >= 3.0 {
            tricks.append(.tripleFlip)
        } else if absRotations >= 2.0 {
            tricks.append(isBackward ? .doubleBackflip : .doubleFrontflip)
        } else if absRotations >= 0.9 {
            tricks.append(isBackward ? .backflip : .frontflip)
        }

        return tricks
    }
}
