# Math Invaders (Godot Edition): Build Plan

The guiding rule: **after every phase, the game should run and be playable end-to-end**, even if it looks and feels rough. Each phase adds one layer of depth on top of a working loop, rather than building all systems in parallel before anything is playable. See the companion **Spec** and **Tech Stack** documents for the detailed rules and architecture each phase implements.

Unit testing with **GUT** (see Tech Stack, Section 8) is part of the development process, not a separate pass — each phase below includes writing/updating GUT tests for the non-visual logic it introduces, and a phase isn't considered done until its tests are green alongside the playable milestone.

---

### Phase 0 — Project Setup (½–1 day)
- Install Godot 4, create project, set portrait resolution (e.g., 720×1280) and mobile render settings.
- Set up Git repo and folder structure, including `scripts/questions/strategies/`, `test/unit/questions/`, and `assets/images/` (background/, ships/, enemies/, ui/, effects/ per the Tech Stack doc).
- Import whichever real image assets are already available (even a partial set); drop same-dimension placeholder PNGs into the matching asset folders for anything not yet supplied, per the Spec's asset table.
- Install the **GUT** addon (AssetLib or Git submodule under `addons/gut/`), enable it under Project Settings → Plugins, and add a `.gutconfig.json` pointing at `test/unit/`. Confirm it runs (even with zero tests) from both the editor GUT panel and the command line.
- **Milestone:** empty Godot project runs on device/emulator and in-editor, with the asset folder structure in place, GUT installed and runnable, and ready to reference.

### Phase 1 — Minimum Playable Loop (first thing you can actually play)
- Real background image (`background_space.png`, or its placeholder) as a full-screen `TextureRect`/`Sprite2D` — no stars/parallax animation yet, just the static image.
- Real player ship sprite (`player_ship.png`) on the `Player` node instead of a `ColorRect`.
- One enemy using its real category sprite (e.g., `enemy_ship_addition.png`) that appears at the top (the full 10-enemy formation is introduced in Phase 3 — this phase just proves out spawn → answer → destroy).
- One hardcoded addition question, with the question panel and answer buttons already using `question_panel_bg.png` and `answer_button_normal.png` rather than default Godot theme buttons.
- Tapping correct answer: enemy disappears (no bullet sprite/animation yet), score +1 shown as plain text.
- Tapping wrong answer: nothing happens, question stays.
- **Milestone: fully playable, single-question game loop, already built on the real (or correctly-sized placeholder) art assets** — not colored rectangles. This is the "something to see and play" deliverable, and it already looks like the intended game rather than a wireframe.

### Phase 2 — Question Strategy Pattern & Bullets
- Implement `question_strategy.gd` (base class) and the first two concrete strategies: `addition_strategy.gd`, `subtraction_strategy.gd`.
- Implement `question_generator.gd` as the dispatcher that delegates to the right strategy by category name.
- Add the real bullet sprite (`player_bullet.png`): player fires a visible projectile on correct answer that travels to the enemy before it's destroyed.
- Wrong answer: enemy is now unaffected and continues descending (introduce simple constant downward movement).
- Enemy sprite now swaps correctly between `enemy_ship_addition.png` and `enemy_ship_subtraction.png` depending on which category is active, confirming the per-instance texture-swap approach from the Tech Stack doc.
- **Testing:** add `test_addition_strategy.gd` and `test_subtraction_strategy.gd` (correct result, exactly one correct choice among 4, no duplicate distractors) and `test_question_generator.gd` (dispatches to the right strategy by category name; handles an unknown category gracefully).
- **Milestone:** playable game where questions are procedurally generated (not hardcoded) for two categories, with visible shooting feedback and category-correct enemy art — and `addition`/`subtraction`/`question_generator` tests passing under GUT.

### Phase 3 — Wave Structure (10 Enemies Visible per Screen)
- Implement `WaveManager.gd`: a wave = 10 enemies from a single category, **all spawned together in a formation when the wave starts**, not one at a time — each using the real sprite for that wave's category.
- One enemy at a time is "active" (linked to the currently-displayed question); on a correct answer that enemy is destroyed and removed, so the player sees the on-screen formation visibly shrink (10 → 9 → 8 → ...).
- Add `multiplication_strategy.gd` and `division_strategy.gd`, registered in `question_generator.gd`, along with their matching `enemy_ship_multiplication.png`/`enemy_ship_division.png` sprites.
- Wire up wave sequencing: Addition (10) → Subtraction (10) → Multiplication (10) → Division (10). When a wave's 10 enemies are all cleared, a **fresh set of 10** spawns for the next category.
- Add the `wave_complete_banner.png` transition between waves.
- Update HUD to show enemies remaining in the current wave (e.g., "6/10 remaining"), matching the visible formation count.
- **Testing:** add `test_multiplication_strategy.gd` and `test_division_strategy.gd` (mirroring Phase 2's strategy tests); add `test_wave_manager.gd` covering wave-clear detection (0 enemies remaining triggers "Wave Complete"), correct category sequencing, and that a fresh set of 10 spawns for the next category — using GUT doubles/stubs for enemy instances rather than the real scene.
- **Milestone:** a full playthrough of one level's worth of waves, each starting with a full 10-enemy formation of correctly-skinned ships that visibly shrinks as questions are answered correctly, with a clear sense of progress both on screen and in the HUD — backed by passing strategy and `WaveManager` tests.

### Phase 4 — Health, Lives, and Game Over
- Enemy reaching the bottom (or a wrong-answer threshold) reduces health, shown via repeated `heart_icon.png` in the HUD.
- Lives shown via repeated `life_icon.png`; losing all health costs a life.
- Losing all lives triggers a Game Over screen using `game_over_bg.png` (or the background image with an overlay panel) with final score.
- **Testing:** add `test_game_manager.gd` covering health/lives transitions (health reaching 0 costs a life; losing all lives triggers game over) in isolation from the visual HUD.
- **Milestone:** full round-trip play session (start → play through waves → lose → game over screen), fully art-dressed, with `GameManager`'s health/lives logic covered by passing tests.

### Phase 5 — Level Progression
- Implement `LevelManager.gd`: completing all waves in a level triggers the `level_complete_banner.png` transition and advances to the next level.
- Increase difficulty parameter passed into `QuestionGenerator` as levels increase (larger numbers within the same four categories).
- Update HUD to display the current **Level** alongside score, health, and lives.
- **Testing:** add `test_level_manager.gd` covering that the difficulty parameter increases correctly across levels and that `WaveManager`'s category sequence updates as expected at level boundaries.
- **Milestone:** playing through multiple levels, each with the same wave/category structure but increasing difficulty, with `LevelManager` behavior covered by passing tests.

### Phase 6 — Score & High Score Persistence
- Score display refined (top of screen, styled with the HUD's chosen font/iconography).
- `HighScoreManager.gd` saves/loads high score to local storage (`user://`).
- Game Over screen shows "New High Score!" when beaten, and shows current high score otherwise.
- **Testing:** add `test_high_score_manager.gd` covering that the stored high score only updates when the new score is higher, and that save/reload round-trips correctly — using GUT's temp-file helpers rather than the real `user://` save file.
- **Milestone:** high scores persist across app restarts, with `HighScoreManager`'s save/compare logic covered by passing tests.

### Phase 7 — New Question Categories (Stage C Content)
- Add `prime_strategy.gd` (and any other advanced-concept strategies) as new files under `scripts/questions/strategies/`, registered with `question_generator.gd` — no changes needed to existing category strategies.
- Add the matching `enemy_ship_prime.png` sprite for the new category.
- Update `LevelManager.gd` to introduce these new categories as additional waves once a player reaches a defined advanced level.
- **Testing:** add `test_prime_strategy.gd` (mirroring the existing strategy tests) and extend `test_level_manager.gd` to cover that the new category is added to the rotation at the correct threshold.
- **Milestone:** advanced levels include new wave types (e.g., a "Prime Numbers" wave) layered on top of the existing four core categories, each with its own correct art, and covered by the same strategy-level test pattern established in earlier phases.

### Phase 8 — Effects, Animation & Audio Polish
- Add the `enemy_explosion_spritesheet.png` destruction animation on correct answers (replacing the simple "disappear" from earlier phases).
- Add the `starfield_overlay.png` parallax/scroll animation over the background (replacing the static background image from Phase 1).
- Add screen shake or flash on taking damage, and polished tap/press feedback using `answer_button_pressed.png`.
- Add sound effects (fire, hit, miss, wave complete, level complete, game over) and background music.
- Any remaining placeholder images (from Section 7 of the Spec) are swapped for final art at this point, if not already replaced in earlier phases.
- **Milestone:** game looks and sounds like a finished mobile game.

### Phase 9 — Mobile Export & Touch Optimization
- Configure Android/iOS export presets in Godot.
- Verify touch target sizes for answer buttons (44px+ minimum touch targets), test on real devices/emulators.
- Handle safe-area insets for notches on portrait phones.
- **Milestone:** installable build running on Android and/or iOS device.

### Phase 10 — Playtesting & Balancing
- Playtest with target age group; adjust question difficulty pacing per level, distractor plausibility, wave length feel, and enemy speed.
- Fix bugs found during testing; run the full GUT suite after balancing changes to catch regressions in difficulty scaling, distractor generation, and wave/level logic.
- **Milestone:** balanced, kid-tested build ready for wider release, with the full GUT suite passing.

### Phase 11 — Stretch / Future Expansion
- Additional math concepts as new strategies (fractions, percentages, factors/multiples).
- Player profiles for multiple kids on one device.
- Wave/level select or endless-mode toggle.
- Additional non-math subject modules (spelling, science) reusing the same wave/level and strategy-pattern framework.
