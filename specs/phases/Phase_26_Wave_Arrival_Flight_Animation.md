# Phase 26 --- Wave Arrival Flight Animation

**Goal:** replace the Phase 24 fade-in row reveal with a dynamic flight-in:
when a wave's formation spawns, its enemies zoom into the screen from above
the top edge of the frame along curved, fighter-jet-style paths, settling
into their formation positions. The frontmost (bottom) row arrives first,
then each row behind it, so the formation builds from the tip backward.

**Source docs:** Spec §15 (Wave Transition Pause & Arrival Animation),
Spec §2 (wave/level structure), Tech Stack §4 (`WaveManager`), Phase 24
(wave transition & timer pause), Phase 3 (wave structure).

---------------------------------------------------------------------------

## 1. Requirements

### Functional Requirements

-   FR26.1 --- When a wave's formation spawns (session start, Play Again,
    level advance, and after the wave-complete pause), enemies start
    off-screen above the top edge of the frame instead of appearing at
    their formation positions.
-   FR26.2 --- Each enemy flies into its formation position along a curved
    (quadratic bezier) path, not a straight line, giving a banking
    fighter-jet feel. The curve is deterministic (no randomness).
-   FR26.3 --- Rows arrive bottom-to-top: the frontmost tip row (row 3)
    launches first, then row 2, row 1, and finally the back row (row 0),
    at `ROW_ARRIVAL_SECONDS` intervals. This reverses the Phase 24
    top-to-bottom reveal order.
-   FR26.4 --- The first question of the wave is not shown until every
    enemy has reached its formation position (all flights complete). The
    question panel stays hidden for the whole arrival (Phase 24 FR24.2a),
    so no stale question is visible while the formation flies in.
-   FR26.5 --- The level timer remains frozen for the entire arrival and
    resumes with the first question (unchanged from Phase 24 FR24.5).
-   FR26.6 --- The flight path and timing are deterministic and
    unit-testable without the scene tree or a wall clock (Phase 24
    NFR24.1 pattern).

### Non-Functional Requirements

-   NFR26.1 --- No gameplay logic changes: formation layout, active-enemy
    ordering, and question flow are unchanged.
-   NFR26.2 --- The flight animation degrades gracefully for custom
    `enemies_per_wave` (overflow enemies belong to the last row and still
    fly in).
-   NFR26.3 --- The total arrival duration for the standard 4-row formation
    stays 2 s (3 row gaps at 0.5 s + a 0.5 s flight), preserving the
    Phase 24 timing contract.

### Out of Scope

-   Changing the formation layout or active-enemy ordering.
-   Changing the wave-complete pause or the level timer.
-   Any scoring changes.

---------------------------------------------------------------------------

## 2. Detailed Implementation Plan

1.  **`WaveManager.gd`:**
    -   Add `FLIGHT_START_Y` (above the top edge), `FLIGHT_SECONDS`, and
        `FLIGHT_CURVE_STRENGTH` constants.
    -   `_spawn_wave()`: spawn each enemy at its flight start position
        (off-screen above the frame) instead of its formation position,
        visible immediately, and store `formation_pos`, `flight_start`,
        and `flight_control` metadata per enemy.
    -   Replace the top-to-bottom `_reveal_row()` with a bottom-to-top
        `_launch_row()` that stamps each enemy's `flight_launch_time`.
    -   `tick()` ARRIVING state: launch rows bottom-to-top at
        `ROW_ARRIVAL_SECONDS` intervals, update every launched enemy's
        position along its bezier path each tick, and finish the transition
        only when all flights have completed.
    -   `_finish_transition()`: re-select the active enemy from the settled
        formation before emitting the first question.
2.  **GUT tests** alongside step 1 (see Testing Plan).

---------------------------------------------------------------------------

## 3. Testing Plan

### Automated Tests (GUT)

**`test_wave_manager.gd` (extended)** --- enemies spawn above the top edge
of the frame; rows launch bottom-to-top at `ROW_ARRIVAL_SECONDS` spacing;
the first question is not emitted until every flight completes; enemies end
at their exact formation positions; the flight path is curved (the bezier
control point is offset from the straight line); the sequence works for the
standard 4-row formation and for custom `enemies_per_wave`.

**Regression** --- full prior suite passes (NFR26.1).

### Manual Test Checklist

  -----------------------------------------------------------------------------
  \#                      Scenario                Expected Result
  ----------------------- ----------------------- -----------------------------
  1                       Start a fresh session   Enemies zoom in from above
                                                  the top edge along curved
                                                  paths, tip row first, then
                                                  rows behind it; first
                                                  question after the last
                                                  enemy settles

  2                       Clear a wave mid-level  After the 2 s pause, the
                                                  next wave flies in the same
                                                  way; timer stays frozen
                                                  until the first question

  3                       Watch the HUD timer     Timer does not tick during
                                                  the pause or the flight
                                                  animation; resumes with the
                                                  first question

  4                       Play Again              Same flight-in as a fresh
                                                  session

  5                       Configure a custom      Overflow enemies belong to
                          enemies_per_wave        the last row and still fly
                                                  in; no errors

  6                       Run full GUT suite       Updated tests + full prior
                                                  suite pass, 0 failures
  -----------------------------------------------------------------------------

**Definition of Done:** enemies fly into formation from above the top edge
along curved paths, the tip row arrives first and the back row last, the
first question waits for every enemy to settle, the timer is frozen for the
whole arrival, and the flight timing/path is covered by passing GUT tests.
