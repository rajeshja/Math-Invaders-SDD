# Phase 4 --- Lives, Wrong-Answer Feedback & Game Over

**Goal:** give wrong answers their real consequence --- one life lost
per incorrect answer, visualized by the active enemy firing a bullet at
the player --- and add the Game Over state. The player has a
configurable mistake budget rather than a health pool. All bullet
travel times (player and enemy) are fixed at 0.3 seconds regardless of
distance, and every answer's gameplay consequences resolve immediately
and in parallel with any bullet animation, so no bullet flight ever
eats into the time available to answer the next question. (The split:
the per-level time limit that used to share this phase now has its own
Phase 5.)

**Source docs:** Build Plan §Phase 4, Spec §4 (core loop and life
depletion), §6 (HUD lives requirement), §7 (`life_icon.png`,
`game_over_bg.png`, `enemy_bullet.png`), Tech Stack §5 (GameManager),
§6 (Project Settings), §9 (testing strategy).

------------------------------------------------------------------------

## 1. Requirements

### Functional Requirements

-   FR4.1 --- `GameManager.gd` exists as the authoritative owner of
    overall game state (`PLAYING`/`PAUSED`/`GAME_OVER`), score, and
    lives.
-   FR4.2 --- The configured `gameplay/starting_lives` value is loaded
    through `GameConfig.gd`; default is 3.
-   FR4.3 --- Every incorrect answer consumes exactly one life. The
    damage event is idempotent at the event level: one incorrect tap
    produces one life decrement, never two.
-   FR4.4 --- A correct answer never consumes a life.
-   FR4.5 --- Wrong answers follow the configured question-attempt rule
    without moving or removing any enemy and without changing the
    active target: with the default one attempt, the wrong answer
    retires the current question and loads the next one; a higher
    per-level override keeps the same question active until its
    allowed attempts are exhausted. Every wrong attempt still costs
    exactly one life.
-   FR4.6 --- Lives are displayed via repeated `life_icon.png` instances
    in the HUD and always match `GameManager.lives`.
-   FR4.7 --- When `lives` reaches 0, `game_state` becomes `GAME_OVER`
    and the `game_over` signal fires exactly once, recording reason
    `LIVES_DEPLETED` in `GameManager.last_game_over_reason`. (The
    enum is introduced in this phase as `{ NONE, LIVES_DEPLETED }`;
    Phase 5 extends it with `TIME_EXPIRED`.)
-   FR4.8 --- Game Over disables question input and uses
    `game_over_bg.png` (or the documented fallback) while displaying
    the final score and an "Out of lives!" reason line. Game Over is a
    terminated state until an explicit restart action --- full "Play
    Again" wiring is deferred to Phase 7.
-   FR4.9 --- A life count never becomes negative. Additional answer
    events after Game Over are ignored.
-   FR4.10 --- `reset_session()` restores `lives` to the configured
    `starting_lives` value and returns the game to `PLAYING`.
-   FR4.11 --- **Enemy-fire feedback on wrong answers**: on every
    incorrect answer, the active enemy plays a brief fire animation
    (e.g., quick flash/scale "telegraph") and visibly fires a bullet
    using `enemy_bullet.png` from its position to the player ship,
    ending in a short player-hit flash. This is purely presentational:
    gameplay consequences remain exactly one life consumed, the red
    answer-button flash, and the configured question-attempt behavior.
    No collision/physics damage path is introduced --- damage stays
    event-driven.
-   FR4.12 --- **Fixed bullet travel time**: all bullets take exactly
    **0.3 seconds** total travel time in all cases, independent of the
    distance between source and target. This applies to the player
    bullet fired on correct answers (replacing any slower/distance-
    dependent travel from earlier phases) and to the new enemy bullet
    fired on wrong answers. Implementation is a fixed-duration tween,
    not a fixed velocity.
-   FR4.13 --- **Parallel answer resolution**: answering is never
    delayed by any bullet animation. On a **correct** answer, score
    and the next active-enemy question all
    resolve at the same instant the player bullet *launches*. The targeted
    enemy remains visible but is excluded from active-enemy selection
    until the bullet's arrival confirms the hit and destroys it. On a **wrong** answer, the life loss,
    attempt counting, and Game Over check resolve immediately; only
    the next question's *display* may wait out the brief red-flash
    feedback interval (~0.18 s), and it must never wait for the enemy
    bullet's launch, telegraph, or arrival.

### Non-Functional Requirements

-   NFR4.1 --- Lives/state logic is testable without the visual HUD or
    real `WaveManager` scene tree.
-   NFR4.2 --- The wrong-answer event has exactly one authoritative
    consumer for life loss; `QuestionPanel`, `WaveManager`, and
    `GameManager` must not independently decrement lives.
-   NFR4.3 --- No gameplay code uses a health pool, health hearts,
    enemy-bottom collision, formation descent, or a wrong-answer
    movement threshold as a damage mechanism.
-   NFR4.4 --- The configured starting-lives value is accessed through
    `GameConfig.gd`, not through scattered raw
    `ProjectSettings.get_setting()` calls.
-   NFR4.5 --- The same wrong-answer path is used for desktop mouse
    input and mobile touch input.
-   NFR4.6 --- Animations must never block or delay game-state
    transitions: life consumption, red flash start, question
    advancement per the attempt rules, and any Game Over transition
    happen immediately on the logic side, decoupled from how long any
    bullet takes to fly. The only permitted await before showing the
    next question is the fixed red-flash feedback interval.
-   NFR4.7 --- The 0.3-second bullet travel duration is defined once as
    a shared constant (in `bullet.gd`, reused by the enemy bullet) so
    player and enemy bullets cannot drift apart.

### Out of Scope

-   The per-level time limit, HUD countdown, and `TIME_EXPIRED` game
    over (Phase 5).
-   Level progression and level-boundary lives/timer reset (Phase 6).
-   High score persistence and Play Again wiring (Phase 7).
-   Visual/audio polish: low-time warning effects, screen shake, and
    fire/hit sounds for the new bullet (Phase 9).

------------------------------------------------------------------------

## 2. Detailed Implementation Plan

1.  **`GameConfig.gd`**: expose `get_starting_lives() -> int` from
    `gameplay/starting_lives`, defaulting safely to 3 if the setting is
    missing or invalid.
2.  **`GameManager.gd`**:
    -   State: `score: int`, `lives: int`, `starting_lives: int`,
        `game_state: enum { PLAYING, PAUSED, GAME_OVER }`,
        `last_game_over_reason: enum { NONE, LIVES_DEPLETED }`
        (extended with `TIME_EXPIRED` by Phase 5).
    -   `take_damage(amount: int = 1)`: while `PLAYING`, consume the
        requested life amount, clamped so lives cannot go below 0; for
        the current gameplay contract all wrong answers call it with
        `1`. Records `LIVES_DEPLETED` when this ends the game.
    -   `lose_life()` / equivalent: decrement one life, emit
        `lives_changed`, and if lives reaches 0 set `GAME_OVER` and emit
        `game_over` exactly once.
    -   `reset_session()`: restore score to 0, lives to configured
        starting lives, clear the reason, and return to `PLAYING`.
3.  **Wire the wrong-answer event**: `QuestionPanel`/the gameplay
    controller reports the incorrect answer once; the authoritative
    game-state path calls `GameManager.take_damage(1)` immediately ---
    not after any animation.
4.  **Enemy bullet + fire animation**:
    -   Add `enemy_bullet.png` under `assets/images/ships/` (same-dimension
        placeholder until final art arrives) plus an
        `enemy_bullet.tscn`/script mirroring `bullet.tscn`.
    -   On the wrong-answer event, the active enemy plays a short fire
        telegraph (flash/scale tween, ~0.1 s) and instances one enemy
        bullet at its position under the `Bullets` container; the
        bullet tweens to the player ship's position over exactly 0.3 s
        and despawns with a brief player-hit flash. The visual path
        listens to the same single wrong-answer event the damage path
        uses --- it never decrements lives itself and never blocks
        input, question advancement, or Game Over.
5.  **Fix player-bullet travel time**: refactor `bullet.gd`'s movement
    to a fixed-duration tween (`TRAVEL_TIME := 0.3`) from source to
    target position, replacing any fixed-velocity/slow travel; expose
    the constant so the enemy bullet reuses the identical duration.
6.  **Parallel resolution wiring**: in `Main.gd`, the correct-answer
    handler launches the bullet, adds score, and calls `WaveManager.on_correct_answer()`
    to emit the next question immediately. The bullet's arrival callback is wired to
    `WaveManager.on_enemy_hit()` to handle enemy destruction. The wrong-answer handler starts the
    red flash non-blocking, resolves life/attempts/Game Over
    immediately, and awaits only the panel's fixed feedback interval
    before displaying the next question or re-enabling input.
7.  **HUD**: replace any health/heart display with a lives display using
    repeated `life_icon.png`.
8.  **Game Over screen**: connect to `game_over`, disable
    `QuestionPanel` input, show the final score, and show the reason
    line ("Out of lives!"; "Time's up!" joins it in Phase 5). Full
    Play Again wiring stays deferred to Phase 7.
9.  **Remove old descent damage**: delete/disable any code that moves
    enemies downward on wrong answers or triggers damage when an enemy
    reaches the bottom.
10. **Write GUT tests** for `GameManager` and `GameConfig` (see
    Testing Plan).

------------------------------------------------------------------------

## 3. Testing Plan

### Automated Tests (GUT)

**`test_game_manager.gd`** - Starting lives load from the configured
value. - One wrong-answer/damage event consumes exactly one life. -
Correct-answer path does not change lives. - Repeated wrong answers
consume one life each. - Lives reaching exactly 0 enters `GAME_OVER` and
emits `game_over` once. - Lives never become negative. - Additional
damage/answer events after Game Over do nothing. - A life-depletion
game over records `last_game_over_reason = LIVES_DEPLETED`. -
`reset_session()` restores the configured starting-lives value,
clears the reason, and returns to `PLAYING`. - No test requires the
HUD or a real `WaveManager` scene tree.

**`test_game_config.gd`** - Missing/invalid setting falls back to the
documented default. - Configured `starting_lives` is returned correctly.

### Manual Test Checklist

  ---------------------------------------------------------------------------
  \#                      Scenario                    Expected Result
  ----------------------- --------------------------- -----------------------
  1                       Start a fresh session       HUD shows the
                                                      configured number of
                                                      lives (default 3)

  2                       Answer correctly            Enemy is destroyed;
                                                      lives do not change;
                                                      the next question is
                                                      answerable immediately,
                                                      while the bullet is
                                                      still visibly in flight

  3                       Answer incorrectly once     One life disappears
                                                      immediately; enemy/
                                                      formation unchanged;
                                                      next question appears
                                                      right after the red
                                                      flash, long before the
                                                      enemy bullet lands

  4                       Answer incorrectly twice    Two lives are consumed;
                                                      play continues per the
                                                      configured attempt rule

  5                       Answer incorrectly a third  Game Over appears
                          time with 3 starting lives  immediately; no fourth
                                                       attempt is accepted

  6                       Change                      HUD starts with 5 lives
                          `gameplay/starting_lives`   and Game Over occurs
                           to 5 and relaunch          after the fifth wrong
                                                      answer

  7                       Attempt to answer after     Question panel is inert
                           Game Over                  

  8                       Answer incorrectly once     Active enemy visibly fires;
                           and watch the enemy         bullet reaches the player
                                                        in ≈0.3 s, player-hit flash
                                                        plays; one life disappears;
                                                        red flash + attempt rules
                                                        unchanged

  9                       Answer correctly and        Bullet reaches the enemy in
                           time the bullet             ≈0.3 s regardless of how far
                                                       the active enemy is from the
                                                       player (triangle tip vs.
                                                       back row)

  10                      Run full GUT suite          0 failures
  ---------------------------------------------------------------------------

**Definition of Done:** every wrong answer consumes exactly one
configured life and flashes the selected answer red while the active
enemy visibly fires a bullet that reaches the player in exactly 0.3
seconds; all bullets (player and enemy) travel in exactly 0.3 seconds
regardless of distance; correct answers load the next question in the
same frame the bullet fires, so bullet flight costs zero answering
time; with the default one attempt, the next question is displayed
right after the red-flash interval --- never after a bullet lands ---
while higher per-level attempt overrides permit additional attempts on
the same question. The game ends when lives reach zero, and the
lives/attempt state machine is covered by passing GUT tests.


## 4. Question Attempt State

`GameManager` owns lives; the question-flow layer owns the attempt counter for
the current question. The effective maximum attempts comes from
`GameConfig.get_tries_per_question(current_level)`.

On a wrong answer:

1. `QuestionPanel` flashes the tapped answer red (non-blocking visual).
2. Exactly one life is consumed --- immediately.
3. If lives reach zero, emit `game_over` and stop; Game Over UI takes
   precedence and no further question work happens.
4. Otherwise, if the question's attempt count has reached the effective
   maximum, wait out the red-flash interval, then load a new question.
5. Otherwise, after the same brief interval, keep the same question
   active for another attempt.

The default maximum is one, so the normal path is wrong → red flash → life
lost (immediate) → next question. No step ever waits for a bullet.

## 5. Wrong-Answer Enemy Fire & Bullet Travel Timing (Detail)

Sequence on every incorrect answer:

1. Tapped button flashes red and one life is consumed via
   `take_damage(1)` --- the flash is fire-and-forget; the damage path
   does not await it.
2. In parallel, the active enemy plays a ~0.1 s fire telegraph
   (flash/scale tween).
3. One `enemy_bullet.tscn` instance spawns at the enemy's position
   under the `Bullets` container and tweens to the player ship's
   position over **exactly 0.3 s** (`bullet.gd`'s shared
   `TRAVEL_TIME` constant).
4. On arrival the bullet despawns with a brief player-hit flash on the
   ship sprite. The HUD life-icon removal stays driven by the
   authoritative `lives_changed` signal (immediate); the bullet is
   flavor, not the damage mechanism.

Correct-answer sequence (for contrast):

1. Player bullet launches from the ship toward the active enemy
   (exactly 0.3 s flight).
2. In the **same frame**, score increments, and the next active-enemy question is emitted to the
   panel --- the player can answer again while the bullet is mid-flight. The targeted enemy
   remains visible but is excluded from active-enemy selection.
3. The bullet's arrival callback confirms the hit, destroying the enemy and updating the
   wave's remaining count. Future hit-effect hooks will also trigger here.

Constraints:

- No animation blocks input gating beyond the deliberate red-flash
  interval; if a wrong answer ends the game, Game Over UI takes
  precedence and the in-flight bullet may finish visually underneath or
  be cancelled.
- Multiple wrong answers each produce their own independent bullet; no
  deduplication or queuing logic is required.
- No Area2D/CollisionObject-based damage: bullets are tweens with a
  scripted arrival callback, keeping damage event-driven per NFR4.3.
