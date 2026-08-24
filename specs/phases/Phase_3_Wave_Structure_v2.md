# Phase 3 — Wave Structure (10 Enemies Visible per Screen)

**Goal:** introduce `WaveManager.gd`, the full 10-enemy formation, all four Stage A categories, and category sequencing across waves — the structural core of the game's progression loop.

**Source docs:** Build Plan §Phase 3, Spec §2 (wave & level structure), §4 (core loop steps 1, 4, 8), Tech Stack §4 (`WaveManager.gd` in full), §8 (WaveManager testing strategy).

---

## 1. Requirements

### Functional Requirements
- FR3.1 — `WaveManager.gd` exists and owns the full lifecycle of a wave per Tech Stack §4: wave start (spawn 10), active-enemy tracking, on-correct-answer removal, on-wave-clear transition.
- FR3.2 — **Wave start** instantiates all **10 `enemy.tscn` instances at once**, arranged in a formation (e.g., grid), each using the real sprite for the wave's category — not spawned one at a time.
- FR3.3 — Exactly one enemy at a time is "active" (linked to the currently displayed question). The active enemy is the **lowest/frontmost remaining enemy by Y position**; ties are broken by **lowest X position (left-to-right)**. This ordering is deterministic and is re-evaluated whenever the remaining formation changes (including after an enemy is removed or the formation is reset).
- FR3.4 — On a correct answer, the active enemy is destroyed/removed (bullet-travel feedback from Phase 2 preserved), the visible formation shrinks by one, and the question panel advances to the next active enemy's question.
- FR3.5 — `multiplication_strategy.gd` and `division_strategy.gd` are added under `scripts/questions/strategies/`, registered in `question_generator.gd`, with **no changes** to `addition_strategy.gd`/`subtraction_strategy.gd`/existing call sites (Tech Stack §3, "Why this pattern").
- FR3.6 — Matching `enemy_ship_multiplication.png`/`enemy_ship_division.png` sprites are wired via the same per-instance texture-swap approach as Phase 2.
- FR3.7 — Wave sequencing is wired: **Addition (10) → Subtraction (10) → Multiplication (10) → Division (10)**, matching Spec §2's Level 1 example.
- FR3.8 — When a wave's 10 enemies are all cleared, a **fresh set of 10** spawns for the next category in sequence — not a continuation/reuse of prior enemy instances.
- FR3.9 — `wave_complete_banner.png` displays as a brief transition between waves.
- FR3.10 — HUD shows enemies remaining in the current wave (e.g., "6/10 remaining"), always matching the true on-screen formation count.
- FR3.11 — On an incorrect answer, **the whole remaining formation advances downward by one movement step together**; the active enemy does not descend independently of the formation. The movement step and speed are tunable, but the scope of movement is fixed for this phase. This movement is not itself a health-loss event; Phase 4 owns the health-loss trigger when the formation reaches the defined danger/bottom boundary.

### Non-Functional Requirements
- NFR3.1 — `division_strategy.gd` must guarantee whole-number results by picking divisor/quotient first and deriving the dividend (Tech Stack §3), never producing a non-integer expected answer.
- NFR3.2 — `WaveManager` must be testable without depending on real enemy scenes — GUT doubles/stubs stand in for enemy instances in unit tests (Tech Stack §8).
- NFR3.3 — The "active enemy" concept must be well-defined and deterministic: lowest/frontmost remaining enemy by Y, then lowest X as the tie-breaker. Re-evaluate the ordering when the remaining formation changes; do not rely on incidental scene-tree order.
- NFR3.4 — Wrong-answer movement is formation-level, not per-enemy: all remaining enemies receive the same downward movement step so their relative ordering is preserved.

### Out of Scope
- Health/lives consequences of enemies reaching the bottom, and Game Over (Phase 4).
- Level progression beyond one level's four waves, difficulty scaling across levels (Phase 5).

---

## 2. Detailed Implementation Plan

1. **`multiplication_strategy.gd` / `division_strategy.gd`**: implement following the `addition`/`subtraction` pattern from Phase 2.
   - Multiplication: pick operands sized by `difficulty` (Stage A: small factors), compute product, generate distractors (e.g., off-by-one-factor, addition-instead-of-multiplication mistakes).
   - Division: pick a **divisor and quotient first**, derive `dividend = divisor * quotient`, so the question always resolves to a whole number; generate plausible wrong-operation/off-by-one distractors.
   - Register both in `question_generator.gd`'s category map — confirm no existing strategy files or call sites need edits (this validates the pattern's extensibility, per Tech Stack §3).
2. **`WaveManager.gd`** (scene-owned manager; it is **not an autoload**):
   - State: `current_category: String`, `category_sequence: Array = ["addition","subtraction","multiplication","division"]`, `enemies_remaining: int`, reference to the `Enemies` container node.
   - `start_wave(category: String)`: clears any leftover enemies, instantiates 10 `enemy.tscn` into a formation layout under `GameWorld/Enemies`, sets each enemy's sprite texture for `category`, generates a question per enemy (up front, or just-in-time for the active one — either is valid per Tech Stack §4), sets `enemies_remaining = 10`.
   - `get_active_enemy()`: returns the current target (e.g., frontmost/lowest by position) and exposes its linked question to `QuestionPanel`.
   - `on_correct_answer()`: destroys the active enemy, decrements `enemies_remaining`, updates HUD wave-progress signal, and if `enemies_remaining == 0`, triggers wave-clear; otherwise advances to the next active enemy's question.
   - `on_wave_clear()`: shows `wave_complete_banner.png` briefly, advances `current_category` to the next entry in `category_sequence` (or signals level-complete if the sequence is exhausted — hook point for Phase 5's `LevelManager`, not fully implemented yet), then calls `start_wave()` again with a **fresh** set of 10.
3. **Formation layout**: implement a simple grid/row arrangement function (e.g., 2 rows × 5 columns) positioning the 10 enemy instances within the play area bounds from Spec §3's layout.
4. **Wire `Main.gd`/game bootstrap** to own a `WaveManager` instance and call `start_wave("addition")` at game start instead of Phase 2's manual dev-triggered category switch.
5. **HUD wave-progress label**: connect to `WaveManager`'s remaining-count updates to render e.g. `"Subtraction 6/10 remaining"`, matching Spec §6.
6. **`wave_complete_banner.png`**: instance as a brief overlay (`Control`/`Sprite2D` with a timer or `AnimationPlayer` fade) shown between `on_wave_clear()` and the next `start_wave()` call.
7. **Write GUT tests** for the two new strategies and for `WaveManager` (see Testing Plan), using GUT's doubling/stubbing tools so `WaveManager` tests don't require the real `enemy.tscn`/scene tree.

---

## 3. Testing Plan

### Automated Tests (GUT)

**`test_multiplication_strategy.gd`** (mirrors Phase 2's strategy tests)
- Correct `correct_answer` equals actual product of operands used.
- Exactly one correct choice among 4 unique choices.
- Difficulty scaling sanity check.

**`test_division_strategy.gd`**
- `correct_answer` is always a whole number (never fractional) — explicitly assert the divisor/quotient-first construction holds (e.g., `dividend % divisor == 0`).
- Exactly one correct choice among 4 unique choices.
- Difficulty scaling sanity check.

**`test_wave_manager.gd`**
- **Wave-clear detection:** simulate 10 enemies down to 0 remaining (via GUT doubles standing in for enemy instances) and assert `on_wave_clear()`/equivalent signal fires exactly when `enemies_remaining` reaches 0, not before.
- **Category sequencing:** assert the sequence advances `addition → subtraction → multiplication → division` in the defined order, and does not skip or repeat a category out of order.
- **Wrong-answer movement:** with a stubbed formation, assert that one wrong answer moves every remaining enemy downward by the same configured step and does not move only the active enemy.
- **Active-enemy ordering:** assert that `get_active_enemy()` chooses the lowest Y enemy and, for equal Y, the lowest X enemy; after removing the active enemy, the next target is selected by the same rule.
- **Fresh spawn on wave clear:** assert that after a wave clears, the next `start_wave()` call produces a **new** set of 10 enemies (count resets to 10; stale references from the previous wave are not reused) — asserted via the stub/double count rather than real scene instantiation.
- Use GUT's doubling (`double()`/`partial_double()`) or stub tooling to avoid depending on `enemy.tscn`'s real scene tree, per Tech Stack §8.

### Manual Test Checklist
| # | Scenario | Expected Result |
|---|---|---|
| 1 | Start a fresh game | 10 addition-category enemies spawn together in a visible formation, all using `enemy_ship_addition.png` |
| 2 | Answer questions correctly one at a time | Formation visibly shrinks (10→9→8→...); HUD "remaining" count matches on-screen count at every step |
| 3 | Clear all 10 enemies in Wave 1 | `wave_complete_banner.png` shows briefly; a **fresh** set of 10 subtraction-category enemies spawns next |
| 4 | Progress through all four waves | Sequence is exactly Addition → Subtraction → Multiplication → Division, each with correct enemy art and 10-enemy formation |
| 5 | Answer incorrectly during a wave | All remaining enemies advance downward together by one movement step; their relative ordering is preserved and the next active enemy is selected deterministically |
| 6 | Answer a division question | Displayed answer always resolves to a whole number; distractors are plausible, no duplicates |
| 7 | Run full GUT suite | All strategy tests (4 categories) + `test_question_generator` + `test_wave_manager` pass, 0 failures |

**Definition of Done:** a full playthrough of one level's four waves is possible, each wave starting with a full 10-enemy correctly-skinned formation that visibly shrinks as questions are answered correctly, with accurate HUD wave-progress at every step, and all strategy + `WaveManager` GUT tests passing.
