# Phase 4 — Health, Lives, and Game Over

**Goal:** give wrong answers and descending enemies real consequences — health loss, life loss, and a Game Over screen — closing the full round-trip play session loop (start → play → lose → game over).

**Source docs:** Build Plan §Phase 4, Spec §4 (core loop steps 5–7, 10), §6 (HUD health/lives requirement), §7 (`heart_icon.png`, `life_icon.png`, `game_over_bg.png`), Tech Stack §5 (`GameManager.gd`), §8 (GameManager testing strategy).

---

## 1. Requirements

### Functional Requirements
- FR4.1 — `GameManager.gd` exists as the authoritative owner of overall game state (playing/paused/game-over), score, health, and lives (Tech Stack §5), orchestrating hand-offs to/from `WaveManager` at the appropriate points.
- FR4.2 — An enemy reaching the bottom of the screen (or a defined wrong-answer threshold, per the team's chosen tuning from Phase 2/3's descent behavior) reduces health by a defined amount.
- FR4.3 — Health is displayed via repeated `heart_icon.png` instances in the HUD, always reflecting `GameManager`'s current health value.
- FR4.4 — Lives are displayed via repeated `life_icon.png` instances in the HUD.
- FR4.5 — Health reaching 0 costs exactly one life, and health resets (to full) for the next life, per a single well-defined rule (no double-decrement, no silent state drift).
- FR4.6 — Losing the last life (lives reaching 0 after a health-depletion event) triggers a Game Over screen.
- FR4.7 — The Game Over screen uses `game_over_bg.png` (or `background_space.png` with an overlay panel, per Spec §7's fallback note) and displays the final score.
- FR4.8 — From Game Over, the game is in a terminated/non-interactive play state (no further answering) until an explicit restart action (full "Play Again" wiring is acceptable to be minimal here — high-score comparison is Phase 6, but the screen itself and its final-score display are in scope now).
- FR4.9 — When health reaches 0 and a life is lost while lives remain, the **remaining enemies in the current wave are reset/repositioned to their original wave-start formation positions (a defined safe distance)** from the player before play resumes, as required by Spec §4 step 7. The reset must not remove the remaining enemies, restart the wave, or cause immediate repeat damage.

### Non-Functional Requirements
- NFR4.1 — Health/lives transition logic must be testable **in isolation from the visual HUD** — i.e., `GameManager`'s state machine doesn't require the HUD scene to be present to be verified (Tech Stack §8).
- NFR4.2 — The health-loss trigger (bottom-reach vs. wrong-answer-threshold) must be a single, clearly defined rule that `WaveManager`/`enemy.gd` and `GameManager` agree on — avoid two different systems independently deciding when health is lost.
- NFR4.3 — HUD icon rendering (`heart_icon.png`/`life_icon.png` repetition) must always match `GameManager`'s true numeric health/lives state — no visual drift after rapid successive health-loss events.

### Out of Scope
- Level progression / `LevelManager.gd` (Phase 5).
- High score persistence and "New High Score!" messaging (Phase 6) — Game Over shows the final score plainly, without comparison logic yet.

---

## 2. Detailed Implementation Plan

1. **Define the health-loss trigger precisely**: confirm with the team whether health is lost when (a) any enemy in the active formation reaches a defined bottom Y-position, (b) the active enemy specifically reaches bottom, or (c) a wrong-answer count threshold is hit (Spec §4 step 5 allows either "whole formation advances" or "just the active enemy" — Phase 3 established descent; Phase 4 must pick and implement the actual penalty trigger). Document the chosen rule directly in `GameManager.gd`'s code comments so it's unambiguous for future phases.
2. **`GameManager.gd`** (autoload singleton):
   - State: `score: int`, `health: int`, `max_health: int`, `lives: int`, `game_state: enum {PLAYING, PAUSED, GAME_OVER}`.
   - `take_damage(amount: int)`: decrements `health`; if `health <= 0`, calls `lose_life()`.
   - `lose_life()`: decrements `lives`; if `lives <= 0`, sets `game_state = GAME_OVER` and emits a `game_over` signal; otherwise resets `health = max_health` and (if applicable) signals `WaveManager` to reset the current wave's remaining formation to a safe state per Spec §4 step 7 ("remaining formation resets to a safe distance").
   - `add_score(amount: int)`: increments `score`, emits a score-changed signal for the HUD.
   - Emits distinct signals (`health_changed`, `lives_changed`, `score_changed`, `game_over`) so HUD and other systems can react without polling.
3. **Wire the damage trigger**: connect the chosen bottom-reach/threshold event (from `enemy.gd`/`WaveManager`, per step 1's decision) to call `GameManager.take_damage(amount)`.
4. **HUD health/lives display**: `hud.gd` listens for `health_changed`/`lives_changed` signals and rebuilds an `HBoxContainer` of `heart_icon.png` (health) and `life_icon.png` (lives) instances matching the current counts, per Tech Stack §7's wiring notes.
5. **Game Over screen**: new `GameOverScreen.tscn` using `game_over_bg.png` (or background + overlay panel fallback), with a `Label` bound to `GameManager.score` at the moment `game_over` fires. `Main.gd` listens for the `game_over` signal and swaps/overlays this screen, halting further question/answer interaction (disable `QuestionPanel` input).
6. **Life-loss formation reset**: coordinate with `WaveManager` so that when a life is lost but the game continues, the current wave's remaining enemies are repositioned to their **original wave-start formation positions (the defined safe-distance formation position)** rather than instantly re-damaging the player (Spec §4 step 7). Preserve the remaining enemy set and wave/category progress; do not respawn a fresh wave or alter `enemies_remaining`.
7. **Write GUT tests** for `GameManager`'s transitions (see Testing Plan), designed to run without instancing the HUD scene.

---

## 3. Testing Plan

### Automated Tests (GUT)

**`test_game_manager.gd`**
- `take_damage(amount)` reduces `health` by exactly `amount`, without affecting `lives`, while `health` remains above 0.
- `take_damage` that brings `health` to exactly 0 triggers `lose_life()` — `lives` decrements by exactly 1, and `health` resets to `max_health` (if lives remain).
- `take_damage` that brings `health` below 0 (overshoot) is still treated as exactly one life lost, not accidentally causing extra decrements.
- Losing the last life (`lives` reaches 0) sets `game_state` to `GAME_OVER` and emits the `game_over` signal exactly once.
- `game_over` is never triggered while `lives > 0`, even after repeated `take_damage` calls across multiple life-loss cycles.
- **Formation reset on life loss:** when a life is lost and lives remain, `GameManager`/`WaveManager` coordinates a reset of the remaining formation to the defined safe distance; the remaining enemy count and current wave category are unchanged.
- `add_score(amount)` increments `score` correctly and emits `score_changed` with the right value.
- All of the above run instancing only `GameManager` (or a GUT double of its dependencies) — **no HUD scene, no `WaveManager` scene tree required** — per NFR4.1.

### Manual Test Checklist
| # | Scenario | Expected Result |
|---|---|---|
| 1 | Answer wrong repeatedly / let an enemy reach the bottom | Health icons (`heart_icon.png`) decrease in the HUD, matching the defined damage rule |
| 2 | Health reaches 0 with lives remaining | One life icon (`life_icon.png`) disappears; health visibly resets to full; play continues; remaining formation resets to a safe distance rather than instant re-damage |
| 3 | Lose all lives | Game Over screen appears using `game_over_bg.png` (or background+overlay fallback), showing the correct final score |
| 4 | Attempt to answer questions after Game Over | No further interaction is possible — question panel is inert |
| 5 | Play a full session start-to-finish | Full round trip (start → play through waves → take damage → lose lives → game over) works without desync between `GameManager`'s numeric state and the HUD's icon counts |
| 6 | Run full GUT suite | `test_game_manager.gd` passes, 0 failures, alongside all prior phases' passing tests (no regressions) |

**Definition of Done:** a complete play session — start, play through waves, take damage, lose lives, reach Game Over with the correct final score displayed — works end-to-end and is fully art-dressed (hearts, lives, game-over background), with `GameManager`'s health/lives state-machine logic covered by passing GUT tests that don't depend on the HUD or wave scene tree.
