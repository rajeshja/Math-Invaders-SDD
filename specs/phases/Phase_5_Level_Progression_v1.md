# Phase 5 — Level Progression

**Goal:** introduce `LevelManager.gd` so that clearing a level's full set of waves advances the player to a new, harder level — closing the loop between `WaveManager`'s per-wave structure (Phase 3) and the multi-level progression described in the Spec.

**Source docs:** Build Plan §Phase 5, Spec §2 (level structure, category sequence per level), §5 (Stage B — expanded difficulty), §6 (HUD level display), Tech Stack §4 (`LevelManager.gd`), §8 (LevelManager testing strategy).

---

## 1. Requirements

### Functional Requirements
- FR5.1 — `LevelManager.gd` exists and tracks the current level number, starting at Level 1.
- FR5.2 — When all waves in the current level's category sequence are cleared (i.e., `WaveManager` finishes its last category's wave), `LevelManager` is notified, shows the `level_complete_banner.png` transition, and advances to the next level.
- FR5.3 — `LevelManager` computes a difficulty parameter that increases as levels increase and passes it to `QuestionGenerator` (via `WaveManager`) for every question generated at that level, per Spec §5's Stage A → Stage B progression (larger operand ranges at higher levels, same four categories).
- FR5.4 — The HUD displays the current **Level** number alongside score, health, and lives, per Spec §6.
- FR5.5 — At the start of a new level, `LevelManager` provides `WaveManager` with the level's category sequence and tells it to spawn the **first** wave's full set of 10 enemies (Addition), rather than continuing from wherever the previous level left off.
- FR5.6 — The category sequence's **content** (Addition → Subtraction → Multiplication → Division) is unchanged level-to-level in this phase — only the difficulty parameter changes. However, `WaveManager` now accepts this sequence as an externally-provided value from `LevelManager` rather than only using its own Phase 3 hardcoded default — this is the ownership handoff Phase 7 depends on to later extend the sequence with new categories, without a further architecture change at that point.

### Non-Functional Requirements
- NFR5.1 — The difficulty formula (level → operand-range/parameter mapping) must be a pure, deterministic function that's testable in isolation, without requiring `WaveManager`'s scene tree.
- NFR5.2 — `LevelManager` and `WaveManager` must coordinate so that "level complete" fires **exactly once** per level clear — no double-advancement from a race between wave-clear and level-clear signals, and no silent failure to advance.
- NFR5.3 — `WaveManager`'s Phase 3 default `category_sequence` (`["addition","subtraction","multiplication","division"]`) remains its fallback when no external sequence is provided, so Phase 3's existing `test_wave_manager.gd` category-sequencing assertions continue to pass unmodified — this phase extends `WaveManager`'s API, it does not change its default behavior.

### Out of Scope
- New question categories beyond the existing four (Stage C content is Phase 7).
- High score persistence and "New High Score!" messaging (Phase 6).

---

## 2. Detailed Implementation Plan

1. **Define the difficulty formula**: pick a simple, documented mapping from `current_level` to a `difficulty` value consumed by `QuestionGenerator.generate_question(category, difficulty)` (e.g., `difficulty = current_level`, or a small lookup table mapping level ranges to Stage A/Stage B operand-size tiers per Spec §5). Document the chosen formula directly in `LevelManager.gd`'s code comments so it's unambiguous for future phases (mirrors the documentation discipline established in Phase 4 for the health-loss trigger).
2. **Finish the Phase 3 hook point**: extend `WaveManager.on_wave_clear()` so that when the just-cleared wave was the **last** category in `category_sequence`, it emits an `all_waves_complete` signal (instead of only handling the "spawn next category" case) — this is the level-clear hook that Phase 3's Tech Stack notes left for this phase.
3. **`LevelManager.gd`** (scene-owned manager, coordinating with `WaveManager` the same way `WaveManager` coordinates with `enemy` instances — not an autoload):
   - State: `current_level: int = 1`.
   - Connects to `WaveManager`'s `all_waves_complete` signal.
   - `on_all_waves_complete()`: shows `level_complete_banner.png` briefly, increments `current_level`, computes the new `difficulty` via the Step 1 formula, and calls `start_level()`.
   - `start_level()`: builds the level's `category_sequence` array (in this phase, always the static 4-category list from Phase 3) and passes it to `WaveManager` — e.g., `WaveManager.set_category_sequence(sequence)` — before calling `WaveManager.start_wave("addition")` (or equivalent) with the new difficulty value, producing a fresh set of 10 enemies for the first wave of the new level. `WaveManager` retains its Phase 3 hardcoded default for standalone/test use when no sequence is provided (NFR5.3).
   - Emits a `level_changed` signal so the HUD can update.
4. **Wire difficulty through to `QuestionGenerator`**: `WaveManager.start_wave()` now accepts and forwards the current `difficulty` value from `LevelManager` into each `QuestionGenerator.generate_question(category, difficulty)` call, rather than a hardcoded Stage A constant.
5. **HUD level display**: `hud.gd` listens for `level_changed` and updates a `LevelLabel`, per Spec §6.
6. **`level_complete_banner.png`**: instance as a brief overlay, following the same pattern as `wave_complete_banner.png` from Phase 3.
7. **Write GUT tests** for `LevelManager` (see Testing Plan), using GUT doubles/stubs for `WaveManager` so the tests don't require the real wave/enemy scene tree.

---

## 3. Testing Plan

### Automated Tests (GUT)

**`test_level_manager.gd`**
- Difficulty increases correctly across levels according to the defined formula (e.g., Level 1 → Stage A operand ranges, a later level → Stage B ranges), asserted directly against the formula's output.
- `on_all_waves_complete()` increments `current_level` by exactly 1 per call — no skipped or double-incremented levels.
- The `level_changed` signal fires exactly once per level advance.
- At a new level's start, the category sequence handed to (a stubbed) `WaveManager` restarts at "addition" — asserted via a GUT double standing in for `WaveManager`, not the real wave/enemy scene tree.
- `all_waves_complete` triggers a level advance only when it actually fires (no premature advancement from individual `wave_clear` events) — asserted by stubbing `WaveManager` and confirming ordinary per-wave clears do not increment `current_level`.
- `start_level()` calls the stubbed `WaveManager`'s sequence-setting method with the expected 4-category array before calling `start_wave("addition")` — confirming `LevelManager` actively provides the sequence rather than relying on `WaveManager`'s internal default.

### Manual Test Checklist
| # | Scenario | Expected Result |
|---|---|---|
| 1 | Clear all four waves of Level 1 | `level_complete_banner.png` shows briefly; Level 2 begins with a fresh Addition wave of 10 enemies |
| 2 | Compare Level 1 vs. Level 2 questions in the same category | Level 2's operand ranges are visibly larger/harder, per the defined difficulty formula |
| 3 | Watch the HUD across a level transition | Level number updates correctly and stays in sync with the true current level |
| 4 | Play through several levels in sequence | Category sequence per level is always Addition → Subtraction → Multiplication → Division; only difficulty changes |
| 5 | Run full GUT suite | `test_level_manager.gd` passes, 0 failures, alongside all prior phases' passing tests (no regressions) |

**Definition of Done:** a player can clear a full level's four waves, see the level-complete transition, and continue into a new level with visibly increased difficulty and a correctly updated HUD level display — with `LevelManager`'s difficulty-scaling and level-advancement logic covered by passing GUT tests.
