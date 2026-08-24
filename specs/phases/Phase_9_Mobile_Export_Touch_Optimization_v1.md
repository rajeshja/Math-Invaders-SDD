# Phase 9 — Mobile Export & Touch Optimization

**Goal:** package the fully-featured, fully-polished game (Phases 0–8) into an installable Android and/or iOS build, and verify it holds up under real device scaling, touch input, and screen geometry — a packaging/configuration pass, not a feature pass.

**Source docs:** Build Plan §Phase 9, Spec §1 (target audience — young children, informing touch-target care), §7 (44px+ minimum touch target note), §3 (720×1280 portrait base resolution), Tech Stack §1 (export targets: Android, iOS, HTML5 for quick testing).

---

## 1. Requirements

### Functional Requirements
- FR9.1 — An Android export preset is configured in Godot (package name, icon/splash, orientation locked portrait, min/target SDK per current Godot 4.x Android export requirements), producing an installable `.apk`/`.aab`.
- FR9.2 — An iOS export preset is configured (bundle identifier, orientation locked portrait, per Godot's iOS exporter requirements), producing a build installable via Xcode/TestFlight — if a Mac and Apple developer account are available to the team; otherwise this is documented as a follow-up and Android is treated as the primary target for this phase.
- FR9.3 — All tappable UI — answer buttons at minimum, and any other interactive elements (banners, restart/play-again controls) — are verified to meet the 44px+ minimum touch target guidance from Spec §7, measured at **actual on-device scaling**, not just base-resolution editor pixel values.
- FR9.4 — Safe-area insets (notches, rounded corners, home indicator) are handled so the HUD (top) and question panel (bottom) are never obscured or clipped on notched portrait phones.
- FR9.5 — The exported build is tested on at least one real Android device or emulator (and an iOS device/simulator, if pursued), confirming touch input, scaling, and layout behave correctly outside the desktop editor.

### Non-Functional Requirements
- NFR9.1 — Touch target verification must account for the game's scaling from the 720×1280 base resolution (Spec §3) to actual device resolutions — a button that measures 44px+ at design resolution but shrinks below that threshold on a smaller physical device fails this requirement.
- NFR9.2 — Export configuration changes are packaging/config only — no gameplay, art, or audio logic from Phases 0–8 is altered in this phase.

### Out of Scope
- Any new gameplay features, art assets, or audio (all prior phases).
- Playtesting-driven balance/tuning changes (Phase 10).

---

## 2. Detailed Implementation Plan

1. **Android export preset**: in Project Settings → Export, add an Android preset — package name, app icon/splash (from the finalized art per Phase 8), orientation locked to portrait, min/target SDK set per current Godot 4.x Android export documentation.
2. **iOS export preset** (if pursued in this pass): add an iOS preset — bundle identifier, orientation locked portrait, following Godot's iOS exporter setup (provisioning/signing requirements depend on the team's Apple developer account access).
3. **Confirm scaling/stretch settings**: verify Project Settings → Display → Window stretch mode/aspect still matches the 720×1280 portrait base resolution decision from Phase 0, so scaling to different device sizes is predictable and doesn't distort UI.
4. **Touch-target audit**: measure `AnswerButtons` and any other tappable controls against the 44px+ guidance from Spec §7, calculating the **effective on-device size** (base-resolution size × the device's actual stretch/scale factor), not just the raw pixel dimensions set in the editor at design resolution.
5. **Safe-area handling**: use Godot's safe-area API (or manual margin/anchor adjustments informed by `DisplayServer.get_display_safe_area()`) so the `HUD` (top) and `QuestionPanel` (bottom) respect notch/home-indicator regions on notched portrait phones, per Spec §3's layout.
6. **Build and install**: produce a build via the Android preset and install it on at least one real device or emulator; repeat for iOS if pursued.
7. **No new GUT tests** — this is a packaging/configuration phase, not new logic; verification is device-based and manual, matching the Build Plan's Phase 9 milestone framing ("installable build running on Android and/or iOS device").
8. **Regression pass**: re-run the full existing GUT suite once after export-config changes to confirm the packaging work introduced no unintended code changes affecting gameplay logic (NFR9.2).

---

## 3. Testing Plan

### Automated Tests (GUT)
- No new dedicated test file for this phase.
- **Regression check:** run the full existing GUT suite (all strategy tests, `question_generator`, `WaveManager`, `LevelManager`, `GameManager`, `HighScoreManager`) post-export-configuration to confirm 0 failures — export/packaging changes should not touch gameplay code at all, so this run should be a pure confirmation.

### Manual Test Checklist
| # | Scenario | Expected Result |
|---|---|---|
| 1 | Install and launch the exported build on a real Android device or emulator | Game launches, runs, and is fully playable outside the editor |
| 2 | (If pursued) Install and launch on an iOS device/simulator | Game launches, runs, and is fully playable outside the editor |
| 3 | Attempt to tap each of the 4 answer buttons on the device | All are comfortably tappable with a finger, meeting the 44px+ effective touch-target size at actual device scale |
| 4 | View the game on a notched device/simulator | HUD (top) and question panel (bottom) are fully visible, not obscured or clipped by the notch or home-indicator area |
| 5 | Rotate/attempt to rotate the device | Orientation stays locked to portrait |
| 6 | Compare on-device visuals to the in-editor build | No visual regressions or scaling artifacts introduced by the export process |
| 7 | Run full GUT suite | All prior phases' tests still pass, 0 failures |

**Definition of Done:** an installable, fully playable build runs correctly on at least one real Android device/emulator (and iOS, if pursued), with all touch targets verified comfortable at real device scale, safe areas correctly respected on notched phones, and no regressions in the underlying gameplay logic's GUT suite.
