import GameController

/// Mottar input-events fra `ControllerManager` etter at de er normalisert
/// på tvers av PlayStation og Xbox-kontrollere.
///
/// Trigger-verdier (`didPressAccelerate`, `didPressBrake`) er kontinuerlige
/// i [0, 1]. Lean (`didLean`) er kontinuerlig i [-1, 1] hvor negativ er
/// bakover. Knapper rapporterer kun pressed-edge (ikke release).
protocol ControllerManagerDelegate: AnyObject {
    /// Kalt når en kontroller blir tilkoblet etter scene-oppstart.
    func controllerDidConnect()
    /// Kalt når kontrolleren mister forbindelsen (utgått batteri, Bluetooth osv.).
    func controllerDidDisconnect()
    /// R2 / RT. `value` ∈ [0, 1] — analog gass.
    func didPressAccelerate(_ value: Float)
    /// L2 / LT. `value` ∈ [0, 1] — analog brems.
    func didPressBrake(_ value: Float)
    /// X (PS) / A (Xbox). I `GameScene` brukt som hopp; i `MenuScene` som start.
    func didPressJump()
    /// Triangle (PS) / Y (Xbox). Alltid en restart, også uten krasj.
    func didPressRestart()
    /// O (PS) / B (Xbox). Toggler `isPaused`.
    func didPressPause()
    /// Venstre stick eller D-pad x-akse. `value` ∈ [-1, 1] (negativ = bakover).
    func didLean(_ value: Float)
}

/// Tynt lag over `GameController.framework` som normaliserer
/// PlayStation- og Xbox-kontroller-events til `ControllerManagerDelegate`.
///
/// Apple's `GCExtendedGamepad` mapper begge typer kontroller til samme
/// abstrakte buttonA/B/Y, så X på PS = A på Xbox osv. Vi videreformidler
/// kun de inputs spillet bryr seg om (gass, brems, hopp, restart, pause, lean).
///
/// Én instans per scene — `MenuScene` og `GameScene` lager hver sin og
/// kobler seg som delegate.
class ControllerManager {

    weak var delegate: ControllerManagerDelegate?
    private var controller: GCController?

    init() {
        setupNotifications()
        connectExistingController()
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerConnected),
            name: .GCControllerDidConnect,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDisconnected),
            name: .GCControllerDidDisconnect,
            object: nil
        )
    }

    private func connectExistingController() {
        if let existing = GCController.controllers().first {
            setupController(existing)
        }
    }

    @objc private func controllerConnected(_ notification: Notification) {
        guard let gc = notification.object as? GCController else { return }
        setupController(gc)
        delegate?.controllerDidConnect()
    }

    @objc private func controllerDisconnected(_ notification: Notification) {
        controller = nil
        delegate?.controllerDidDisconnect()
    }

    private func setupController(_ gc: GCController) {
        controller = gc

        // Log controller type
        let productCategory = gc.productCategory
        print("🎮 Controller connected: \(productCategory)")
        if productCategory.contains("Xbox") {
            print("   Xbox controller detected")
        } else if productCategory.contains("DualShock") || productCategory.contains("DualSense") {
            print("   PlayStation controller detected")
        }

        guard let gamepad = gc.extendedGamepad else { return }

        // R2 = accelerate
        gamepad.rightTrigger.valueChangedHandler = { [weak self] _, value, _ in
            self?.delegate?.didPressAccelerate(value)
        }

        // L2 = brake
        gamepad.leftTrigger.valueChangedHandler = { [weak self] _, value, _ in
            self?.delegate?.didPressBrake(value)
        }

        // X button (buttonA on Apple) = jump
        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed { self?.delegate?.didPressJump() }
        }

        // Circle / B button = pause
        gamepad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed { self?.delegate?.didPressPause() }
        }

        // Triangle / Y button = restart
        gamepad.buttonY.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed { self?.delegate?.didPressRestart() }
        }

        // Left stick / D-pad = lean
        gamepad.leftThumbstick.xAxis.valueChangedHandler = { [weak self] _, value in
            self?.delegate?.didLean(value)
        }
        gamepad.dpad.xAxis.valueChangedHandler = { [weak self] _, value in
            self?.delegate?.didLean(value)
        }
    }
}
