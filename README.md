# Monster Truck Mayhem

Et 2D side-scrollende monstertruck-spill for Apple TV — bygget i Swift med SpriteKit. Hovedrolleinnehaver er **Konrad**, som kjører gjennom prosedyralt generert terreng, hopper på ramper og setter saltoer for poeng. Retro 8-bit pikselart, norsk UI, og kontrollerstøtte for både PlayStation og Xbox.

Dette er et hobbyprosjekt. Spillet er ikke i App Store, men kan kjøres på simulator eller signeres til en fysisk Apple TV.

## Krav

| Verktøy / mål        | Versjon                                            |
| -------------------- | -------------------------------------------------- |
| Xcode                | 15+                                                |
| tvOS                 | 17.0+                                              |
| macOS (for utvikling)| Nyeste som støtter Xcode 15                        |
| Apple TV (hardware)  | 4. generasjon eller nyere (kun for fysisk testing) |
| Game controller      | DualShock 4, DualSense, eller Xbox-kontroller      |

Spillet bruker `GameController.framework` og krever en ekstern kontroller — Siri Remote alene fungerer ikke. Det fungerer fint på simulator hvis du har en støttet kontroller paret over Bluetooth med Mac-en.

## Bygg og kjør

1. Åpne `MonsterTruckGame.xcodeproj` i Xcode.
2. Velg scheme `MonsterTruckGame`.
3. Velg destination:
   - **Simulator:** `Apple TV 4K (3rd generation)` (tvOS 26.2 testet)
   - **Fysisk enhet:** Apple TV koblet til via nettverk eller USB-C
4. Trykk Cmd+R for å bygge og kjøre.

Fra kommandolinje (kun macOS):

```bash
# Simulator
xcodebuild -project MonsterTruckGame.xcodeproj \
  -scheme MonsterTruckGame \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
  build

# Generisk tvOS-enhet (for signering)
xcodebuild -project MonsterTruckGame.xcodeproj \
  -scheme MonsterTruckGame \
  -destination 'generic/platform=tvOS' \
  build
```

Signering for fysisk enhet er satt opp med automatic provisioning (team `VL7V9QNTJW`). For deg som ikke har tilgang til det teamet, må du sette ditt eget i Xcode → Signing & Capabilities.

## Prosjektstruktur

Kildekoden ligger i `MonsterTruckGame/`. Alt er ett mål — ingen separate moduler eller Swift Package Manager.

| Fil                       | Ansvar                                                                                        |
| ------------------------- | --------------------------------------------------------------------------------------------- |
| `AppDelegate.swift`       | Standard UIKit-bootstrap. Lager vindu og presenterer `GameViewController`.                    |
| `GameViewController.swift`| Setter opp `SKView` og presenterer `MenuScene` ved oppstart.                                  |
| `MenuScene.swift`         | Hovedmeny: tittelbakgrunn, Konrad-sprite med bounce, "Trykk X" prompt, bakgrunnsmusikk.       |
| `GameScene.swift`         | Hele spillsløyfen: fysikk, kamera, parallax, HUD, krasj-håndtering, audio.                    |
| `LevelGenerator.swift`    | Prosedyral terreng-generering: flatt, ramper, høyder, store høyder. Tiled pikselart.          |
| `TrickSystem.swift`       | Rotasjons-tracking, salto-deteksjon, kombo, poengberegning.                                   |
| `ControllerManager.swift` | Game Controller-abstraksjon. Mapper R2/L2/X/B/Y/stick til delegate-callbacks.                 |
| `Assets.xcassets`         | 11 imagesets (pikselart), App Icon, Top Shelf Image (3-lags parallax).                        |
| `*.mp3`                   | `background_music`, `engine_sound`, `crash_sound`, `horn_sound`.                              |

## Spillsløyfe

1. **Meny** (`MenuScene`) viser Konrad og pulserende "Trykk X for å kjøre!". X starter spillet.
2. **Kjøring** (`GameScene.update`): R2 gir gass (kraft + hjulrotasjon), L2 bremser, X gir hopp-impuls. Kameraet følger trucken med litt forskyvning fremover.
3. **Terreng** genereres prosedyralt etter hvert som kameraet beveger seg høyre. Distribusjon: 65 % flatt, 15 % ramper, 15 % høyder, 10 % store høyder.
4. **Triks** registreres når trucken er i lufta — full rotasjon = salto. Mer rotasjon = doble/trippel. Høyt hopp = "SVEVETUR". Flat landing etter triks = "PERFEKT LANDING". Kjedede landinger gir komboomultiplikator.
5. **Krasj** trigges hvis landings-vinkelen er over 100° (π/1.8) eller om trucken faller under y = -200. Y/Triangle starter på nytt.

## Kontroller

| Handling          | PlayStation         | Xbox                |
| ----------------- | ------------------- | ------------------- |
| Gass              | R2                  | RT (right trigger)  |
| Brems             | L2                  | LT (left trigger)   |
| Hopp / start spill| X (Cross)           | A                   |
| Pause             | O (Circle)          | B                   |
| Restart           | Triangle            | Y                   |
| Lean (luft)       | Venstre stick / D-pad| Venstre stick / D-pad |

Knappene er mappet via `GCExtendedGamepad.buttonA/B/Y` — Apple normaliserer på tvers av PlayStation og Xbox, så X på PS = A på Xbox.

## Triks og poeng

| Triks            | Krav                                | Grunnpoeng |
| ---------------- | ----------------------------------- | ---------- |
| Salto            | ≥ 0.85 rotasjoner i lufta           | 150        |
| Dobbel salto     | ≥ 2.0 rotasjoner                    | 500        |
| Trippel salto    | ≥ 3.0 rotasjoner                    | 1200       |
| Svevetur         | Maks-høyde > 200 px over bakken     | 200        |
| Perfekt landing  | Landings-vinkel < π/12 etter triks  | 100        |

Alle poeng multipliseres med gjeldende kombo. Komboen brytes ved landing uten triks eller ved krasj. Pluss `+10 poeng` per 0.1 sek luft over 1 sek.

## Pikselart og assets

Alle sprites er generert med `gpt-image-1` og lagret som imagesets i `Assets.xcassets`. Filtrering er satt til `.nearest` i kode for å bevare det skarpe pikselart-uttrykket — *aldri* la SpriteKit gjøre bilineær blur på disse.

App-ikonet er et 3-lags tvOS layered icon (sky → truck → "KONRAD"-tekst). Top Shelf Image kommer i normal- og bred-variant.

## Hvor finner jeg X

| Trenger du å vite om...           | Se                                                             |
| --------------------------------- | -------------------------------------------------------------- |
| Hva er nylig endret?              | `PROGRESS.md`                                                  |
| Fysikk-verdier, tuning-history    | `MEMORY.md` (Physics Tuning-seksjonen)                         |
| SpriteKit-gotchas (pikselart osv.)| `MEMORY.md` (SpriteKit Pixel Art Notes)                        |
| Commit-regler / krav til logg     | `CLAUDE.md`                                                    |
| Hvordan triks beregnes            | `TrickSystem.swift` + `MEMORY.md` (Trick System)               |
| Hvilke fysikk-kategorier finnes   | `PhysicsCategory` øverst i `GameScene.swift`                   |
| Hvordan terreng spawnes           | `LevelGenerator.generateNextSegment()`                         |

## Hobbyspill, ikke produkt

Det er ingen tester, ingen CI og ingen App Store-distribusjon. Hvis `xcodebuild` bygger rent og spillet kjører på simulator, er det godt nok. Bidrag og lekenhet er velkomne.

## Kontakt

madsegseth@gmail.com
