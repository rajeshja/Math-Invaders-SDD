# Phase 24 --- Wave Transition Animation & Timer Pause

**Goal:** give wave transitions a deliberate rhythm. When a wave is
cleared, the level timer pauses for a configurable 2 seconds (no question
shown), then the next wave's enemies arrive **one row at a time** (0.5 s
per row, 4 rows = 2 s for the standard formation) before the first
question appears. The timer is frozen for the entire transition, so the
player gets a breather and a look at the incoming formation without losing
level time.

**Source docs:** Spec §15 (Wave Transition Pause & Arrival Animation),
Spec §2 (wave/level structure), Spec §10 (level time limit), Tech Stack §4
(`WaveManager`), §5 (`GameManager`), Phase 3 (wave structure), Phase 5
(level timer).

-----------------------------------------------------------------------

## 1. Requirements

### Functional Requirements

-   FR24.1 --- New game-wide Project Setting
    `gameplay/wave_complete_pause_seconds` (Float, default `2.0`, minimum
    `0`), read only through `GameConfig.get_wave_complete_pause_seconds()`.
-   FR24.2 --- When a wave is cleared, the level timer pauses and no
    question is shown for `wave_complete_pause_seconds`.
-   FR24.3 --- After the pause, the next wave's enemies spawn and animate
    into formation **one row at a time**. Each row takes
    `WaveManager.ROW_ARRIVAL_SECONDS` (0.5 s); the standard 4-row
    formation takes 2 s total. Rows arrive bottom-to-top (3, then 2, then
    1, then 0) as a curved flight-in animation (Phase 26 FR26.3).
-   FR24.4 --- The first question of the new wave is not shown until every
    row has arrived.
-   FR24.5 --- The level timer is paused for the **entire** wave
    transition (pause + arrival) and resumes when the new wave's first
    question is shown.
-   FR24.6 --- The "Wave Complete!" banner still shows during the
    transition; the arrival animation is presentational and enemies are
    not answerable until all rows have arrived.
-   FR24.7 --- The row-by-row arrival animation also plays when a new
    wave's formation spawns at session start and on Play Again (no
    completion pause in those cases).

### Non-Functional Requirements

-   NFR24.1 --- The transition timing (pause duration, per-row duration,
    total) is deterministic and unit-testable without the scene tree or a
    wall clock.
-   NFR24.2 --- No gameplay logic changes beyond timing: formation
    layout, active-enemy ordering, and question flow are unchanged.
-   NFR24.3 --- The arrival animation degrades gracefully for custom
    `enemies_per_wave` (overflow enemies belong to the last row).

### Out of Scope

-   Changing the formation layout or active-enemy ordering.
-   Per-level pause overrides (the pause is game-wide only).
-   Any scoring changes (Phase 25).

-----------------------------------------------------------------------

## 2. Detailed Implementation Plan

1.  **`GameConfig.gd`:** add `WAVE_COMPLETE_PAUSE_SETTING`,
    `DEFAULT_WAVE_COMPLETE_PAUSE := 2.0`, and
    `get_wave_complete_pause_seconds() -> float` (clamped ≥ 0).
2.  **`GameManager.gd`:** add a `transitioning: bool` flag and
    `set_transition_active(active: bool)`; `tick()` returns early while
    `transitioning` so the level timer freezes (FR24.5).
3.  **`WaveManager.gd`:**
    -   Add `ROW_ARRIVAL_SECONDS := 0.5`.
    -   Split `start_wave()` so spawning and the first-question emit are
        separable: enemies spawn hidden/off-screen and the first question
        is emitted only after the arrival sequence (FR24.4).
    -   Add the arrival sequence: reveal each formation row in order,
        `ROW_ARRIVAL_SECONDS` apart (top-to-bottom), then emit the first
        question.
    -   `_on_wave_clear()` no longer calls `start_wave()` directly; it
        runs the transition sequence: set transition active → await
        `wave_complete_pause_seconds` → spawn the next wave → arrival
        sequence → clear transition → emit the first question.
4.  **`Main.gd`:** the existing `wave_cleared` handler still shows the
    banner; answer input is naturally disabled because no question is
    shown during the transition.
5.  **GUT tests** alongside steps 1--3 (see Testing Plan).

-----------------------------------------------------------------------

## 3. Testing Plan

### Automated Tests (GUT)

**`test_game_manager.gd` (extended)** --- `tick()` is a no-op while
`transitioning`; the timer resumes after `set_transition_active(false)`;
`time_remaining` is unchanged across a simulated transition.

**`test_wave_manager.gd` (extended)** --- the transition sequence waits
the configured pause before spawning the next wave; rows arrive in order
with `ROW_ARRIVAL_SECONDS` spacing; the first question is not emitted
until the arrival completes; the sequence works for the standard 4-row
formation and for custom `enemies_per_wave`.

**Regression** --- full prior suite passes unmodified (NFR24.2).

### Manual Test Checklist

  -----------------------------------------------------------------------------
  \#                      Scenario                Expected Result
  ----------------------- ----------------------- -----------------------------
  1                       Clear a wave mid-level  "Wave Complete!" banner
                                                  shows; timer freezes; no
                                                  question for 2 s

  2                       After the pause         Next wave's enemies arrive
                                                  row by row (top row first),
                                                  ~0.5 s per row; first
                                                  question appears only after
                                                  the last row

  3                       Watch the HUD timer     Timer does not tick during
                          during the transition   the pause or the arrival
                                                  animation; resumes with the
                                                  first question

  4                       Start a fresh session   First wave's enemies arrive
                                                  row by row (no 2 s pause);
                                                  first question after arrival

  5                       Play Again              Same row-by-row arrival as a
                                                  fresh session

  6                       Configure the pause to   Pause length matches the
                          0 / 5 seconds           configured value; arrival
                                                  animation unchanged

  7                       Run full GUT suite       Updated tests + full prior
                                                  suite pass, 0 failures
  -----------------------------------------------------------------------------

**Definition of Done:** clearing a wave pauses the level timer for the
configured duration with no question shown, the next wave's enemies arrive
one row at a time before the first question appears, the timer is frozen
for the entire transition, and the transition timing is covered by passing
GUT tests.
