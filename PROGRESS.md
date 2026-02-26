# Monster Truck Mayhem - Progress Log

## 2026-02-26 — Norwegian translations, gameplay tuning, menu polish

### What was done
- **All text translated to Norwegian**: trick names (BAKLENGS SALTO, SVEVETUR, etc.), HUD (POENG, KOMBO, I LUFTA), crash overlay (KRASJET!, BESTE KOMBO, Trykk Y for å starte på nytt), menu (Trykk X for å kjøre!, Koble til en kontroller for å spille)
- **Crash tolerance increased**: angle threshold from 72° (π/2.5) to 100° (π/1.8) — much harder to crash
- **Terrain rebalanced**: 65% flat / 15% ramps / 15% hills / 10% big hills (was 40/20/20/20) — fewer jumps
- **Speed & power increased**: accel force 300→600, wheel angular vel -22→-35, max speed 3200→4500, jump impulse (50,200)→(80,350)
- **Music starts on menu**: background_music plays in MenuScene, stops when entering game
- **Controller remapped**: Y/Triangle = restart (was pause), B/Circle = pause (was restart) — matches Xbox convention
- **Konrad on front page**: 220x220 konrad.png sprite centered on menu screen with bounce animation

### Current state
- Build succeeds clean
- All user-facing text in Norwegian
- Game feels faster and more forgiving

---

## 2026-02-26 — Visual polish: fix ramps, textures, menu, no holes

### What was done
- **Regenerated ramp_big texture**: was showing AI prompt text baked into the image — now clean red diagonal stripes
- **Regenerated ramp_surface texture**: was a triangle shape (not tileable) — now clean brown diagonal stripes
- **Regenerated ground_grass texture**: had white margins causing white lines — now edge-to-edge fill
- **Regenerated title_bg**: new version with "KONRAD" baked into the pixel art, no text overlays needed
- **Menu scene cleaned up**: removed "MONSTER TRUCK MAYHEM" and "Featuring Konrad!" text overlays, removed Konrad sprite, removed dim overlay — the title_bg art speaks for itself, only "Press X to Race!" and controller hint remain
- **No more holes in ground**: removed big jump gap entirely — replaced with hills (up-ramp → flat top → down-ramp, continuous ground). Two types: regular hill (120-200px) and big hill (220-320px, red texture)
- **No more curved ramps**: removed Bezier curves that looked wrong — all ramps are now clean straight triangles
- **Ramp stroke removed**: set `strokeColor = .clear` and `lineWidth = 0` — eliminates white outlines around ramp shapes
- **Tile overlap**: tiles now render at tileSize+1 to prevent hairline gaps between tiles
- **Deeper underground fill**: 4 rows of dirt tiles (was 3) below all terrain segments
- **Ramp overlap increased**: ramps extend 6px past edges (was 4px) for better junction sealing

### Current state
- Build succeeds clean
- No more visible white gaps, holes, or texture artifacts
- Terrain types: flat (40%), straight ramps (25%), hills (20%), big hills (20%)

---

## 2026-02-26 — tvOS app icon with "KONRAD" branding

### What was done
- **Full tvOS layered app icon** created (brandassets structure with 3-layer parallax):
  - **Back**: Dark blue-purple pixel art night sky with stars (opaque, required)
  - **Middle**: Orange pixel art monster truck mid-jump with dust
  - **Front**: "KONRAD" in bold red pixel letters with character portrait
- **App Icon - Large**: 1280x768 px (App Store)
- **App Icon - Small**: 400x240 px (Home Screen)
- **Top Shelf Image**: 1920x720 px
- **Top Shelf Image Wide**: 2320x720 px
- All images generated with gpt-image-1, resized to exact dimensions with `sips`
- Fixed `ASSETCATALOG_COMPILER_APPICON_NAME` from `"App Icon"` to `"App Icon & Top Shelf Image"`
- Clean build on both simulator and device targets (no warnings)

### Assets created
- 8 PNG files total (3 layers x 2 sizes + 2 top shelf)
- 14 Contents.json files for the brandassets directory structure

---

## 2026-02-26 — Gameplay fixes: ramps, restart, backgrounds, trick scoring, menu

### What was done
- **Restart button**: B/Circle button now restarts anytime (not just when crashed)
- **Curved ramps fixed**: Bezier control point flipped from (0.1w, 0.9h) to (0.85w, 0.1h) — now ski-jump shape (gentle start, steep launch) instead of wall shape
- **Background gap fix**: Added sky fill + underground dirt fill that follow camera via parallax. No more white/empty gaps visible
- **Parallax scrolling**: Sun (5%), clouds (10%), mountains (20%) move at different rates relative to camera for depth effect
- **More mountains/clouds**: 12 mountain strips and 20 clouds (up from 8/15), extended coverage
- **Underground fill**: Dirt tiles added below all terrain segments (flat, ramps, jumps) — 3 rows of 64px tiles
- **Trick-focused terrain**: Ramp/jump frequency increased (40% flat, 20% straight ramp, 20% curved ramp, 20% big jumps) — was 60/20/15/10
- **Enhanced trick system**:
  - "BIG AIR" bonus (+200 base) for jumps over 200px height
  - "PERFECT LANDING" bonus (+100 base) for landing near-flat after tricks
  - Air time bonus: +10pts per 0.1s over 1 second
  - Flip detection threshold lowered (0.85 rotations, was 0.9) for easier tricks
  - Higher base points: flips 150 (was 100), doubles 500 (was 300), triples 1200 (was 600)
  - Best combo tracked and shown on crash screen
- **Trick popup improvements**: Color-coded by value (yellow/orange/red), scale-pop animation, drop shadows
- **HUD additions**: "AIR TIME" indicator shown while airborne, "COMBO x#" and "BEST COMBO" on crash
- **Menu text styling**: All labels have drop shadows for retro pixel look, dim overlay on title_bg so text pops, softer colors, "Connect a controller" instead of "PlayStation"
- **Crash overlay improved**: Larger, shows best combo, pulsing restart hint

### Current state
- Build succeeds clean (no warnings)
- All 5 issues from feedback addressed

---

## 2026-02-26 — Retro pixel art overhaul, curved ramps & speed tuning

### What was done
- **10 pixel art sprites** generated with gpt-image-1: truck_body, wheel, ground_dirt, ground_grass, ramp_surface, ramp_big, mountains, cloud, sun, title_bg
- **Asset catalog** entries (Contents.json) created for all 10 sprites
- **Ramp gap fix**: Extended ramp paths to y=-36 with 4px horizontal overlap — eliminates visible seam at ground junction
- **Curved ramps**: New `makeCurvedRamp()` using quadratic Bézier sampled at 10 points; convex polygon physics body (12 vertices max). ~15% spawn chance
- **Big jump curved launch**: Up-ramp on big jumps now uses curved quarter-pipe shape
- **Speed reduction**: Max speed 5600→3200, accel force 560→300, wheel angular vel -42→-22, km/h display multiplier 0.36→0.12 (max ~384 km/h displayed)
- **Pixel art truck**: SKSpriteNode with `truck_body` texture replaces flat-color body+stripes+cab+windshield. Konrad sprite kept as child
- **Pixel art wheels**: SKSpriteNode with `wheel` texture replaces SKShapeNode circles with rims/treads
- **Pixel art background**: Textured sun, clouds, mountains replace SKShapeNode primitives. Deep retro blue sky
- **Pixel art terrain**: Tiled 64px dirt+grass sprites with invisible physics body. Ramp/jump shapes use fillTexture
- **Retro fonts**: All `AvenirNext-*` fonts replaced with `Menlo-Bold` (HUD, crash overlay, trick popups, menu)
- **Menu scene**: Pixel art title_bg background, konrad.png sprite at 192px, Menlo-Bold fonts throughout
- **All sprites use `.nearest` filteringMode** for crisp pixel rendering
- **Device build**: Builds and signs for real Apple TV (team VL7V9QNTJW, automatic signing). No physical device connected yet

### Current state
- Build succeeds for both tvOS Simulator and generic tvOS device
- Retro 8-bit visual style throughout
- Smoother ramp transitions and new curved ramp variety

---

## 2026-02-26 — Dev tooling & project documentation

### What was done
- Created `CLAUDE.md` with commit rules (PROGRESS.md required) and memory policy
- Installed **swiftlint** — found 11 violations (6 identifier_name, 3 function_body_length, 1 file_length, 1 type_body_length)
- Verified **xcodebuild** — build succeeds for tvOS Simulator (Apple TV 4K 3rd gen, tvOS 26.2)
- Verified **xcrun simctl** — 3 Apple TV simulators available
- Configured **OpenAI image generation MCP** (`@lpenguin/openai-image-mcp` with `gpt-image-1`)
- Apple documentation access confirmed via built-in WebFetch/WebSearch

### Current state
- Game is fully playable: physics driving, procedural terrain, trick system, audio, controller support (PS + Xbox)
- 1,244 lines of Swift across 7 files
- 2 commits on main, some untracked sprite generation scripts

---

## 2026-02-16 — Complete game features

- Added Konrad pixel art driver sprite visible in truck cab
- Full audio system (background music, engine, crash, horn)
- Xbox controller support alongside PlayStation
- Improved physics: 4-wheel drive, high friction, better hill climbing
- Speed reduced 30% for better control
- Crash detection more forgiving (72° threshold)
- Enhanced terrain graphics, removed random holes

## 2026-02-16 — Initial commit

- Monster Truck Mayhem for Apple TV — SpriteKit + Swift
- Core gameplay: acceleration, braking, jumping, air rotation
- Procedural infinite terrain (flat, ramps, big jumps)
- Trick detection with combo scoring
- Menu scene with animated Konrad character
- PlayStation controller support
- HUD: score, combo, trick display, speed
