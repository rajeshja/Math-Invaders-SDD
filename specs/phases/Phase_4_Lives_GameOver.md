# Phase 4 --- Lives, Level Timer, and Game Over

**Goal:** give wrong answers their real consequence --- one life lost
per incorrect answer, visualized by the active enemy firing a bullet at
the player --- and add the Game Over state. The player has a
configurable mistake budget rather than a health pool. Each level also
gets a configurable time limit: completing every wave in the level
before time expires is required, and running out of time fails the
level via Game Over. All bullet travel times (player and enemy) are
fixed at 0.3 seconds regardless of distance.

**Source docs:** Build Plan §Phase 4, Spec §4 (core loop and life
depletion), §6 (HUD lives/time requirement), §7 (`life_icon.png`,
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
-   FR4.5 --- The active enemy, formation positions, and current
    question are unchanged by an incorrect answer. The player may retry
    the same question until it is answered correctly or Game Over
    occurs.
-   FR4.6 --- Lives are displayed via repeated `life_icon.png` instances
    in the HUD and always match `GameManager.lives`.
-   FR4.7 --- When `lives` reaches 0, `game_state` becomes `GAME_OVER`
    and the `game_over` signal fires exactly once.
-   FR4.8 --- Game Over disables question input and uses
    `game_over_bg.png` (or the documented fallback) while displaying the
    final score.
-   FR4.9 --- A life count never becomes negative. Additional answer
    events after Game Over are ignored.
-   FR4.10 --- `reset_session()` restores `lives` to the configured
    `starting_lives` value and returns the game to `PLAYING`.
-   FR4.11 --- **Level time limit**: each level has a time limit for
    being solved, configurable through Project Settings. The default
    limit is computed as **number of waves in the level ×
    `gameplay/seconds_per_wave`** (default 30 seconds per wave). With
    Phase 3's four-wave level this yields a default of **120 seconds
    for Level 1**. An optional per-level override dictionary
    (`gameplay/level_time_limit_by_level`) may replace the computed
    value for specific levels; overrides must be positive numbers of
    seconds.
-   FR4.12 --- The timer starts when the level starts (in this phase:
    at session start) and decrements only while the game state is
    `PLAYING`. It is frozen while `PAUSED` or `GAME_OVER`. It continues
    across wave transitions within the level --- it is a per-level
    limit, not per-wave; ordinary wave boundaries never reset it.
-   FR4.13 --- When the remaining time reaches 0, the level is failed:
    `game_state` becomes `GAME_OVER` and the `game_over` signal fires
    exactly once, exactly as for life depletion. The Game Over screen
    distinguishes the cause via `GameManager.last_game_over_reason`
    (`LIVES_DEPLETED` vs. `TIME_EXPIRED`) and shows a "Time's up!"
    message for timer expiry alongside the final score. Answer input is
    disabled either way.
-   FR4.14 --- The HUD displays the remaining level time at all times
    during play and always corresponds to `GameManager.time_remaining`
    (displayed rounded up to whole seconds).
-   FR4.15 --- Timer state (`time_remaining`, the resolved
    `level_time_limit`, and `last_game_over_reason`) is owned by
    `GameManager`. Time advances through an explicit
    `tick(delta)` call so the logic is deterministic and testable
    without the scene tree. `reset_session()` restores
    `time_remaining` to the configured limit for the restarted level.
-   FR4.16 --- Precedence: within a single frame, answer resolution
    happens before timer expiry processing. A correct answer that
    clears the current wave/level is honored even if the timer reaches
    zero in the same frame; the timer can only fail a level that has
    not already been cleared.
-   FR4.17 --- **Enemy-fire feedback on wrong answers**: on every
    incorrect answer, the active enemy plays a brief fire animation
    (e.g., quick flash/scale "telegraph") and visibly fires a bullet
    using `enemy_bullet.png` from its position to the player ship,
    ending in a short player-hit flash. This is purely presentational:
    gameplay consequences remain exactly one life consumed, the red
    answer-button flash, and the configured question-attempt behavior.
    No collision/physics damage path is introduced --- damage stays
    event-driven.
-   FR4.18 --- **Fixed bullet travel time**: all bullets take exactly
    **0.3 seconds** total travel time in all cases, independent of the
    distance between source and target. This applies to the player
    bullet fired on correct answers (replacing any slower/distance-
    dependent travel from earlier phases) and to the new enemy bullet
    fired on wrong answers. Implementation is a fixed-duration tween,
    not a fixed velocity.

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
-   NFR4.6 --- Timer logic is testable without the visual HUD or a real
    scene tree: tests drive `tick(delta)` with fixed deltas and assert
    state transitions deterministically (no reliance on wall-clock
    time or engine timers inside `GameManager`).
-   NFR4.7 --- The enemy-fire animation must not block or delay the
    underlying game-state transition: life consumption, the red flash,
    question advancement per the attempt rules, and any Game Over
    transition happen immediately on the logic side, decoupled from how
    long the bullet visual takes to travel.
-   NFR4.8 --- All new configuration values (`seconds_per_wave`,
    `level_time_limit_by_level`) are accessed through `GameConfig.gd`,
    never through scattered raw `ProjectSettings.get_setting()` calls.
-   NFR4.9 --- The 0.3-second bullet travel duration is defined once as
    a shared constant (in `bullet.gd`, reused by the enemy bullet) so
    player and enemy bullets cannot drift apart.

### Out of Scope

-   Level progression and level-boundary lives/timer reset (Phase 5).
-   High score persistence and Play Again wiring (Phase 6).
-   Visual/audio polish: low-time warning effects, screen shake, and
    fire/hit sounds for the new bullet (Phase 8).
-   Per-wave timers, time bonuses/penalties, or retry-the-level
    mechanics. The timer is strictly per-level in this phase.

------------------------------------------------------------------------

## 2. Detailed Implementation Plan

1.  **`GameConfig.gd`**: expose `get_starting_lives() -> int` from
    `gameplay/starting_lives`, defaulting safely to 3 if the setting is
    missing or invalid. Also expose
    `get_seconds_per_wave() -> float` (from
    `gameplay/seconds_per_wave`, default 30, minimum 1) and
    `get_level_time_limit(level: int, wave_count: int) -> float`,
    which returns a valid positive entry from
    `gameplay/level_time_limit_by_level` for the supplied level when
    present, and otherwise computes `wave_count × get_seconds_per_wave()`.
2.  **`GameManager.gd`**:
    -   State: `score: int`, `lives: int`, `starting_lives: int`,
        `game_state: enum { PLAYING, PAUSED, GAME_OVER }`,
        `time_remaining: float`, `level_time_limit: float`,
        `last_game_over_reason: enum { NONE, LIVES_DEPLETED,
        TIME_EXPIRED }`.
    -   `take_damage(amount: int = 1)`: while `PLAYING`, consume the
        requested life amount, clamped so lives cannot go below 0; for
        the current gameplay contract all wrong answers call it with
        `1`. Records `LIVES_DEPLETED` when this ends the game.
    -   `lose_life()` / equivalent: decrement one life, emit
        `lives_changed`, and if lives reaches 0 set `GAME_OVER` and emit
        `game_over` exactly once.
    -   `start_level_timer(limit: float)`: sets `level_time_limit` and
        `time_remaining` to `limit`, emits `time_changed`.
    -   `tick(delta: float)`: while `PLAYING`, decrements
        `time_remaining` by `delta`, emits `time_changed`, clamps at 0;
        on reaching 0 sets `last_game_over_reason = TIME_EXPIRED`,
        enters `GAME_OVER`, and emits `game_over` exactly once. No-op
        in any other state.
    -   `reset_session()`: restore score to 0, lives to configured
        starting lives, restart the level timer at its configured
        limit, clear the reason, and return to `PLAYING`.
3.  **Wire the wrong-answer event**: `QuestionPanel`/the gameplay
    controller reports the incorrect answer once; the authoritative
    game-state path calls `GameManager.take_damage(1)`. The current
    question remains selected.
4.  **Wire the timer**: at session start (and after any
    `reset_session()`), bootstrap code resolves the limit via
    `GameConfig.get_level_time_limit(current_level, wave_count)` ---
    where `wave_count` comes from `WaveManager`'s active category
    sequence length (4 in this phase) --- and calls
    `GameManager.start_level_timer(limit)`. `Main.gd`'s `_process`
    calls `GameManager.tick(delta)` every frame; `tick` itself no-ops
    unless `PLAYING`, so pausing freezes time automatically.
5.  **HUD**: replace any health/heart display with a lives display using
    repeated `life_icon.png`, and add a `TimeLabel` that listens for
    `time_changed` and shows the remaining seconds (rounded up).
6.  **Game Over screen**: connect to `game_over`, disable
    `QuestionPanel` input, show the final score, and show a reason line
    ("Out of lives!" or "Time's up!") based on
    `last_game_over_reason`.
7.  **Enemy bullet + fire animation**:
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
8.  **Fix player-bullet travel time**: refactor `bullet.gd`'s movement
    to a fixed-duration tween (`TRAVEL_TIME := 0.3`) from source to
    target position, replacing any fixed-velocity/slow travel; expose
    the constant so the enemy bullet reuses the identical duration.
9.  **Remove old descent damage**: delete/disable any code that moves
    enemies downward on wrong answers or triggers damage when an enemy
    reaches the bottom.
10. **Write GUT tests** for `GameManager`, `GameConfig`, and the timer
    (see Testing Plan).

------------------------------------------------------------------------

## 3. Testing Plan

### Automated Tests (GUT)

**`test_game_manager.gd`** - Starting lives load from the configured
value. - One wrong-answer/damage event consumes exactly one life. -
Correct-answer path does not change lives. - Repeated wrong answers
consume one life each. - Lives reaching exactly 0 enters `GAME_OVER` and
emits `game_over` once. - Lives never become negative. - Additional
damage/answer events after Game Over do nothing. - `reset_session()`
restores the configured starting-lives value and `PLAYING`. - No test
requires the HUD or a real `WaveManager` scene tree.

**Timer cases (in `test_game_manager.gd`)** - `start_level_timer(120)`
sets both `level_time_limit` and `time_remaining` to 120 and emits
`time_changed`. - `tick(delta)` reduces `time_remaining` by exactly the
supplied delta while `PLAYING`. - Driving `tick()` until
`time_remaining` reaches 0 enters `GAME_OVER`, sets
`last_game_over_reason = TIME_EXPIRED`, and emits `game_over` exactly
once. - Further `tick()` calls after Game Over change nothing (no
negative time, no second signal). - `tick()` while not `PLAYING`
(e.g., after an explicit pause-state set) does not reduce
`time_remaining`. - A life-depletion game over records
`LIVES_DEPLETED`; the two reasons are mutually exclusive per session. -
`reset_session()` restores `time_remaining` to the configured level
limit and clears the reason.

**`test_game_config.gd`** - Missing/invalid setting falls back to the
documented default. - Configured `starting_lives` is returned correctly.
- Missing/invalid `seconds_per_wave` falls back to 30.
- `get_level_time_limit(level, wave_count)` returns
`wave_count × seconds_per_wave` when no override exists (e.g.,
4 waves × 30 s = 120). - A valid positive entry in
`gameplay/level_time_limit_by_level` for the supplied level replaces the
computed value; invalid entries (zero, negative, non-numeric) are
ignored and fall back to the computed value; levels without an override
entry use the computed value.

### Manual Test Checklist

  ---------------------------------------------------------------------------
  \#                      Scenario                    Expected Result
  ----------------------- --------------------------- -----------------------
  1                       Start a fresh session       HUD shows the
                                                      configured number of
                                                      lives (default 3)

  2                       Answer correctly            Enemy is destroyed;
                                                      lives do not change

  3                       Answer incorrectly once     One life disappears;
                                                      enemy/formation and
                                                      question remain
                                                      unchanged

  4                       Answer incorrectly twice    Two lives are consumed;
                                                      play continues with the
                                                      same current question

  5                       Answer incorrectly a third  Game Over appears
                          time with 3 starting lives  immediately; no fourth
                                                      attempt is accepted

  6                       Change                      HUD starts with 5 lives
                          `gameplay/starting_lives`   and Game Over occurs
                          to 5 and relaunch           after the fifth wrong
                                                      answer

  7                       Attempt to answer after     Question panel is inert
                           Game Over                   

  8                       Watch the HUD timer during Counts down from 120 s
                           a fresh default session      (4 waves × 30 s);
                                                        continues across wave
                                                        transitions; freezes
                                                        while paused

  9                       Let the timer reach 0        Game Over appears
                           (e.g., set                   with a "Time's up!"
                           `seconds_per_wave = 5`       message; answer input
                           for quick testing)           is inert

  10                      Answer incorrectly once      Active enemy visibly fires;
                           and watch the enemy          bullet reaches the player
                                                        in ≈0.3 s, player-hit flash
                                                        plays; one life disappears;
                                                        red flash + attempt rules
                                                        unchanged

  11                      Answer correctly and         Bullet reaches the enemy in
                           time the bullet              ≈0.3 s regardless of how far
                                                        the active enemy is from the
                                                        player (top row vs. bottom
                                                        row)

  12                      Change `gameplay/            New session's timer starts
                           seconds_per_wave` to 20      at 80 s (4 waves × 20 s);
                           and relaunch                 per-level override entries
                                                        replace the computed value

  13                      Run full GUT suite           0 failures
  ---------------------------------------------------------------------------

**Definition of Done:** every wrong answer consumes exactly one
configured life and flashes the selected answer red while the active
enemy visibly fires a bullet that reaches the player in exactly 0.3
seconds; all bullets (player and enemy) travel in exactly 0.3 seconds
regardless of distance; with the default one attempt, the next question
is loaded after the feedback, while higher per-level attempt overrides
permit additional attempts on the same question. Each level runs against
its configured time limit (default: waves × 30 s --- 120 s for Level 1),
shown as a live countdown in the HUD; reaching zero fails the level via
Game Over ("Time's up!") exactly once, indistinguishable in flow from
life-depletion Game Over apart from the reason line. The game ends when
lives reach zero or time expires, and the lives/attempt/timer state
machine is covered by passing GUT tests.


## 4. Question Attempt State

`GameManager` owns lives; the question-flow layer owns the attempt counter for
the current question. The effective maximum attempts comes from
`GameConfig.get_tries_per_question(current_level)`.

On a wrong answer:

1. `QuestionPanel` flashes the tapped answer red.
2. Exactly one life is consumed.
3. If lives reach zero, emit `game_over` and stop.
4. Otherwise, if the question's attempt count has reached the effective
   maximum, load a new question.
5. Otherwise, keep the same question active for another attempt.

The default maximum is one, so the normal path is wrong → red flash → life
lost → next question.

## 5. Level Time Limit (Detail)

### Configuration

```text
gameplay/seconds_per_wave = 30            # float, minimum 1
gameplay/level_time_limit_by_level = {}   # optional {level: seconds} overrides
```

Effective limit for a level = valid per-level override, otherwise
`wave_count × seconds_per_wave`, where `wave_count` is the length of the
level's category sequence (4 in this phase).

| Level | Waves | Default limit |
|-------|-------|---------------|
| 1     | 4     | 120 s         |
| override `{ 2: 200 }` | 4 | 200 s for Level 2 only |

### Behavior rules

1. The timer starts at level start (session start in this phase) and
   runs only while `PLAYING`; pause freezes it.
2. Wave transitions do **not** reset or pause the timer --- the whole
   level must be cleared inside one continuous budget.
3. Wrong answers do **not** consume time and correct answers do not
   add time; time pressure is independent of the lives budget.
4. Reaching zero fails the level: `GAME_OVER` + `game_over` exactly
   once with reason `TIME_EXPIRED`. There is no partial credit and no
   auto-advance; Play Again (Phase 6) restarts at Level 1 with a fresh
   timer.
5. Answer resolution precedes expiry processing each frame, so clearing
   the final enemy as time hits zero still counts as a clear.

## 6. Wrong-Answer Enemy Fire & Bullet Travel Timing (Detail)

Sequence on every incorrect answer:

1. Tapped button flashes red (existing feedback) and one life is
   consumed via `take_damage(1)` --- unchanged.
2. The active enemy plays a ~0.1 s fire telegraph (flash/scale tween).
3. One `enemy_bullet.tscn` instance spawns at the enemy's position
   under the `Bullets` container and tweens to the player ship's
   position over **exactly 0.3 s** (`bullet.gd`'s shared
   `TRAVEL_TIME` constant).
4. On arrival the bullet despawns with a brief player-hit flash on the
   ship sprite. The HUD life-icon removal stays driven by the
   authoritative `lives_changed` signal (immediate); the bullet is
   flavor, not the damage mechanism.

Constraints:

- The animation never blocks input gating (which follows the existing
  red-flash interval), question advancement, or a Game Over transition;
  if that wrong answer ends the game, Game Over UI takes precedence and
  the in-flight bullet may finish visually underneath or be cancelled.
- Multiple wrong answers each produce their own independent bullet; no
  deduplication or queuing logic is required.
- No Area2D/CollisionObject-based damage: bullets are tweens with a
  scripted arrival callback, keeping damage event-driven per NFR4.3.
