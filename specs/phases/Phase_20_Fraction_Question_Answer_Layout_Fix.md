# Phase 20 --- Fraction Question & Answer Layout Fix

**Goal:** fix stacked-fraction rendering so fraction questions and answer
buttons are **centered** (not left-aligned) and the question area has
enough room that it no longer overlaps the answer buttons --- while
preserving the 360px panel height, the Phase 11 safe-area behavior, and
the plain-text integer question path exactly as before.

**Source docs:** Build Plan §Phase 20, Spec §5 (clear fraction display
--- authoritative), §3 (screen layout --- question panel), Tech Stack §5
(`question_panel.gd`), Phase 13 FR13.3--FR13.5 (stacked-fraction
rendering foundation).

> Renumbering note: this phase was inserted between the completed Phase 19
> and the former Phase 20 (Playtesting & Balancing, now **Phase 25**).
> Phases 0--19 are untouched and remain implemented as shipped.

-----------------------------------------------------------------------

## 1. Requirements

### Functional Requirements

-   FR20.1 --- **Centered answer-button fractions.** The stacked-fraction
    control added to each answer button must fill the button and center
    its content both horizontally and vertically, instead of sitting at
    the button's top-left corner. Root cause: the fraction control was
    added to a plain `Button` (a `Control`, not a `Container`) without
    anchors, so `ALIGNMENT_CENTER` only centered within the control's own
    content-sized box. Fix: set the control's anchors to
    `PRESET_FULL_RECT` so it fills the 320×110 button and its
    `ALIGNMENT_CENTER` takes effect.
-   FR20.2 --- **Centered question text.** The stacked-fraction question
    host must span the panel width and center its segments, so a fraction
    question reads centered (matching the plain-text `QuestionLabel`,
    which already centers). Fix: give the host
    `size_flags_horizontal = SIZE_EXPAND_FILL` on top of its existing
    `PRESET_TOP_WIDE` anchors and `ALIGNMENT_CENTER`.
-   FR20.3 --- **More question space / no overlap.** Redefine the question
    panel layout so the question area is taller and the answer grid is
    moved down, eliminating the overlap between the question area and the
    answer buttons:
    -   Question row (both the `QuestionLabel` in the scene and the
        code-built question stack host): `offset_top 16 → 8`,
        `offset_bottom 76 → 88` (80px, up from 60px).
    -   Answer grid: `offset_top -110 → -85`, `offset_bottom 130 → 155`
        so the buttons sit at y 95--335, clear of the question row
        (88 < 95).
-   FR20.4 --- **Panel height & safe area preserved.** The panel stays
    360px tall (`PANEL_HEIGHT` and the scene's `offset_top = -360`
    unchanged) and `_apply_safe_area()` keeps lifting the whole panel by
    the bottom inset and insetting it from the left/right insets. The new
    internal layout (question 8--88, grid 95--335) sits entirely within
    the 360px panel, so it stays clear of the safe-area lift on notched
    phones. No safe-area code changes.

### Non-Functional Requirements

-   NFR20.1 --- Integer (plain-text) questions render exactly as before:
    the `QuestionLabel` path is untouched, and the answer buttons fall
    back to plain text when no `answer_layout` is present.
-   NFR20.2 --- Touch targets, theme styleboxes, the wrong-answer red
    flash, and `mouse_filter = IGNORE` on all fraction widgets are
    preserved (Phase 13 FR13.4).
-   NFR20.3 --- With no fraction questions shown, visuals are identical to
    Phase 19 (regression-protected by the unmodified GUT suite).

### Out of Scope

-   Any change to fraction question *generation*, simplification, or
    answer-value logic (Phases 13--14) --- this phase is presentation/layout
    only.
-   Redesigning the panel's overall height, button size, or the
    inverted-triangle formation.
-   New fraction rendering features (e.g., diagonal fraction bars,
    auto-shrinking for very large denominators).

-----------------------------------------------------------------------

## 2. Detailed Implementation Plan

1.  **`question_panel.gd` — `_build_button_stack`:** after building the
    fraction control, set its anchors to fill the button so its content
    centers:
    ```gdscript
    func _build_button_stack(layout: Dictionary) -> Control:
        var control := _build_fraction_control(layout, STACK_FONT_LARGE)
        control.set_anchors_preset(Control.PRESET_FULL_RECT)
        return control
    ```
    The `row` already has `ALIGNMENT_CENTER` (horizontal) and the inner
    `stack` has `ALIGNMENT_CENTER` (vertical); filling the 320×110 button
    centers the fraction both ways (FR20.1).
2.  **`question_panel.gd` — `_build_question_stack_host`:** add
    `_question_stack_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL`
    so the host reliably spans the panel width and `ALIGNMENT_CENTER`
    centers the segments (FR20.2).
3.  **`question_panel.gd` — question stack host offsets:** change
    `offset_top`/`offset_bottom` from `16.0`/`76.0` to `8.0`/`88.0` to
    mirror the scene (FR20.3).
4.  **`scenes/question_panel.tscn`:** update the `QuestionLabel` offsets
    (`offset_top 16 → 8`, `offset_bottom 76 → 88`) and the `AnswerButtons`
    grid offsets (`offset_top -110 → -85`, `offset_bottom 130 → 155`)
    (FR20.3).
5.  **Verify safe area / panel height:** confirm `PANEL_HEIGHT = 360`
    still matches the scene and that `_apply_safe_area()` is unchanged
    (FR20.4). No edits expected.
6.  **GUT tests** alongside steps 1--2 (see Testing Plan).

-----------------------------------------------------------------------

## 3. Testing Plan

### Automated Tests (GUT)

-   **Regression bar:** the full existing GUT suite (all strategy tests,
    `question_generator`, `WaveManager`, `LevelManager`, `GameManager`,
    `HighScoreManager`, `LevelConfig`, save-data tests) passes with 0
    failures. This phase touches only `question_panel.gd` and
    `question_panel.tscn`; no strategy or game-state logic changes, so the
    existing suite is expected to pass unmodified (NFR20.3).
-   **Panel layout (light, optional):** a headless test can assert that
    `_build_button_stack` returns a control whose anchors are
    `PRESET_FULL_RECT` and that the question stack host's
    `size_flags_horizontal` includes `SIZE_EXPAND_FILL`, guarding the
    centering fix against regression.

### Manual Test Checklist

  -------------------------------------------------------------------------------
  \#                      Scenario                Expected Result
  ----------------------- ----------------------- -------------------------------
  1                       Play a fraction wave    The question reads centered in
                          (e.g., fraction          the question row, not hugging
                          addition)                the left edge

  2                       Inspect the four        Each answer button shows its
                          answer buttons          fraction centered both
                                                  horizontally and vertically

  3                       Play an integer wave    Plain-text questions and
                          (e.g., integer           buttons render exactly as
                          addition)                before (NFR20.1)

  4                       Check the question       No overlap between the
                          row vs. the answer       question text and the top row
                          grid                     of answer buttons

  5                       Run on a notched         Panel lifts above the home
                          phone / safe area        indicator; question and
                                                  buttons stay clear and
                                                  tappable (FR20.4)

  6                       Tap a wrong answer       Red flash still works on the
                          on a fraction            fraction button; touch target
                          question                 unchanged (NFR20.2)

  7                       Run full GUT suite       0 failures across the full
                                                  existing suite
  -------------------------------------------------------------------------------

**Definition of Done:** fraction questions and answer buttons render
centered and readable with no overlap between the question area and the
answer grid; integer questions are visually unchanged; the 360px panel
height and safe-area behavior are preserved; and the full GUT suite
passes.
