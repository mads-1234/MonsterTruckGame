# Monster Truck Mayhem for Apple TV

A 2D side-scrolling monster truck game for Apple TV with game controller support.

## Features
- Drive a monster truck through terrain with ramps and jumps
- Perform tricks (flips, spins) for points
- Land correctly or crash and restart
- 🎮 Controller support: PlayStation (DualShock 4 / DualSense) & Xbox controllers
- 🎵 Retro 8-bit arcade music and sound effects
- 👦 Featuring Konrad as your pixel art driver!

## Requirements
- Xcode 15+
- tvOS 17.0+
- Apple TV (4th generation or later)
- Game controller (PlayStation DualShock 4/DualSense or Xbox controller)

## Building
1. Open `MonsterTruckGame.xcodeproj` in Xcode
2. Select your Apple TV as target device
3. Build and run

## Controls

### PlayStation Controller (DualShock 4 / DualSense)
- **Left stick / D-pad**: Lean truck forward/backward in air
- **R2**: Accelerate (with engine sound!)
- **L2**: Brake
- **✕ (Cross)**: Jump / boost off ramps
- **⭕ (Circle)**: Restart after crash
- **△ (Triangle)**: Pause

### Xbox Controller
- **Left stick / D-pad**: Lean truck forward/backward in air
- **RT (Right Trigger)**: Accelerate (with engine sound!)
- **LT (Left Trigger)**: Brake
- **A**: Jump / boost off ramps
- **B**: Restart after crash
- **Y**: Pause

## Tricks
- **Backflip**: Full backward rotation in air (100 pts)
- **Frontflip**: Full forward rotation in air (100 pts)
- **Double flip**: Two rotations in one jump (300 pts)
- **Triple flip**: Three rotations (600 pts)
- **Combo**: Chain tricks across landings for multiplier bonus
