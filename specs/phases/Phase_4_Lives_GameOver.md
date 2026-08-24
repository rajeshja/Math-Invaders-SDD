# Phase 4 --- Lives and Game Over

**Goal:** give wrong answers their real consequence --- one life lost
per incorrect answer --- and add the Game Over state. The player has a
configurable mistake budget rather than a health pool.

**Source docs:** Build Plan §Phase 4, Spec §4 (core loop and life
depletion), §6 (HUD lives requirement), §7 (`life_icon.png`,
`game_over_bg.png`), Tech Stack §5 (GameManager), §6 (Project Settings),
§9 (testing strategy).

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

### Out of Scope

-   Level progression and level-boundary lives reset (Phase 5).
-   High score persistence and Play Again wiring (Phase 6).
-   Visual/audio polish (Phase 8).

------------------------------------------------------------------------

## 2. Detailed Implementation Plan

1.  **`GameConfig.gd`**: expose `get_starting_lives() -> int` from
    `gameplay/starting_lives`, defaulting safely to 3 if the setting is
    missing or invalid.
2.  **`GameManager.gd`**:
    -   State: `score: int`, `lives: int`, `starting_lives: int`,
        `game_state: enum { PLAYING, PAUSED, GAME_OVER }`.
    -   `take_damage(amount: int = 1)`: while `PLAYING`, consume the
        requested life amount, clamped so lives cannot go below 0; for
        the current gameplay contract all wrong answers call it with
        `1`.
    -   `lose_life()` / equivalent: decrement one life, emit
        `lives_changed`, and if lives reaches 0 set `GAME_OVER` and emit
        `game_over` exactly once.
    -   `reset_session()`: restore score to 0, lives to configured
        starting lives, and `PLAYING`.
3.  **Wire the wrong-answer event**: `QuestionPanel`/the gameplay
    controller reports the incorrect answer once; the authoritative
    game-state path calls `GameManager.take_damage(1)`. The current
    question remains selected.
4.  **HUD**: replace any health/heart display with a lives display using
    repeated `life_icon.png`.
5.  **Game Over screen**: connect to `game_over`, disable
    `QuestionPanel` input, and show the final score.
6.  **Remove old descent damage**: delete/disable any code that moves
    enemies downward on wrong answers or triggers damage when an enemy
    reaches the bottom.
7.  **Write GUT tests** for `GameManager` and `GameConfig`.

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

  8                       Run full GUT suite          0 failures
  ---------------------------------------------------------------------------

**Definition of Done:** every wrong answer consumes exactly one
configured life and flashes the selected answer red; with the default one
attempt, the next question is loaded after the feedback, while higher
per-level attempt overrides permit additional attempts on the same question.
The game ends when lives reach zero, and the lives/attempt state machine is
covered by passing GUT tests.


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
