import Foundation

/// Triks-typer trucken kan utføre i lufta. Rå-strengen brukes direkte
/// som UI-tekst i trick-popup (alltid norsk, store bokstaver).
enum TrickType: String {
    case backflip = "BAKLENGS SALTO"
    case frontflip = "FORLENGS SALTO"
    case doubleBackflip = "DOBBEL SALTO"
    case doubleFrontflip = "DOBBEL SALTO!"
    case tripleFlip = "TRIPPEL SALTO"
    case bigAir = "SVEVETUR"
    case perfectLanding = "PERFEKT LANDING"

    /// Grunnpoeng før kombo-multiplikator. Faktisk poengsum sendt til
    /// HUD og total score er `basePoints * max(1, currentCombo)`.
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

/// Ett triks utført ved én landing. `GameScene` får en `[TrickResult]`
/// fordi en landing kan utløse flere triks samtidig (f.eks. trippel
/// salto + svevetur + perfekt landing).
struct TrickResult {
    let type: TrickType
    /// Allerede multiplisert med kombo — ferdig å vise i UI eller legge til total.
    let points: Int
    /// Komboen som var aktiv da dette trikset ble registrert. 1 = ingen kombo.
    let comboMultiplier: Int
}

/// State machine for triks-deteksjon og poengtelling.
///
/// `GameScene` driver denne via `startAirborne()` (ved første hjul-løft),
/// `addRotation(_:)` per frame i lufta, `updateHeight(_:)` per frame for
/// å spore maks-høyde, og `land(landingAngle:)` ved kontakt med bakken.
/// `crash()` brukes hvis landingen ikke er gyldig — komboen brytes.
///
/// Eies av `GameScene` og lever like lenge som scenen. Restart lager
/// en ny scene (og dermed en ny `TrickSystem`).
class TrickSystem {

    private(set) var totalScore: Int = 0
    private(set) var currentCombo: Int = 0
    private(set) var bestCombo: Int = 0
    private(set) var airTime: TimeInterval = 0
    private var totalRotation: CGFloat = 0
    private var isAirborne = false
    private var airborneStartTime: TimeInterval = 0
    private var maxHeight: CGFloat = 0

    /// Markerer at trucken nettopp har forlatt bakken — nullstiller
    /// rotasjon, høyde-tracking, og starter air-time-klokken.
    func startAirborne() {
        isAirborne = true
        totalRotation = 0
        airborneStartTime = ProcessInfo.processInfo.systemUptime
        maxHeight = 0
    }

    /// Akkumulerer rotasjons-delta. `delta` *må* være normalisert til
    /// [-π, π] av kalleren — se `GameScene.trackRotation()` for hvorfor.
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

    /// Avslutter en luft-fase og returnerer eventuelle triks som ble utført.
    ///
    /// - Parameter landingAngle: Trucken sin vinkel mot horisontalplanet
    ///   ved landing, normalisert til [0, π]. Brukes til "perfekt landing"-bonus.
    /// - Returns: Tom liste hvis ingen triks ble fullført. En liste med ett
    ///   eller flere `TrickResult` ellers — salto, svevetur og perfekt
    ///   landing kan alle utløses i samme landing.
    ///
    /// Sideeffekter: oppdaterer `totalScore`, `currentCombo`, `bestCombo`
    /// og `airTime`. Bryter kombo hvis ingen triks ble registrert.
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

    /// Kalles ved krasj (vinkel-grense eller death zone). Bryter komboen,
    /// men bevarer `totalScore` og `bestCombo` slik at crash-overlayet
    /// kan vise dem.
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
