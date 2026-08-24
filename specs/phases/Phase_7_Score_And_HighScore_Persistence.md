# Phase 7 --- Score & High Score Persistence

**Goal:** give the score its final HUD styling, add
`HighScoreManager.gd` so the player's best score survives across app
restarts, and complete the "Play Again" session-restart flow that Phase
4 explicitly left minimal --- clearly defining what a restart resets and
what it must leave untouched.

**Source docs:** Build Plan §Phase 7, Spec §4 (core loop step 10), §6
(high scores tracked and persisted), Tech Stack §5
(`HighScoreManager.gd`), §6 (Persistence Details), §8 (HighScoreManager
testing strategy); Phase 4 FR4.8 (Game Over is a terminated state "until
an explicit restart action," with full "Play Again" wiring explicitly
deferred to this phase).

------------------------------------------------------------------------

## 1. Requirements

### Functional Requirements

-   FR7.1 --- The score display is refined at the top of the HUD using
    the game's chosen font/iconography (visual polish only; the
    underlying `score_changed` signal and value from `GameManager`,
    Phase 4, are unchanged).
-   FR7.2 --- `HighScoreManager.gd` (autoload) persists a single
    high-score value locally via `FileAccess`/`ConfigFile` or a small
    JSON file in `user://`, per Tech Stack §6.
-   FR7.3 --- `HighScoreManager` loads the stored high score at startup
    and exposes `get_high_score() -> int`.
-   FR7.4 --- `HighScoreManager` exposes
    `save_if_higher(score: int) -> bool`, which updates and persists the
    stored high score only if `score` exceeds the current stored value,
    returning whether a new record was set.
-   FR7.5 --- When `GameManager`'s `game_over` signal fires (Phase 4),
    the game-over handling code (`Main.gd`/`GameOverScreen.gd` --- the
    same listener that swaps in the Game Over screen in Phase 4) calls
    `HighScoreManager.save_if_higher(score)` with the session's final
    score, per Spec §4 step 10. `GameManager` itself does not call
    `HighScoreManager` directly, keeping the two autoloads decoupled per
    Phase 0's architecture-ownership note.
-   FR7.6 --- The Game Over screen shows **"New High Score!"** alongside
    the final score when `save_if_higher()` returns `true`, and
    otherwise shows the current persisted high score alongside the final
    score.
-   FR7.7 --- The stored high score persists across app restarts
    (verified by relaunching after a session).
-   FR7.8 --- The Game Over screen's "Play Again" control (Phase 4,
    FR4.8) is fully wired in this phase: tapping it returns the game to
    a freshly-started session --- Level 1, Wave 1 (Addition), 10 fresh
    enemies --- exactly as if the app had just been launched, and
    re-enables `QuestionPanel` input.
-   FR7.9 --- Restart resets exactly the following session state, and
    nothing else:
    -   **`GameManager`**: `score → 0`, `lives →` the configured
        starting lives count, `game_state → PLAYING`, `time_remaining →`
        Level 1's resolved limit via `start_level_timer()` (emitting
        `score_changed`/`lives_changed`/`time_changed` so the HUD
        updates immediately).
    -   **`LevelManager`**: `current_level → 1`, `difficulty →` the
        Level 1 value from its formula (Phase 6).
    -   **`WaveManager`**: any remaining enemy and bullet nodes from the
        previous session are cleared, the category sequence is rebuilt
        for Level 1 (the base 4-category list, or 5 if the advanced
        threshold logic from Phase 8 is already in place and Level 1
        still qualifies --- it won't, by construction, but the reset
        must not hardcode "4 waves" in a way that breaks once Phase 8
        lands), and a fresh Wave 1 (Addition) is spawned.
-   FR7.10 --- `HighScoreManager`'s stored value is explicitly **not**
    touched by restart --- the high score set (or not) by the session
    that just ended remains exactly as `save_if_higher()` left it, and
    the newly-restarted session's future `game_over` will compare
    against that same persisted value.

### Non-Functional Requirements

-   NFR7.1 --- Save/load logic must be testable using GUT's temp-file
    helpers rather than the real `user://` save file, so test runs never
    overwrite the player's actual saved high score.
-   NFR7.2 --- Save/reload must round-trip exactly (the value written is
    the value read back), and a missing or first-run save file must be
    handled gracefully (default to `0`) without erroring.
-   NFR7.3 --- A score exactly equal to the current high score does
    **not** count as beating it --- `save_if_higher` only updates on a
    strictly greater score, avoiding a false "New High Score!" message
    on a tie.
-   NFR7.4 --- Restart is a **single coordinated call path**, not three
    independently-triggered resets that could race --- stale
    enemy/bullet nodes and any lingering banner overlays must be cleared
    *before* the fresh Level 1/Wave 1 spawn happens, so the player never
    briefly sees old-session and new-session state overlap.
-   NFR7.5 --- Terminology note for this doc: **"restart"**/**"Play
    Again"** refers to starting a new session from the Game Over screen
    without closing the app (FR7.8--FR7.10); **"app restart"** (FR7.7,
    NFR7.1) refers to fully closing and relaunching the app, which is
    what high-score persistence is actually tested against. The two are
    independent --- a session restart never touches disk, and an app
    restart never touches in-memory
    `GameManager`/`WaveManager`/`LevelManager` state (a fresh process
    starts that state at its defaults regardless).

### Out of Scope

-   Multiple/per-player high score profiles (Phase 12 stretch).
-   Any change to how `GameManager` computes or increments score during
    play (Phase 4, unchanged).

------------------------------------------------------------------------

## 2. Detailed Implementation Plan

1.  **`HighScoreManager.gd`** (autoload singleton):
    -   State: `high_score: int`, `save_path: String` (e.g.,
        `"user://highscore.json"` or a `ConfigFile` section).
    -   `_ready()`: calls `load_high_score()` so the value is available
        as soon as the game starts.
    -   `load_high_score()`: reads `save_path`; if the file doesn't
        exist or is malformed, defaults `high_score = 0` rather than
        raising an error.
    -   `get_high_score() -> int`: returns the cached `high_score`.
    -   `save_if_higher(score: int) -> bool`: if `score > high_score`,
        sets `high_score = score`, writes it to `save_path`, and returns
        `true`; otherwise returns `false` without writing to disk.
2.  **Wire into Game Over flow**: in the `game_over` signal handler
    introduced in Phase 4 (`Main.gd` or `GameOverScreen.gd`), call
    `HighScoreManager.save_if_higher(GameManager.score)` and branch the
    screen's messaging on the returned bool.
3.  **`GameOverScreen.tscn` update**: add a label/state that reads
    either "New High Score! `<score>`" (record beaten) or "Score:
    `<score>` • High Score: `<high_score>`" (record not beaten), sourced
    from `HighScoreManager.get_high_score()` after the
    `save_if_higher()` call.
4.  **HUD score styling**: apply the chosen font/iconography to the
    top-of-screen `ScoreLabel`, matching the visual language established
    by the HUD's other art-dressed elements (hearts, life icons,
    wave-progress text) from earlier phases --- no change to the
    underlying signal wiring from `GameManager`.
5.  **Add a single restart entry point**: implement
    `Main.gd.restart_session()` (or equivalent) as the *only* place
    restart is triggered from, called by the "Play Again" button's
    `pressed` signal. It runs, in order:
    1.  `WaveManager.clear_all()` --- `queue_free()` every remaining
        child of the `Enemies` and `Bullets` containers, and remove any
        lingering wave/level banner overlays.
    2.  `GameManager.reset_session()` --- sets `score = 0`,
        `lives = configured starting_lives`, `game_state = PLAYING`, and
        emits `score_changed`/`lives_changed`/`lives_changed` so the HUD
        repaints immediately.
    3.  `LevelManager.reset_and_start()` --- sets `current_level = 1`,
        recomputes `difficulty` for Level 1, builds the Level 1
        `category_sequence`, hands it to `WaveManager` (the same
        `set_category_sequence()` hand-off from Phase 6), and calls
        `WaveManager.start_wave("addition")`, producing a fresh 10-enemy
        formation.
    4.  Hide the `GameOverScreen` and re-enable `QuestionPanel` input.

    -   `HighScoreManager` is **not** called anywhere in this path
        (FR7.10) --- its state carries forward untouched from the
        session that just ended.
6.  **Write GUT tests** for `HighScoreManager` (see Testing Plan), using
    GUT's temp-file/temp-path helpers so the real
    `user://highscore.json` is never touched by the test suite. Also
    extend `test_game_manager.gd` (Phase 4) and `test_level_manager.gd`
    (Phase 6) to cover `reset_session()`/`reset_and_start()` in
    isolation, per the pattern Phase 8 already used to extend
    `test_level_manager.gd`.

------------------------------------------------------------------------

## 3. Testing Plan

### Automated Tests (GUT)

**`test_high_score_manager.gd`** - `save_if_higher(score)` updates
`high_score` and returns `true` when `score` is strictly greater than
the current stored value. - `save_if_higher(score)` leaves `high_score`
unchanged and returns `false` when `score` is less than or equal to the
current stored value (explicitly covers the tie case per NFR7.3). -
Save/reload round-trips correctly: after `save_if_higher()` writes a
value, a **new** `HighScoreManager` instance pointed at the same (temp)
path loads back the identical value via
`load_high_score()`/`get_high_score()`. - A missing save file (first
run) results in `get_high_score() == 0` without throwing an error. - A
malformed/corrupt save file is handled gracefully, falling back to a
default rather than crashing `load_high_score()`. - All of the above use
GUT's temp-file/temp-directory helpers to override `save_path` for the
duration of the test --- **the real `user://highscore.json` is never
read or written by the test suite**, per NFR7.1.

**`test_game_manager.gd` (extended, per NFR7.4/FR7.9)** -
`reset_session()` sets `score = 0`, `lives = configured starting_lives`,
and `game_state = PLAYING`, regardless of what state the values were in
beforehand (including from `GAME_OVER`). - `reset_session()` emits
`score_changed`/`lives_changed`/`lives_changed` exactly once each, so
the HUD is guaranteed to repaint.

**`test_level_manager.gd` (extended)** - After simulating advancement to
a later level (e.g., Level 4), calling `reset_and_start()` resets
`current_level` to 1 and recomputes `difficulty` back to the Level 1
value --- not left over from the prior session. - `reset_and_start()`
calls the stubbed `WaveManager`'s sequence-setting method with the Level
1 sequence and `start_wave("addition")`, mirroring the assertion already
used for ordinary level starts (Phase 6).

**Cross-cutting regression check** - `HighScoreManager`'s test suite is
unaffected by anything in the restart path --- no restart-related test
double or fixture touches `HighScoreManager`, confirming FR7.10 at the
test level, not just by convention.

### Manual Test Checklist

  ------------------------------------------------------------------------------
  \#                      Scenario                Expected Result
  ----------------------- ----------------------- ------------------------------
  1                       Play a session and beat Game Over screen shows "New
                          the existing high score High Score!" with the final
                                                  score

  2                       Restart the app after   The new high score is still
                          setting a new high      shown as current (persistence
                          score                   confirmed)

  3                       Play a session scoring  Game Over screen shows the
                          below the existing high final score alongside the
                          score                   existing (unchanged) high
                                                  score, no "New High Score!"
                                                  message

  4                       Play a session scoring  No "New High Score!" message
                          exactly equal to the    (tie does not count as beating
                          existing high score     it)

  5                       Fresh install / first   High score defaults to 0
                          run, no prior save file without any error or crash

  6                       Run full GUT suite      `test_high_score_manager.gd`
                                                  passes, 0 failures, alongside
                                                  all prior phases' passing
                                                  tests (no regressions), with
                                                  no modification to the real
                                                  save file

  7                       Play until reaching     Score and lives visibly reset
                          Level 3+ with some      to their starting values;
                          damage taken, then      Level indicator resets to 1; a
                          reach Game Over and tap fresh Addition wave of 10
                          "Play Again"            enemies spawns; no leftover
                                                  enemies, bullets, or banners
                                                  from the previous session are
                                                  visible

  8                       Immediately after Play  The high score is exactly what
                          Again, check the high   it was after the previous
                          score display/state     session ended (untouched by
                                                  the restart) --- it only
                                                  changes again if *this new*
                                                  session later beats it

  9                       Tap Play Again several  Each tap produces a clean
                          times in a row (without Level 1/Wave 1 reset with no
                          playing between taps)   accumulating leftover nodes or
                                                  drifting state
  ------------------------------------------------------------------------------

**Definition of Done:** the HUD score display is fully styled; high
scores persist correctly across **app** restarts; the Game Over screen
correctly distinguishes a new record from a non-record session; tapping
**Play Again** fully and cleanly resets `GameManager`, `LevelManager`,
and `WaveManager` to a fresh Level 1 session while leaving
`HighScoreManager`'s persisted value untouched; and all of the above ---
save/compare/round-trip logic plus the restart path --- are covered by
passing GUT tests that never touch the real `user://` save file.


## 4. Restart & Question Attempt Configuration

`Play Again` resets the session to Level 1, so the effective
`tries_per_question` also resolves again from the global setting plus the
Level 1 override, if any. It does not persist the prior level's attempt count
or current-question attempt counter. The level timer likewise restarts at
Level 1's resolved limit (`GameConfig.get_level_time_limit(1, wave_count)`)
--- a timer expiry that ended the previous session carries no penalty into
the new one.

The high score remains untouched.
