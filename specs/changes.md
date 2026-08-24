# Math Invaders — Requirements Change Log

## Purpose

This file records the migration required for the existing implementation through Phase 3. It is intentionally not the only source of truth: the Specification, Technology Stack, Build Plan, and phase documents contain the normative requirements. Delete this file after the code migration is complete.

## Latest Gameplay Contract

The previous change request removed enemy descent and replaced it with lives. This revision adds configurable attempts per question and explicit wrong-answer feedback.

### Global settings

- `gameplay/starting_lives` — integer, default `3`, minimum `1`.
- `gameplay/enemies_per_wave` — integer, default `10`, minimum `1`.
- `gameplay/tries_per_question` — integer, default `1`, minimum `1`.
- `gameplay/tries_per_question_by_level` — Dictionary, default `{}`. A valid positive-integer value for a level overrides the global attempt count for that level.

All reads go through `GameConfig.gd`; do not scatter raw `ProjectSettings.get_setting()` calls through gameplay code.

## Wrong-Answer Contract

1. The player can attempt the currently displayed question up to the effective `tries_per_question` count.
2. Every wrong answer consumes exactly **one life**.
3. The tapped answer button immediately **flashes red** as feedback.
4. With the default `tries_per_question = 1`, the wrong answer retires the current question and the **next question is shown** after the brief red feedback.
5. If a level override allows more than one attempt, the same question remains active until its configured attempt count is exhausted. Each wrong attempt still costs one life and flashes red.
6. A correct answer destroys the active enemy and advances to the next question as before.
7. Wrong answers never move the active enemy or the formation.
8. If a wrong answer reduces lives to zero, Game Over takes precedence: no next question is loaded and answer input is disabled.
9. Completing a level resets lives to the configured `starting_lives` value. It does not reset lives between waves.
10. `Play Again` resets lives and the effective attempt rule by restarting at Level 1, but does not reset the persisted high score.
11. There is no health pool or bottom-of-screen damage path.

### Default example

With `starting_lives = 3` and `tries_per_question = 1`:

- Question A → wrong → red flash → 2 lives → Question B.
- Question B → wrong → red flash → 1 life → Question C.
- Question C → wrong → red flash → 0 lives → Game Over.

With `tries_per_question_by_level = { 3: 2 }`, Level 3 permits two attempts on each question before that question advances, but each wrong attempt still costs one life.

## Required Code Changes for Existing Phase-3 Code

### 1. Remove wrong-answer descent

Delete/disable all Phase-2/3 logic that moves an enemy or formation after an incorrect answer. No movement may occur after a wrong answer, regardless of how many wrong answers have occurred.

### 2. Implement attempt-aware answer handling

Track attempts used for the current question. Reset the counter only when a new question is generated. The flow is:

```text
correct
  → destroy active enemy
  → score
  → reset question attempt counter
  → next question

incorrect
  → flash tapped button red
  → consume exactly one life
  → increment question attempt counter
  → if lives == 0: Game Over, stop
  → else if attempt limit reached: next question
  → else: keep same question active
```

The default limit is one, so the normal path is `incorrect → red flash → life lost → next question`.

### 3. Make red feedback immediate and single-shot

The `QuestionPanel`/answer-button layer should provide a short red flash on the exact button tapped. The feedback must not generate a second answer event or second life loss. Disable or gate input during the brief feedback interval if necessary.

### 4. Add configuration access

Create/extend `GameConfig.gd` with:

- `get_starting_lives() -> int`
- `get_enemies_per_wave() -> int`
- `get_tries_per_question(level: int) -> int`

`get_tries_per_question()` first checks `gameplay/tries_per_question_by_level` for a valid override for the supplied level, then falls back to `gameplay/tries_per_question`.

### 5. Lives remain authoritative in GameManager

`GameManager` owns `lives`, `starting_lives`, and `game_state`. There is no `health` state. A wrong-answer event calls the one-life loss path exactly once. The last life triggers `game_over` exactly once and prevents further input.

### 6. Preserve wave/level structure

The 10-enemy wave, active-enemy ordering, category sequence, correct-answer destruction, and wave/level completion logic remain unchanged except that wrong answers no longer move enemies.

### 7. Level-specific attempt override

At level start, `LevelManager` resolves the effective attempt count through `GameConfig`. Every question in that level uses that resolved value. A level transition resets lives to `starting_lives` and loads the new level's attempt rule.

## Phase-by-Phase Changes

### Phase 0 — Project Setup

Added the two question-attempt Project Settings and required `GameConfig.gd` access path. Added configuration verification to the setup checklist.

### Phase 1 — Minimum Playable Loop

Clarified that Phase 1's temporary wrong-answer no-op is not the later gameplay contract. The final contract begins in Phase 2: wrong answers cost lives, flash red, and follow the configured attempt rule.

### Phase 2 — Question Strategy & Bullets

- Removed enemy descent as the wrong-answer consequence.
- Added immediate red feedback on the selected wrong answer button.
- Added attempt counting per question.
- Default one attempt retires the question and loads the next question.
- Higher attempt settings keep the same question active until the attempt limit is reached.
- Every wrong attempt costs one life.
- Added tests for default and multi-attempt behavior.

### Phase 3 — Wave Structure

- Removed formation movement from wrong-answer handling.
- Preserved active-enemy selection and wave sequencing.
- Added integration of the effective attempt count into question flow.
- Added tests proving wrong answers do not change enemy positions and that the default one-attempt path advances to a new question after red feedback.

### Phase 4 — Lives & Game Over

- Kept the lives-only model; no health.
- Made the wrong-answer event explicitly one-life-per-attempt.
- Added red feedback before question-flow advancement.
- Defined Game Over precedence over loading the next question.
- Added tests for zero lives, multi-attempt questions, and exactly-once life consumption.

### Phase 5 — Level Progression

- Level completion still resets lives to `starting_lives`.
- Added per-level question-attempt overrides.
- The effective attempt count is resolved once per level and applied consistently to its questions.

### Phase 6 — Score & High Score Persistence

- Session restart also resets the question-attempt rule by restarting at Level 1.
- High score behavior remains unchanged.

### Phase 7 — New Question Categories

New categories inherit the same attempt configuration and wrong-answer feedback. `WaveManager` must not special-case attempts by category.

### Phase 8 — Effects, Animation & Audio Polish

Red wrong-answer feedback is promoted to a required presentation behavior. The red flash is immediate and brief; optional screen-shake/secondary damage feedback must not replace it.

### Phase 9 — Mobile Export & Touch

Verified that the red feedback is visible and touch-safe on-device and that the same attempt configuration behaves identically on desktop and mobile.

### Phase 10 — Playtesting & Balancing

Added question-attempt count and red-feedback clarity to the balancing dimensions. Enemy descent speed is no longer a gameplay tuning dimension because descent is removed.

## Migration Checklist

- [ ] Add `gameplay/tries_per_question` with default `1`.
- [ ] Add `gameplay/tries_per_question_by_level` with default `{}`.
- [ ] Route both through `GameConfig.gd`.
- [ ] Remove all wrong-answer enemy/formation movement.
- [ ] Add per-question attempt counter.
- [ ] On wrong answer, flash the tapped button red.
- [ ] Consume exactly one life per wrong attempt.
- [ ] With one allowed attempt, load the next question after the red feedback.
- [ ] With multiple allowed attempts, retain the same question until the attempt limit is reached.
- [ ] Do not load another question after Game Over.
- [ ] Reset lives at level completion, not wave completion.
- [ ] Resolve per-level attempt override at level start.
- [ ] Preserve correct-answer bullet/destruction behavior.
- [ ] Update GUT tests for default and overridden attempt counts.
- [ ] Run the full GUT suite before deleting this file.
