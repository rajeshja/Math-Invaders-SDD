# Phase 25 --- Points Bonus And Penalty

**Goal:** reward finishing a level early and penalize losing lives, applied
as per-level scoring adjustments at level completion. Completing a level
with time to spare awards bonus points (1 per full 5 seconds remaining by
default); each life lost during a level deducts a penalty (1 point per life
by default).

**Source docs:** Spec §16 (Level Completion Bonus & Penalty), Spec §4 (core
loop step 9), Spec §7 (project settings), Tech Stack §5 (`LevelManager`),
Phase 6 (level progression), Phase 17 (points per question).

-----------------------------------------------------------------------

## 1. Requirements

### Functional Requirements

-   FR25.1 --- New game-wide Project Settings
    `gameplay/bonus_seconds_per_point` (Float, default `5.0`, minimum
    `1.0`) and `gameplay/lives_lost_penalty_points` (Integer, default
    `1`, minimum `0`), read only through `GameConfig`.
-   FR25.2 --- Completing a level with time remaining awards an
    early-finish bonus: `floor(time_remaining / bonus_seconds_per_point)`
    points (default 1 point per full 5 seconds remaining).
-   FR25.3 --- Each life lost during a level deducts
    `lives_lost_penalty_points` (default 1 point per life) from that
    level's score.
-   FR25.4 --- Both adjustments are applied at level completion:
    `level_score = max(0, earned + bonus - penalty)`, where `earned` =
    correct answers × `points_per_question`.
-   FR25.5 --- The adjusted `level_score` is what is recorded as the
    level's personal best and what is added to the running total (the
    running total never goes below 0).
-   FR25.6 --- Lives lost in a level that is NOT completed (game over)
    are not penalized, and the bonus does not apply to an incomplete
    level.

### Non-Functional Requirements

-   NFR25.1 --- The bonus/penalty math is deterministic and unit-testable
    without the scene tree.
-   NFR25.2 --- No gameplay changes beyond scoring: questions, difficulty,
    lives, and timing are untouched.
-   NFR25.3 --- Personal bests, assumed full score, and high scores
    continue to operate on totals (Phase 17 note) and need no schema
    changes.

### Out of Scope

-   Changing lives, timing, or question generation.
-   Per-level bonus/penalty overrides (game-wide only).
-   Any animation/timing changes (Phase 24).

-----------------------------------------------------------------------

## 2. Detailed Implementation Plan

1.  **`GameConfig.gd`:** add `BONUS_SECONDS_PER_POINT_SETTING`,
    `LIVES_LOST_PENALTY_SETTING`, their defaults, and getters
    `get_bonus_seconds_per_point() -> float` and
    `get_lives_lost_penalty_points() -> int` (safe fallbacks on missing or
    invalid values).
2.  **`LevelManager.gd`:** in `on_all_waves_complete()`, before
    `_record_level_result()`:
    -   `bonus = floor(GameManager.time_remaining /
        GameConfig.get_bonus_seconds_per_point())`
    -   `penalty = _lives_lost_this_level *
        GameConfig.get_lives_lost_penalty_points()`
    -   `level_score = max(0, (GameManager.score - _score_at_level_start)
        + bonus - penalty)`
    -   Apply the net adjustment `bonus - penalty` to
        `GameManager.score` (clamped so the total never goes below 0),
        emitting `score_changed`.
    -   Record `level_score` as the personal best (instead of the raw
        delta).
3.  **GUT tests** alongside steps 1--2 (see Testing Plan).

-----------------------------------------------------------------------

## 3. Testing Plan

### Automated Tests (GUT)

**`test_level_manager.gd` (extended)** --- bonus equals
`floor(time_remaining / seconds_per_point)`; penalty equals
`lives_lost × points`; `level_score` is clamped at 0; the personal best is
recorded from the adjusted score; the running total is updated by the net
adjustment and never goes negative; a game-over (incomplete) level applies
neither bonus nor penalty.

**`test_game_config.gd` (extended)** --- the new settings resolve with
their defaults and fall back safely on missing/invalid values.

**Regression** --- full prior suite passes unmodified (NFR25.2).

### Manual Test Checklist

  -----------------------------------------------------------------------------
  \#                      Scenario                Expected Result
  ----------------------- ----------------------- -----------------------------
  1                       Complete a level with   Bonus points added at level
                          12 s remaining          completion (2 points with
                                                  the default 5 s/point)

  2                       Complete a level with   No bonus (0 points) with the
                          < 5 s remaining         default rate

  3                       Complete a level after  Penalty deducted (1 point
                          losing 2 lives          per life lost) at level
                                                  completion

  4                       Lose more lives than    Level score clamps to 0;
                          points earned           running total never goes
                                                  negative

  5                       Game over mid-level     No bonus/penalty applied to
                                                  the incomplete level

  6                       Check personal bests    The adjusted level score is
                                                  what is recorded

  7                       Run full GUT suite       Updated tests + full prior
                                                  suite pass, 0 failures
  -----------------------------------------------------------------------------

**Definition of Done:** finishing a level early awards bonus points and
losing lives deducts penalty points at level completion, the adjusted level
score is recorded as the personal best and reflected in the running total
(never negative), and the scoring math is covered by passing GUT tests.
