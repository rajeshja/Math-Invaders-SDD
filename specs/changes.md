# Math Invaders — Requirements Change Log

## Purpose

This file records the migration required for the existing implementation through Phase 3. It is intentionally not the only source of truth: the Specification, Technology Stack, Build Plan, and phase documents contain the normative requirements. Delete this file after the code migration is complete.

## Latest Gameplay Contract

The previous change request removed enemy descent and replaced it with lives. This revision adds configurable attempts per question and explicit wrong-answer feedback. A later revision adds the per-level time limit, enemy return fire on wrong answers, and a fixed 0.3-second bullet travel time (see "Level Timer Revision" below). The latest revision makes bullet flight purely presentational --- question changes resolve in parallel with the bullet launching --- replaces the 2×5 grid with a 4-3-2-1 inverted-triangle formation, and splits Phase 4 into two phases (see "Parallel Resolution & Triangle Formation Revision" below).

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

## Level Timer Revision (now its own Phase 5)

This revision was originally folded into Phase 4; after the phase split (see
the final revision below) it is Phase 5 in its own right and ripples into
Phases 6, 7, 9, and 11.

### Global settings

- `gameplay/seconds_per_wave` — float, default `30`, minimum `1`. Seconds granted per wave when computing a level's default time limit.
- `gameplay/level_time_limit_by_level` — Dictionary, default `{}`. A valid positive-seconds entry for a level replaces the computed limit for that level only.

Both are read through `GameConfig.gd` (`get_seconds_per_wave()`,
`get_level_time_limit(level, wave_count)`); no raw Project Settings reads in
gameplay code.

### Level timer contract

1. A level's effective time limit = valid per-level override, otherwise `wave_count × seconds_per_wave`. With the four-wave level, that is **120 seconds for Level 1**.
2. The timer starts at level start and decrements only while the game state is `PLAYING`; pausing freezes it.
3. Wave transitions never reset or pause the timer; the whole level must be cleared within one continuous budget.
4. Wrong answers do not consume time; correct answers do not add time.
5. Reaching zero fails the level: `GAME_OVER` + `game_over` exactly once with reason `TIME_EXPIRED`; the Game Over screen shows "Time's up!" and answer input is disabled. There is no retry-the-level path; Play Again restarts at Level 1 with a fresh budget.
6. Answer resolution precedes expiry processing each frame, so clearing the final enemy as time hits zero still counts as a clear.
7. The HUD shows a live countdown matching `GameManager.time_remaining`.
8. `GameManager` owns `time_remaining`/`level_time_limit`/`last_game_over_reason` (`NONE`/`LIVES_DEPLETED`/`TIME_EXPIRED`) and is advanced via a deterministic `tick(delta)` so GUT tests need no scene tree or wall clock.
9. Each new level resolves its own limit at the boundary (Phase 6); Play Again re-resolves for Level 1 (Phase 7).

### Enemy return fire contract

1. Every wrong answer makes the active enemy play a brief fire telegraph (~0.1 s) and shoot one `enemy_bullet.png` projectile at the player ship, ending in a short player-hit flash.
2. Purely presentational: exactly one life is still consumed by the authoritative damage path; the red flash and attempt rules are unchanged.
3. No Area2D/collision-based damage may be introduced; bullets are tweens with scripted arrival callbacks.
4. The animation never blocks input gating, question advancement, or Game Over; if the wrong answer ends the game, Game Over UI takes precedence.

### Bullet travel time contract

All bullets --- player bullets on correct answers and enemy bullets on wrong
answers --- take **exactly 0.3 seconds** from source to target in every
case, regardless of distance, implemented as a fixed-duration tween sharing
one constant (`bullet.gd` `TRAVEL_TIME`). This replaces the previous slow,
distance-dependent player-bullet travel.

### Phase-by-phase impact

- **Phase 4**: implements the enemy-return-fire and 0.3 s travel contracts plus Game Over reason display for life depletion; extended `test_game_manager.gd`/`test_game_config.gd`.
- **Phase 5**: implements the timer contract itself (countdown HUD, deterministic tick, `TIME_EXPIRED`) plus the config resolution tests.
- **Phase 6**: each level start resolves its time limit via `GameConfig.get_level_time_limit(level, wave_count)` and calls `GameManager.start_level_timer()` exactly once; wave transitions never reset it; per-level overrides change only that level's budget.
- **Phase 7**: Play Again restarts the Level 1 timer via the same resolution path; a timeout ending the prior session carries no penalty.
- **Phase 9**: adds enemy-return-fire/player-hit sounds and a presentational low-time warning (pulsing red timer + optional tick during the final 10 seconds).
- **Phase 11**: the level time budget becomes an explicit tuning dimension via `seconds_per_wave` and `level_time_limit_by_level`.

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

### Phase 4 — Lives, Wrong-Answer Feedback & Game Over

- Kept the lives-only model; no health.
- Made the wrong-answer event explicitly one-life-per-attempt.
- Added red feedback before question-flow advancement.
- Defined Game Over precedence over loading the next question.
- Added tests for zero lives, multi-attempt questions, and exactly-once life consumption.

### Phase 5 — Level Timer

Split out of the old Phase 4 (which was too heavy as one playable increment).
Owns the per-level time limit: configuration resolution, deterministic
ticking, countdown HUD, and the `TIME_EXPIRED` game over path.

### Phase 6 — Level Progression

- Level completion still resets lives to `starting_lives`.
- Added per-level question-attempt overrides.
- The effective attempt count is resolved once per level and applied consistently to its questions.

### Phase 7 — Score & High Score Persistence

- Session restart also resets the question-attempt rule by restarting at Level 1.
- High score behavior remains unchanged.

### Phase 8 — New Question Categories

New categories inherit the same attempt configuration and wrong-answer feedback. `WaveManager` must not special-case attempts by category.

### Phase 9 — Effects, Animation & Audio Polish

Red wrong-answer feedback is promoted to a required presentation behavior. The red flash is immediate and brief; optional screen-shake/secondary damage feedback must not replace it.

### Phase 10 — Mobile Export & Touch

Verified that the red feedback is visible and touch-safe on-device and that the same attempt configuration behaves identically on desktop and mobile.

### Phase 11 — Playtesting & Balancing

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

## Level Timer Revision Checklist

- [ ] Add `gameplay/seconds_per_wave` with default `30`.
- [ ] Add `gameplay/level_time_limit_by_level` with default `{}`.
- [ ] Expose `get_seconds_per_wave()` / `get_level_time_limit(level, wave_count)` through `GameConfig.gd`.
- [ ] Add `time_remaining`, `level_time_limit`, `last_game_over_reason`, `start_level_timer()`, and deterministic `tick(delta)` to `GameManager`.
- [ ] Emit `time_changed`; drive ticks from `Main._process` while `PLAYING` only.
- [ ] Fail the level via Game Over (reason `TIME_EXPIRED`) exactly once at zero; show "Time's up!".
- [ ] Add HUD countdown bound to `time_changed`.
- [ ] Refactor all bullet travel to a shared fixed 0.3-second tween.
- [ ] Add `enemy_bullet.png` + `enemy_bullet.tscn`; wire active-enemy return fire into the wrong-answer event path (presentational only).
- [ ] Restart the timer at each level boundary (Phase 6) and on Play Again (Phase 7).
- [ ] Extend GUT coverage for timer tick/expiry/pause/reset, config resolution, and overrides.

## Parallel Resolution & Triangle Formation Revision (Phase Split)

Three changes to the requirements and the existing Phase-3-era code:

### 1. Parallel answer resolution

Bullet flight is strictly cosmetic in both directions; it must never take
away from the time available to answer questions.

- **Correct answer:** score, destruction of the active enemy, and loading
  the next question all resolve in the same frame the player bullet
  launches. Nothing subscribes gameplay logic to bullet arrival.
- **Wrong answer:** red flash starts non-blocking; life loss, attempt
  counting, and any Game Over resolve immediately. Only the next
  question's *display* may wait out the ~0.18 s red-flash interval
  (`QuestionPanel.wait_wrong_feedback()`); it never waits for the enemy
  bullet's telegraph, launch, or arrival.
- Normative home: Spec §10 "Parallel answer resolution"; Phase 4 FR4.13;
  Phase 2 FR2.5 / Phase 3 FR3.4 updated accordingly.
- Code: `Main.gd` resolves answers synchronously; `bullet.gd`'s `arrived`
  signal is presentation-only.

### 2. Inverted-triangle formation

The 2×5 grid is replaced by an inverted triangle: rows of **4 - 3 - 2 - 1**
enemies from top to bottom (summing to the default 10-enemy wave), each row
centered on the screen's horizontal axis (`WaveManager.FORMATION_ROW_COUNTS`,
`FORMATION_CENTER_X`). The single bottom tip is targeted first under the
existing lowest-Y/lowest-X active-enemy rule. Indices beyond 10 (custom
`enemies_per_wave`) overflow into a continuation of the last row.

### 3. Phase 4 split

The old Phase 4 (lives + level timer + game over) was too heavy for one
playable increment and is now:

- **Phase 4 — Lives, Wrong-Answer Feedback & Game Over**: playable
  end-to-end with lives, enemy return fire, fixed 0.3 s bullet travel,
  parallel resolution, and life-depletion Game Over.
- **Phase 5 — Level Timer**: the per-level countdown layered onto that
  working game, with its own `TIME_EXPIRED` game over path.

All later phases shift by one: Level Progression → 6, Score & High Score → 7,
New Categories → 8, Effects/Audio → 9, Mobile Export → 10, Playtesting &
Balancing → 11, Stretch → 12.

## Parallel Resolution & Triangle Checklist

- [x] `Main.gd`: correct-answer path resolves score/destruction/next question at bullet launch (no gameplay await on travel).
- [x] `Main.gd`: wrong-answer path consumes life/attempts immediately; awaits only `QuestionPanel.wait_wrong_feedback()`.
- [x] `QuestionPanel.flash_wrong_answer` is fire-and-forget with self-restoring styleboxes.
- [x] `WaveManager._formation_position` lays out 4-3-2-1 centered rows.
- [x] GUT coverage: inverted-triangle formation test added to `test_wave_manager.gd`.
- [ ] When Phase 4 lands: enemy return fire hooks the existing `wrong_answer` event non-blockingly; fixed 0.3 s tween replaces velocity-based `bullet.gd` movement.
