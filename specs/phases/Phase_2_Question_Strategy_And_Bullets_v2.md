# Phase 2 — Question Strategy Pattern & Bullets

**Goal:** replace the hardcoded question with procedurally generated addition/subtraction questions via the Strategy Pattern, add real bullet visuals on correct answers, and give wrong answers a visible consequence (enemy descent). First phase with real GUT unit tests.

**Source docs:** Build Plan §Phase 2, Tech Stack §3 (Strategy Pattern architecture in full), §7 (bullet sprite wiring, enemy texture-swap), §8 (testing strategy for strategies/generator), Spec §5 (Stage A content rules, distractor rules), §7 (`player_bullet.png`, enemy sprite table).

---

## 1. Requirements

### Functional Requirements
- FR2.1 — `question_strategy.gd` exists as a base class defining the contract: `generate(difficulty: int) -> Dictionary` returning `{ question_text, correct_answer, choices: [] }` (Tech Stack §3).
- FR2.2 — `addition_strategy.gd` and `subtraction_strategy.gd` exist under `scripts/questions/strategies/`, each extending `question_strategy.gd` and implementing `generate(difficulty)` per Spec §5 Stage A rules: 1–2 digit operands, 4 choices (1 correct + 3 plausible, non-duplicate distractors).
- FR2.3 — `question_generator.gd` exists as the dispatcher: holds a category-name → strategy-instance map, exposes `generate_question(category: String, difficulty: int) -> Dictionary`, and is the **only** class `Main`/gameplay code talks to for questions.
- FR2.4 — `Main.gd` (or equivalent) calls `QuestionGenerator.generate_question("addition", difficulty)` (or `"subtraction"`) instead of using a hardcoded literal. **Until `LevelManager.gd` is introduced in Phase 5, `difficulty` is a hardcoded default of `1` owned by the Phase 2 caller (`Main.gd` or equivalent).**
- FR2.5 — On a correct answer, a real `player_bullet.png` sprite instance visibly travels from the player position to the active enemy's position before the enemy is destroyed (replacing Phase 1's instant disappear).
- FR2.6 — On a wrong answer, the enemy is no longer a no-op: it survives and begins the Phase 2 descent behavior. **For the single-enemy implementation, this means the enemy moves downward by a simple, tunable constant movement rule. Phase 3 promotes this to whole-formation movement on each wrong answer.**
- FR2.7 — The enemy's `Sprite2D` texture is set **per-instance** at spawn/category-switch time — `enemy_ship_addition.png` vs. `enemy_ship_subtraction.png` — confirming the single-scene, texture-swap approach from Tech Stack §7, rather than separate enemy scenes per category.
- FR2.8 — The player can experience both categories in the same session (e.g., toggle or sequential for manual testing purposes — full wave sequencing is Phase 3, so a simple manual/dev-triggered category switch is sufficient here).

### Non-Functional Requirements
- NFR2.1 — Strategies must have **no dependency on the scene tree** — `generate(difficulty)` is pure logic, callable and testable in isolation (Tech Stack §8).
- NFR2.2 — Adding a new category strategy later must require no changes to `addition_strategy.gd`/`subtraction_strategy.gd` or to code that calls `question_generator.gd` — only a new file + one registration line.
- NFR2.3 — Distractor generation must never produce duplicate values or a duplicate of the correct answer (Spec §5).

### Out of Scope
- Multiplication/division strategies (Phase 3).
- Wave/formation logic, 10-enemy spawns (Phase 3).
- Health/lives consequences of the enemy reaching the bottom (Phase 4) — for this phase, constant descent is purely visual/tunable, without a defined "reached bottom" penalty yet.

---

## 2. Detailed Implementation Plan

1. **`question_strategy.gd`**: define as a `class_name QuestionStrategy extends RefCounted` (or `Node`, per team preference) with a virtual `generate(difficulty: int) -> Dictionary` that either raises `push_error` if unimplemented or is left as a documented contract for subclasses to override. Optionally add shared distractor-building helpers here or in a small `distractor_utils.gd` (Tech Stack §3).
2. **`addition_strategy.gd`**:
   - `generate(difficulty)`: pick two operands sized by `difficulty` (Stage A: 1–2 digit), compute `correct_answer = a + b`.
   - Build 3 distractors using plausible-mistake patterns (off-by-one, transposed digits, wrong-operation result), ensuring no duplicates among distractors or against the correct answer.
   - Shuffle the 4 choices before returning; return `{ question_text: "What is %d + %d?" % [a, b], correct_answer: a+b, choices: [...] }`.
3. **`subtraction_strategy.gd`**: mirror addition's structure; guard against negative results if that's undesired for the target age group (e.g., ensure `a >= b` for Stage A).
4. **`question_generator.gd`**:
   - Internal dictionary: `{"addition": AdditionStrategy.new(), "subtraction": SubtractionStrategy.new()}`.
   - `generate_question(category, difficulty)`: looks up the strategy; if found, delegates and returns its result; if not found, fail gracefully (e.g., `push_error` + return a safe empty/default `Dictionary` rather than crashing) — this graceful-failure path is explicitly unit-tested.
5. **Wire `Main.gd`** to call `QuestionGenerator.generate_question(current_category, difficulty)` after each correct answer (and at game start) instead of the Phase 1 hardcoded string, populating `QuestionLabel` and the 4 buttons from the returned `Dictionary`.
6. **Bullet visuals**: create `bullet.tscn`/`bullet.gd` using `player_bullet.png`; on correct answer, instance a bullet at the player's position, tween/move it toward the active enemy's position, and only on arrival (or after a short fixed travel time) destroy the enemy and apply score — replacing the instant Phase 1 removal.
7. **Wrong-answer descent**: give `enemy.gd` a simple `_process`/`_physics_process` downward movement, active once a wrong answer has been registered against it (or continuously at a slow rate — confirm intended feel against Spec §4 step 5; exact formation-wide advance is refined in Phase 3).
8. **Texture swap**: in `enemy.tscn`'s spawn/setup code (called from `Main.gd` for now, pending `WaveManager` in Phase 3), set the `Sprite2D.texture` based on the active category string (`"addition"` → `enemy_ship_addition.png`, `"subtraction"` → `enemy_ship_subtraction.png`).
9. **Write GUT tests** (see Testing Plan) alongside each script as it's built, not after.

---

## 3. Testing Plan

This is the first phase with real GUT coverage, per Tech Stack §8. Tests live under `test/unit/questions/`, mirroring `scripts/questions/`.

### Automated Tests (GUT)

**`test_addition_strategy.gd`**
- `generate(difficulty)` returns a `correct_answer` equal to the actual sum of the operands used.
- Returned `choices` contains exactly one value equal to `correct_answer`.
- `choices` has exactly 4 entries, all unique (no duplicate distractors, no distractor equal to the correct answer).
- Operand size scales sensibly with `difficulty` (e.g., higher difficulty allows/produces larger operands than lower difficulty, per Stage A/B ranges).

**`test_subtraction_strategy.gd`**
- Same shape as addition: correct result verified, exactly one correct choice among 4 unique choices, no negative-result questions (if that's the chosen rule), difficulty scaling sanity.

**`test_question_generator.gd`**
- `generate_question("addition", difficulty)` dispatches to `AdditionStrategy` and returns a well-formed `Dictionary` (has `question_text`, `correct_answer`, `choices`).
- `generate_question("subtraction", difficulty)` dispatches correctly.
- `generate_question("not_a_real_category", difficulty)` handles the unknown category gracefully — no crash/uncaught error, and either returns a defined "empty"/error result or emits a clear, catchable error signal (exact contract confirmed with the team, but the test asserts *some* safe defined behavior).

### Manual Test Checklist
| # | Scenario | Expected Result |
|---|---|---|
| 1 | Play an addition question, answer correctly | Bullet sprite visibly travels from player to enemy; enemy destroyed after travel; score +1 |
| 2 | Play an addition question, answer incorrectly | Enemy is unaffected instantly, then begins visible downward movement; question remains |
| 3 | Switch to a subtraction question (dev-triggered) | Enemy sprite swaps to `enemy_ship_subtraction.png`; question text/choices are subtraction-appropriate |
| 4 | Answer several questions in a row | No duplicate-looking answer choices ever appear; correct answer position varies (not always the same button slot) |
| 5 | Run full GUT suite | `test_addition_strategy`, `test_subtraction_strategy`, `test_question_generator` all pass, 0 failures |

**Definition of Done:** questions are procedurally generated (not hardcoded) for addition and subtraction, correct answers produce visible bullet-travel-then-destroy feedback, wrong answers produce visible enemy descent, enemy art correctly reflects the active category, and all three new GUT test files pass under both the editor GUT panel and CLI.
