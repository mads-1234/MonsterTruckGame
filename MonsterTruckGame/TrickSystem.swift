import Foundation

enum TrickType: String {
    case backflip = "BAKLENGS SALTO"
    case frontflip = "FORLENGS SALTO"
    case doubleBackflip = "DOBBEL SALTO"
    case doubleFrontflip = "DOBBEL SALTO!"
    case tripleFlip = "TRIPPEL SALTO"
    case bigAir = "SVEVETUR"
    case perfectLanding = "PERFEKT LANDING"

    var basePoints: Int {
        switch self {
        case .backflip: return 150
        case .frontflip: return 150
        case .doubleBackflip: return 500
        case .doubleFrontflip: return 500
        case .tripleFlip: return 1200
        case .bigAir: return 200
        case .perfectLanding: return 100
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
    private(set) var bestCombo: Int = 0
    private(set) var airTime: TimeInterval = 0
    private var totalRotation: CGFloat = 0
    private var isAirborne = false
    private var airborneStartTime: TimeInterval = 0
    private var maxHeight: CGFloat = 0

    // Track rotation while airborne
    func startAirborne() {
        isAirborne = true
        totalRotation = 0
        airborneStartTime = ProcessInfo.processInfo.systemUptime
        maxHeight = 0
    }

    func addRotation(_ delta: CGFloat) {
        guard isAirborne else { return }
        totalRotation += delta
    }

    func updateHeight(_ height: CGFloat) {
        guard isAirborne else { return }
        if height > maxHeight {
            maxHeight = height
        }
    }

    // Called on successful landing - returns tricks performed
    func land(landingAngle: CGFloat) -> [TrickResult] {
        guard isAirborne else { return [] }
        isAirborne = false

        airTime = ProcessInfo.processInfo.systemUptime - airborneStartTime
        let tricks = evaluateTricks(landingAngle: landingAngle)

        if tricks.isEmpty {
            currentCombo = 0
        } else {
            currentCombo += 1
            if currentCombo > bestCombo {
                bestCombo = currentCombo
            }
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

        // Air time bonus: 10 points per 0.1 second over 1 second
        if airTime > 1.0 {
            let airBonus = Int((airTime - 1.0) * 100) * max(1, currentCombo)
            totalScore += airBonus
        }

        totalRotation = 0
        maxHeight = 0
        return results
    }

    // Called on crash
    func crash() {
        isAirborne = false
        totalRotation = 0
        currentCombo = 0
        maxHeight = 0
    }

    func reset() {
        totalScore = 0
        currentCombo = 0
        bestCombo = 0
        totalRotation = 0
        airTime = 0
        isAirborne = false
        maxHeight = 0
    }

    private func evaluateTricks(landingAngle: CGFloat) -> [TrickType] {
        let fullRotations = totalRotation / (.pi * 2)
        let absRotations = abs(fullRotations)
        let isBackward = fullRotations < 0

        var tricks: [TrickType] = []

        // Flip tricks
        if absRotations >= 3.0 {
            tricks.append(.tripleFlip)
        } else if absRotations >= 2.0 {
            tricks.append(isBackward ? .doubleBackflip : .doubleFrontflip)
        } else if absRotations >= 0.85 {
            tricks.append(isBackward ? .backflip : .frontflip)
        }

        // Big Air: awarded for high jumps (maxHeight > 200 above ground)
        if maxHeight > 200 {
            tricks.append(.bigAir)
        }

        // Perfect Landing: near-flat landing after doing at least one trick
        if !tricks.isEmpty && landingAngle < .pi / 12 {
            tricks.append(.perfectLanding)
        }

        return tricks
    }
}
