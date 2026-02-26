import GameController

protocol ControllerManagerDelegate: AnyObject {
    func controllerDidConnect()
    func controllerDidDisconnect()
    func didPressAccelerate(_ value: Float)
    func didPressBrake(_ value: Float)
    func didPressJump()
    func didPressRestart()
    func didPressPause()
    func didLean(_ value: Float) // -1 = back, 1 = forward
}

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
