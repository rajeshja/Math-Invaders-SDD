# Phase 5 --- Level Timer

**Goal:** add the per-level time limit: each level must be cleared
within a configurable budget, shown as a live countdown in the HUD.
Running out of time fails the level via Game Over ("Time's up!"),
exactly as life depletion does. This phase was split out of the old,
overloaded Phase 4 (which remains playable on its own: lives and Game
Over without time pressure); after this phase the timer layers onto
that working game as an additional, independent lose condition.

**Source docs:** Build Plan §Phase 5, Spec §4 step 7 (level time limit),
§6 (HUD time-remaining requirement), §7 (`seconds_per_wave`,
`level_time_limit_by_level`), Tech Stack §5 (GameManager timer state),
§9 (testing strategy).

------------------------------------------------------------------------

## 1. Requirements

### Functional Requirements

-   FR5.1 --- **Level time limit**: each level has a time limit for
    being solved, configurable through Project Settings. The default
    limit is computed as **number of waves in the level ×
    `gameplay/seconds_per_wave`** (default 30 seconds per wave). With
    Phase 3's four-wave level this yields a default of **120 seconds
    for Level 1**. An optional per-level override dictionary
    (`gameplay/level_time_limit_by_level`) may replace the computed
    value for specific levels; overrides must be positive numbers of
    seconds.
-   FR5.2 --- The timer starts when the level starts (in this phase:
    at session start) and decrements only while the game state is
    `PLAYING`. It is frozen while `PAUSED` or `GAME_OVER`. It continues
    across wave transitions within the level --- it is a per-level
    limit, not per-wave; ordinary wave boundaries never reset it.
-   FR5.3 --- When the remaining time reaches 0, the level is failed:
    `game_state` becomes `GAME_OVER` and the `game_over` signal fires
    exactly once, exactly as for life depletion. The Game Over screen
    distinguishes the cause via `GameManager.last_game_over_reason`
    (`LIVES_DEPLETED` vs. `TIME_EXPIRED`) and shows a "Time's up!"
    message for timer expiry alongside the final score. Answer input is
    disabled either way.
-   FR5.4 --- The HUD displays the remaining level time at all times
    during play and always corresponds to `GameManager.time_remaining`
    (displayed rounded up to whole seconds).
-   FR5.5 --- Timer state (`time_remaining`, the resolved
    `level_time_limit`, and `last_game_over_reason`, now extended with
    `TIME_EXPIRED`) is owned by `GameManager`. Time advances through an
    explicit `tick(delta)` call so the logic is deterministic and
    testable without the scene tree. `reset_session()` restores
    `time_remaining` to the configured limit for the restarted level.
-   FR5.6 --- Precedence: within a single frame, answer resolution
    happens before timer expiry processing. A correct answer that
    clears the current wave/level is honored even if the timer reaches
    zero in the same frame; the timer can only fail a level that has
    not already been cleared.
-   FR5.7 --- Answers never move the clock by more than real elapsed
    time: wrong answers do not consume time, correct answers do not
    add it, and no bullet animation pauses, extends, or otherwise
    distorts the countdown.

### Non-Functional Requirements

-   NFR5.1 --- Timer logic is testable without the visual HUD or a real
    scene tree: tests drive `tick(delta)` with fixed deltas and assert
    state transitions deterministically (no reliance on wall-clock
    time or engine timers inside `GameManager`).
-   NFR5.2 --- All new configuration values (`seconds_per_wave`,
    `level_time_limit_by_level`) are accessed through `GameConfig.gd`,
    never through scattered raw `ProjectSettings.get_setting()` calls.

### Out of Scope

-   Per-level timer restarts at level boundaries and Play Again
    re-resolution (LevelManager wiring lands in Phase 6/7; this phase
    starts and resets the timer at session scope only).
-   High score persistence (Phase 7).
-   Visual/audio polish: low-time warning effects and tick sounds
    (Phase 9).
-   Per-wave timers, time bonuses/penalties, or retry-the-level
    mechanics. The timer is strictly per-level in this phase.

------------------------------------------------------------------------

## 2. Detailed Implementation Plan

1.  **`GameConfig.gd`**: expose `get_seconds_per_wave() -> float` (from
    `gameplay/seconds_per_wave`, default 30, minimum 1) and
    `get_level_time_limit(level: int, wave_count: int) -> float`,
    which returns a valid positive entry from
    `gameplay/level_time_limit_by_level` for the supplied level when
    present, and otherwise computes `wave_count × get_seconds_per_wave()`.
2.  **`GameManager.gd`**: extend the Phase 4 state machine with
    `time_remaining: float`, `level_time_limit: float`, and reason
    value `TIME_EXPIRED`:
    -   `start_level_timer(limit: float)`: sets `level_time_limit` and
        `time_remaining` to `limit`, emits `time_changed`.
    -   `tick(delta: float)`: while `PLAYING`, decrements
        `time_remaining` by `delta`, emits `time_changed`, clamps at 0;
        on reaching 0 sets `last_game_over_reason = TIME_EXPIRED`,
        enters `GAME_OVER`, and emits `game_over` exactly once. No-op
        in any other state.
    -   `reset_session()`: additionally restarts the level timer at its
        configured limit and clears the reason.
3.  **Wire the timer**: at session start (and after any
    `reset_session()`), bootstrap code resolves the limit via
    `GameConfig.get_level_time_limit(current_level, wave_count)` ---
    where `wave_count` comes from `WaveManager`'s active category
    sequence length (4 in this phase) --- and calls
    `GameManager.start_level_timer(limit)`. `Main.gd`'s `_process`
    calls `GameManager.tick(delta)` every frame; `tick` itself no-ops
    unless `PLAYING`, so pausing freezes time automatically.
4.  **HUD**: add a `TimeLabel` that listens for `time_changed` and shows
    the remaining seconds (rounded up).
5.  **Game Over screen extension**: show "Time's up!" instead of "Out of
    lives!" when `last_game_over_reason == TIME_EXPIRED`; both reasons
    disable answer input identically.
6.  **Write GUT tests** for the timer (see Testing Plan).

------------------------------------------------------------------------

## 3. Testing Plan

### Automated Tests (GUT)

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

**`test_game_config.gd` (extended)** - Missing/invalid
`seconds_per_wave` falls back to 30. -
`get_level_time_limit(level, wave_count)` returns
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
  1                       Watch the HUD timer during  Counts down from 120 s
                           a fresh default session     (4 waves × 30 s);
                                                        continues across wave
                                                        transitions; freezes
                                                        while paused

  2                       Let the timer reach 0       Game Over appears
                           (e.g., set                   with a "Time's up!"
                           `seconds_per_wave = 5`       message; answer input
                           for quick testing)           is inert

  3                       Change                      New session's timer starts
                          `gameplay/                   at 80 s (4 waves × 20 s);
                          seconds_per_wave` to 20      per-level override entries
                          and relaunch                 replace the computed value

  4                       Clear the final enemy of a  The clear counts; Game Over
                           wave just as the timer hits  does not fire retroactively
                           0                            for the already-resolved
                                                         answer

  5                       Answer wrong/correct near   Time cost matches only real
                           expiry while bullets fly    elapsed ticks; neither the
                                                        player bullet nor enemy
                                                        return fire alters the
                                                        countdown

  6                       Run full GUT suite          0 failures
  ---------------------------------------------------------------------------

**Definition of Done:** each session runs against its configured level
time limit (default: waves × 30 s --- 120 s for Level 1), shown as a
live countdown in the HUD; the timer runs only while playing, survives
wave transitions untouched, and reaching zero fails the level via Game
Over ("Time's up!") exactly once, indistinguishable in flow from
life-depletion Game Over apart from the reason line. The lives path
from Phase 4 still ends the game first if lives run out sooner, and
the timer state machine is covered by passing GUT tests.


## 4. Level Time Limit (Detail)

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
   auto-advance; Play Again (Phase 7) restarts at Level 1 with a fresh
   timer.
5. Answer resolution precedes expiry processing each frame, so clearing
   the final enemy as time hits zero still counts as a clear.
