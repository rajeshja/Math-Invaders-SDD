# Phase 17 --- Configurable Points Per Question Per Level

**Goal:** let each level award its own number of points for a correct
answer instead of the hardcoded `+1` per answer. The value lives in the
level's `LevelConfig.tres` (continuing Phase 9's direction that
per-level tuning belongs in Inspector-editable resources, not Project
Settings or code). Default `1` preserves every existing score total,
personal best, and high score.

**Source docs:** Build Plan §Phase 17, Spec §11 (Level Configuration),
§13 (Visual & Scoring Level Configuration --- authoritative), Tech
Stack §4 (`LevelManager`/`LevelConfig` flow), §6 (settings ownership
note: per-level values live in resources).

------------------------------------------------------------------------

## 1. Requirements

### Functional Requirements

-   FR17.1 --- `LevelConfig.gd` gains an exported scoring field:
    `@export var points_per_question: int = 1` in a "Scoring" export
    group, editable in the Godot Inspector per level (NFR9.1
    continuity).
-   FR17.2 --- Validation: values below 1 are clamped to `1` at
    resolution time with a one-time `push_warning`; there is no zero-
    or negative-scoring configuration.
-   FR17.3 --- `LevelManager` resolves the effective value once at
    level start (alongside `effective_tries_per_question`) and exposes
    it (e.g., `effective_points_per_question`); `Main._resolve_correct_answer()`
    calls `GameManager.add_score(effective_points_per_question)`
    instead of the hardcoded `add_score(1)`. Wrong answers never score.
-   FR17.4 --- The value applies uniformly to every correct answer in
    that level across all waves/categories --- no per-wave or
    per-category point values in this phase.
-   FR17.5 --- Downstream scoring systems are structurally unchanged
    and must keep working: HUD score display (`score_changed`),
    Game Over final score, `HighScoreManager.save_if_higher`,
    personal bests recorded from the level score delta
    (`LevelManager._record_level_result`), and assumed-full-score on
    level skip. They all operate on totals, so they inherit the new
    per-answer values automatically; this phase verifies rather than
    modifies them.
-   FR17.6 --- Level authoring: existing five `.tres` files gain the
    field with sensible defaults (recommended: Level 1 stays `1`;
    later levels rise modestly as categories get harder --- exact
    values are authoring detail tuned in Phase 20). Levels beyond the
    defined set reuse the last config's shape (existing
    `resolved_config_for` behavior), so overflow levels keep that
    config's point value plus their raised difficulty.

### Non-Functional Requirements

-   NFR17.1 --- With every level left at the default `1`, all score
    behavior is byte-identical to Phase 16 (regression-protected by
    existing suites running unmodified).
-   NFR17.2 --- No new signals, autoloads, or Project Settings: the
    change is one resource field + one resolution + one call-site edit.
-   NFR17.3 --- `GameManager.add_score(amount)` keeps its default of
    `1`; callers pass explicitly.

### Out of Scope

-   Score multipliers, combos, time-bonuses, or negative scoring.
-   Changing high-score persistence format (totals only; schema
    untouched).

------------------------------------------------------------------------

## 2. Detailed Implementation Plan

1.  **`LevelConfig.gd`**: add the export group + field (FR17.1) and a
    `resolved_points_per_question()` helper performing the FR17.2
    clamp/warn so validation lives in one place.
2.  **`LevelManager.gd`**: capture the resolved value in
    `start_level()` next to the other effective values (FR17.3).
3.  **`main.gd`**: swap `GameManager.add_score(1)` for the resolved
    value (FR17.3).
4.  **`.tres` authoring** (FR17.6): add the field to the five level
    files with chosen defaults.
5.  **GUT tests**: extend `test_level_config.gd` (default, clamp,
    round-trip through a `.tres` fixture) and add a Main-flow-level
    case asserting two correct answers at `points_per_question = 3`
    yield `+6` while the default path still yields `+2`
    (see Testing Plan).

------------------------------------------------------------------------

## 3. Testing Plan

### Automated Tests (GUT)

**`test_level_config.gd` (extended)** --- default value is `1` on a
freshly constructed resource; `resolved_points_per_question()` clamps
`0`/negative to `1` and warns; a fixture `.tres` with a non-default
value loads it intact.

**Main-flow / scoring test (new or extended)** --- drive correct-answer
resolution against a stubbed signal listener: configured value applied
per correct answer; wrong answers never score; switching levels applies
each level's own value at its boundary (the same session can carry two
different values across `start_level()` calls).

**Regression** --- full prior suite passes unmodified (NFR17.1: defaults
preserve totals; personal-best and assumed-score tests must not need
edits).

### Manual Test Checklist

  -------------------------------------------------------------------------------
  \#                      Scenario                Expected Result
  ----------------------- ----------------------- -------------------------------
  1                       Set Level 1 to          Correct answers show the HUD
                          points_per_question=3   jumping by 3; everything else
                          in the Inspector, play  unchanged
                          a few correct answers

  2                       Complete that level     Personal best records the
                                                  earned delta; Play Again starts
                                                  from the same assumed base

  3                       Set an invalid value    Warning logged once; game runs
                          (e.g., 0)               with 1 point per answer

  4                       Revert to defaults and  Score behaves exactly as before
                          run full GUT suite      the phase (0 failures)
  -------------------------------------------------------------------------------

**Definition of Done:** each level awards its configured points per
correct answer through a single validated resolution path, downstream
score consumers verified untouched, defaults preserve all prior score
behavior, and the full GUT suite passes.
