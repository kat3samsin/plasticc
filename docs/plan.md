# Plasticc: plan

A disposable film camera for iPhone. Pick a film, tear the plastic off the camera, load the film, shoot the roll without seeing a single frame, rewind, develop, then sort the prints like a deck of cards.

Planned with Fable 5.1 on 2026-10-20. The earlier manual-controls app lives untouched in a separate `film-cam` project; port code from there, don't copy it wholesale.

## Status (2026-10-20)

All ten milestones are built. The whole flow runs in the simulator, from the shop counter to the summary screen. 54 package tests pass (`swift test` in `PlasticcCore`).

| Area | Where | State |
|---|---|---|
| Shop counter, 12/24/36, lab-order settings | `App/Pick`, `App/Settings` | Done; checked in simulator |
| Shrink-wrap tear, canister load | `App/Unbox` | Done; checked in simulator |
| Camera back: counter wheel, finder, flash charge and ready lamp, thumbwheel, shutter | `App/Shoot`, `App/Look` | Done; camera and flash checked on iPhone Air (milestone 4 build) |
| Rewind crank | `App/Rewind`, `RewindCrank.swift` | Done; checked in simulator |
| Lab envelope, countdown, notification | `App/Lab/LabView.swift` | Done; 1-hour notification not yet seen on a device |
| Darkroom, film looks, light leaks, date stamp, fixed exposure | `App/Lab/DarkroomView.swift`, `FilmEngine.swift`, `Developer.swift` | Done; tuned on contact sheets; see `docs/film-looks.md` |
| Print deck, keep to Photos, toss, flip, summary | `App/Review` | Done; keep and toss checked in simulator |
| Sounds and haptics | `App/Feel/Feel.swift`, `App/Sounds`, `tools/make_sounds.py` | Synthesised and wired; not yet heard or felt on a device |
| App icon | `tools/make_icon.swift` | Done |

Still to check on the iPhone: how the haptics and sounds feel (tear, wheel, crank, shutter, flash whine), develop time and memory on a 36-frame roll, and the notification.

Tools: `swift run -c release contact-sheet out.jpg photo.jpg …` in `PlasticcCore` develops photos with every film; `python3 tools/make_sounds.py` rebuilds the sounds; `swift tools/make_icon.swift App/Assets.xcassets/AppIcon.appiconset/icon.png` redraws the icon.

## Decisions

| Topic | Decision |
|---|---|
| Camera | One: "Snappy 35". Only control is flash on/off; fires the real iPhone flash. |
| Films | Fujifilm Superia X-TRA 400, Kodak Portra 800, Ilford HP5 Plus 400. Real names for personal use; rename (e.g. "Superia 400") before any App Store release. |
| Roll length | Separate picker: 12, 24 or 36 exposures, for any film. |
| Shooting | Counter counts down to 0. No thumbnails, ever. Shutter is dead until you wind the thumb wheel (haptic click per notch, firm stop when the frame is ready). |
| End of roll | Rewind crank: circular drag, ticks speed up as resistance drops, soft clunk when the leader leaves the spool. Then develop. |
| Develop time | Setting: Instant (about 6 s animation), 1 hour (default), Next morning (9 AM). Timed options schedule a local notification, "Your roll is ready"; notification permission is asked only when one is chosen. |
| Date stamp | Orange 7-segment stamp, on by default, on/off in Settings. Applied at develop time. |
| Light leaks | Random per frame, seeded so a frame always gets the same leak. Higher chance on the first 1–2 frames (fogged while loading). Superia and Portra: warm orange/red leaks. HP5: grey fog. |
| Review | Card deck. Swipe right saves to Photos (add-only permission) and deletes the sandbox copy. Swipe left deletes it. No in-app album in V1. |
| Settings | Date stamp, develop time, sound on/off. |

### Film looks

Research each stock's published characteristics (colour shifts, contrast, grain, latitude) before tuning in milestone 7.

- **Superia X-TRA 400:** cooler, green-leaning shadows, punchy greens and blues, medium grain.
- **Portra 800:** soft and warm, flattering skin tones, more grain, forgiving in low light.
- **HP5 Plus 400:** black and white, medium contrast, visible grain, deep blacks.

All films: 2:3 portrait crop, slight softness, halation, vignette, flash hotspot with edge fall-off when flash fired.

## Tech

- SwiftUI with `@Observable` models, portrait only, iOS 18+.
- XcodeGen `project.yml` plus a local SwiftPM package `PlasticcCore` that also builds for macOS, so `swift test` runs without a simulator.
- Capture: `AVCaptureSession` + `AVCapturePhotoOutput`, processed JPEG, viewfinder is a plain `AVCaptureVideoPreviewLayer`. No RAW, no live look.
- Look: Core Image at develop time on stored originals. Colour cube generated at runtime from a `LookSpec`, cached per film. One shared `CIContext`.
- Storage: files in `Application Support/Roll/` plus one `roll.json`. Write the image before the manifest; atomic writes.
- Haptics: pre-warmed `UIImpactFeedbackGenerator` / `UISelectionFeedbackGenerator`. Sounds: short synthesised `.caf` files (crinkle, clunk, shutter, wind, rewind) on an `.ambient` audio session.
- Info.plist: `NSCameraUsageDescription`, `NSPhotoLibraryAddUsageDescription`.

## Model (`PlasticcCore`)

```swift
struct FilmStock { id, name, look: LookSpec, grain, vignette, leakChance, leakTint }
enum RollLength: Int { case short = 12, standard = 24, long = 36 }
enum RollPhase { case sealed, unwrapped, loaded, shooting, rewinding, developing, developed, done }
struct Shot { file, takenAt, flash, seed, developedFile?, verdict? }
struct Roll { filmID, length, phase, shots, wound, readyAt? }
```

Transitions are pure functions that throw on an invalid move (`tear`, `load`, `wind`, `shoot`, `rewind(readyAt:)`, `markDeveloped`, `review`). The phase is persisted, so a force-quit resumes on the right screen. `RollStore` writes each image before the manifest and clears the roll after the last card.

`sealed → unwrapped → loaded → shooting → rewinding → developing → developed → done → new roll`

Developing: when the roll is rewound, set `readyAt` from the develop-time setting and schedule the notification. When the app is opened after `readyAt`, render every frame with real progress, then show the deck.

## Screens

1. **Pick:** camera, three film boxes, 12/24/36 picker. Settings button.
2. **Unbox:** tear the wrap (drag from a corner tab, jagged edge, crinkle haptics every 24 pt, springs away past 65 %), drag the canister into the chamber (snap and clunk), door shuts, first wind.
3. **Shoot:** finder, counter window, flash switch, shutter, wind wheel.
4. **Rewind:** crank.
5. **Developing:** countdown until `readyAt`, then the render animation.
6. **Review:** card deck.
7. **Settings**, plus a permission screen when camera access is denied.

## Simulator

`protocol PhotoCapturing { func capture(flash: Bool) async throws -> Data }`, implemented by `AVCamera` and, on the simulator, `SampleCamera`, which cycles bundled sample JPEGs. Port the samples from `film-cam/App/Samples/`.

## Testing

- `swift test`: every roll transition and refused transition, resume after decode, store write order, look engine on synthetic images (HP5 is grey, Portra warmer than source, vignette darkens corners, same seed gives identical output, leak chance higher on frames 1–2), crop size, date stamp position and on/off.
- Simulator: a full 12-shot roll on sample images, force-quit resume, instant develop, deck to Photos, denied-permission paths.
- Device only: preview, flash, haptics feel (tear, wind, rewind), silent switch, notification after 1 hour, develop time and memory on 36 × 12 MP.

## Milestones

Each one is PR-sized: step → verification.

1. **Skeleton:** `project.yml`, `PlasticcCore` with one test, "Hello" root view. → `xcodegen generate`, simulator build, and `swift test` pass.
2. **Model and store** → all transition tests green.
3. **Pick and shoot on samples** (film, length, counter, wind wheel, no thumbnails) → full roll in the simulator, files on disk, relaunch resumes.
4. **Real camera and flash** → device: upright JPEGs with and without flash.
5. **Rewind crank** → simulator flow works; device: haptics feel right.
6. **Develop timing** (setting, `readyAt`, notification) → instant path in the simulator; 1-hour notification on device.
7. **Film looks, leaks, date stamp** (port the engine, research the stocks) → look tests green; prints look like the stock.
8. **Review deck** → kept frames in Photos, trashed ones gone, `Roll/` empty after the last card.
9. **Unboxing** (tear and load) → device: tear feels right, can't be skipped.
10. **Polish** (icon, sounds, accessibility labels, device checklist) → full checklist on iPhone.

## Port from film-cam

- `FilmCore/Sources/FilmCore/FilmEngine.swift`, `LookSpec.swift`, `LUTGenerator.swift`, `DateStamp.swift`, `Roll.swift`
- `FilmCore/Tests/FilmCoreTests/Support.swift` (pixel helpers)
- `App/Feel/DialFeel.swift` (haptics and sound shape)
- `App/Camera/CameraController.swift` (session setup and capture continuation only)
- `App/Samples/*.jpg`

Pitfalls to keep from the old engine: tune effects at a 1000 px long edge and scale by resolution; composite over black so alpha is 1; apply contrast in sRGB, not linear light.
