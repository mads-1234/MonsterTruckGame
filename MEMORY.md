# Monster Truck Mayhem - Learnings & Notes

## Project Architecture
- **Tech**: Swift 5 + SpriteKit, targeting tvOS 17.0+
- **Resolution**: 1920x1080 (standard tvOS)
- **Files**: GameScene (core loop), LevelGenerator (terrain), MenuScene (menu), TrickSystem (scoring), ControllerManager (input), GameViewController, AppDelegate
- **Audio**: AVFoundation — 4 assets (background_music, engine_sound, crash_sound, horn_sound)
- **Visual style**: Retro 8-bit pixel art — all sprites use `.nearest` filteringMode

## Build & Run
- Scheme: `MonsterTruckGame`, target: `MonsterTruckGame`
- Simulator: `xcodebuild ... -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' build`
- Device: `xcodebuild ... -destination 'generic/platform=tvOS' build`
- Device signing: Apple Development (Mads Weidemann Egseth), team VL7V9QNTJW, automatic provisioning
- Simulators: Apple TV 4K (3rd gen), Apple TV 4K (3rd gen at 1080p), Apple TV — all tvOS 26.2

## Physics Tuning (current values)
- Gravity: -7.0 (reduced for extended air time)
- Truck body mass: 1.5, wheel mass: 0.3
- Wheel radius: 28, friction: 2.0-3.0
- Max speed: 4,500, accel force: 600, wheel angular vel: -35
- km/h display multiplier: 0.12 (max ~540 km/h displayed)
- Spring joints: damping 1.0, frequency 6.0
- Jump impulse: (80, 350)
- Crash angle threshold: 100° (π/1.8)
- Air rotation torque: -3.0

## Terrain Generation (current distribution)
- Flat (65%): 300-600 width, tiled 64px dirt+grass sprites + 4 rows underground dirt
- Straight ramps (15%): 60-150 height, 250-400 width
- Hills (15%): up-ramp → flat top → down-ramp, continuous (120-200px height)
- Big hills (10%): same as hill but taller (220-320px), red texture
- No curved ramps or gaps — all terrain is continuous
- Ramp overlap: 6px past edges, strokeColor=.clear, tileSize+1 overlap
- Underground fill: all segments have 4 rows of dirt tiles below
- Death zone at y = -200
- Initial: 800 flat + 20 random segments, then infinite procedural

## SpriteKit Pixel Art Notes
- `SKTexture.filteringMode = .nearest` — critical for crisp pixel art (prevents bilinear blur)
- `SKShapeNode.fillTexture` requires `.fillColor = .white` (not .clear) to render the texture
- `SKPhysicsBody(polygonFrom:)` max 12 vertices, must be convex
- Curved ramp Bézier: P1 at (0.85w, 0.1h) = gentle start, steep end (ski-jump). NOT (0.1w, 0.9h) which makes a wall
- Tiled terrain: invisible SKNode for physics + visible SKSpriteNode tiles as children
- Background gaps: need sky fill + ground fill sprites that follow camera to prevent empty areas showing
- Parallax: sun 5%, clouds 10%, mountains 20% of camera X speed

## Trick System
- Flip detection: 0.85+ rotations (single), 2.0+ (double), 3.0+ (triple)
- Big Air: height > 200px above ground
- Perfect Landing: angle < π/12 after performing tricks
- Air time bonus: +10pts per 0.1s over 1 second
- Base points: single 150, double 500, triple 1200, big air 200, perfect landing 100
- Combo multiplier applied to all trick points
- Y/Triangle = restart (anytime), B/Circle = pause
- All UI text in Norwegian

## Asset Catalog
- 11 imagesets in Assets.xcassets: konrad, truck_body, wheel, ground_dirt, ground_grass, ramp_surface, ramp_big, mountains, cloud, sun, title_bg
- All generated with gpt-image-1 at 1024x1024 (mountains/title_bg at 1536x1024)

## Swiftlint
- Some violations in current code (naming, function/file length)
- Consider adding `.swiftlint.yml` to tune rules for game dev style

## Tooling
- swiftlint installed via Homebrew
- OpenAI image MCP configured (`gpt-image-1` via `@lpenguin/openai-image-mcp`)
- xcodebuild + xcrun simctl available for CLI builds and simulator management
