# Phase 14 --- Fraction Multiplication & Division Strategies

**Goal:** complete the four fraction operations by adding
`fraction_multiplication` and `fraction_division`, reusing the
`FractionValue` helper, canonical answer strings, and stacked rendering
landed in Phase 13. Multiplication scales difficulty through operand
size and cross-simplification opportunities; division scales through
reciprocal reasoning with unit-fraction-friendly tiers; both keep the
Phase 13 guarantees --- simplified results, value-distinct choices,
mixed/improper representation mix, stacked display.

**Source docs:** Build Plan §Phase 14, Spec §5 (Stage C), §12 (category
registry & answer-value model), Tech Stack §3, Phase 13 FRs 13.1--13.11
(foundation being reused).

------------------------------------------------------------------------

## 1. Requirements

### Functional Requirements

-   FR14.1 --- `fraction_multiplication_strategy.gd` and
    `fraction_division_strategy.gd` are added under
    `scripts/questions/strategies/`, registered under keys
    `"fraction_multiplication"` / `"fraction_division"` with display
    names "Fraction Multiplication" / "Fraction Division" (Spec §12).
    Both reuse `FractionValue` (no local gcd/reduction logic) and return
    the extended question Dictionary shape from Phase 13 (canonical
    string answers + `answer_layout` for stacked rendering).
-   FR14.2 --- Both strategies inherit every Phase 13 guarantee: exactly
    one correct choice among 4 unique choices; no distractor value-equal
    to the correct answer or another distractor (checked on simplified
    form); every result fully simplified; subtraction-free but division
    divisors never zero and operands' denominators never zero.
-   FR14.3 --- **Multiplication difficulty ladder:**
    -   **Tier 1:** proper fraction × whole number with canceling
        structure (e.g., `1/2 × 6`), or two unit-ish fractions with
        obvious cross-cancel.
    -   **Tier 2:** proper × proper with small numerators (≤ 9);
        cross-simplification optional but result must be simplified.
    -   **Tier 3:** one operand mixed number (converted internally to
        improper before multiplying); larger numerators/denominators;
        cross-cancel becomes the efficient path.
    -   **Tier 4+:** both operands may be mixed/improper; results may be
        improper → simplified and rendered per the question's chosen
        representation (improper-stacked or mixed, consistent across all
        four choices).
-   FR14.4 --- **Division difficulty ladder:**
    -   **Tier 1:** whole ÷ unit fraction and unit fraction ÷ whole
        (e.g., `3 ÷ 1/4`), reciprocal concept in its friendliest form;
        results whole or unit fractions.
    -   **Tier 2:** unit ÷ unit and simple proper ÷ proper where the
        divisor's numerator is 1 after simplification-friendly structure
        is arranged; results simplify cleanly.
    -   **Tier 3:** general proper ÷ proper (multiply-by-reciprocal
        required); operands may include mixed numbers.
    -   **Tier 4+:** mixed ÷ mixed and improper-involved items; larger
        magnitudes; results simplified, representation-mixed as above.
    Division questions render with the `÷` symbol; no complex-fraction
    (fraction-over-fraction) notation is required in this phase.
-   FR14.5 --- Distractors model real student errors: multiplying/
    dividing straight across WITHOUT simplifying pressure applied to a
    *different* wrong pairing (e.g., multiplying numerators but dividing
    denominators), inverting the wrong operand in division, off-by-one
    numerator or denominator, using an add/subtract-across result, and
    whole-number-only results when fractional parts were dropped.
    Un-simplified equivalents of the true answer remain forbidden
    (value-equality rule).
-   FR14.6 --- New category sprites
    `enemy_ship_fraction_multiplication.png` /
    `enemy_ship_fraction_division.png` (96×96,
    placeholder-acceptable) are added under `assets/images/enemies/`
    and wired into `enemy.gd`'s texture map.
-   FR14.7 --- Level authoring: a level's `.tres` gains
    `fraction_multiplication` / `fraction_division` waves (recommended:
    Level 4, following the Level 3 fraction debut), keeping integer
    waves ahead of them so the sequence reads as a progression.
    Final pacing/tuning belongs to Phase 20.

### Non-Functional Requirements

-   NFR14.1 --- No scene-tree dependency in either strategy; all logic
    GUT-testable in isolation (Tech Stack §9).
-   NFR14.2 --- **Zero edits** to `fraction_addition_strategy.gd`,
    `fraction_subtraction_strategy.gd`, `fraction_value.gd`'s existing
    API surface (additions allowed if genuinely shared), or any integer
    strategy --- extensibility check per Tech Stack §3.
-   NFR14.3 --- Rendering changes: none expected. If any
    `question_panel.gd` change proves necessary it must preserve
    Phase 13's touch-target/flash/safe-area behavior and be justified in
    review.

### Out of Scope

-   Decimal categories (Phase 15).
-   Ratio/proportion and HCF/LCM (Phase 16).
-   Complex-fraction notation, fraction-to-decimal conversion items.

------------------------------------------------------------------------

## 2. Detailed Implementation Plan

1.  **`fraction_multiplication_strategy.gd`**: implement the FR14.3
    ladder --- construct operands so Tier-appropriate canceling
    structures exist (pick factor pairs first, mirroring how
    `integer_division` picks divisor/quotient first); multiply
    numerators/denominators on ints; simplify via `FractionValue`;
    choose representation; build distractors per FR14.5.
2.  **`fraction_division_strategy.gd`**: implement the FR14.4 ladder ---
    generate divisor first (nonzero), compute the true product with the
    reciprocal, simplify; same assembly path.
3.  **Register** both categories (generator map + display names) and
    wire the two new enemy sprites (FR14.6).
4.  **Author levels** (FR14.7): extend the target `.tres` sequences;
    raise `time_limit_seconds` if wave count grew.
5.  **GUT tests** alongside each step (see Testing Plan).

------------------------------------------------------------------------

## 3. Testing Plan

### Automated Tests (GUT)

**`test_fraction_multiplication_strategy.gd`** --- marked-correct choice
equals the true simplified product (verified via `FractionValue` against
an independent reference computation in the test); exactly one
value-correct choice; pairwise value-distinct choices; always fully
simplified (GCD == 1); Tier 1 items contain at least one whole-number or
unit-fraction operand; Tier 3+ includes mixed-number operands; Tier 4+
yields some improper results rendered consistently; `answer_layout`
matches displayed choices.

**`test_fraction_division_strategy.gd`** --- same shape; additionally:
divisor never zero; marked-correct equals dividend × reciprocal
(simplified); Tier 1 restricted to whole/unit-fraction structures;
higher tiers include mixed operands; no negative values anywhere.

**`test_question_generator.gd` (extended)** --- dispatches for both new
keys.

**Regression** --- Phase 13's suites and the full prior suite pass
unmodified (NFR14.2 verified by diff: no edits to foundation files'
logic).

### Manual Test Checklist

  -------------------------------------------------------------------------------
  \#                      Scenario                Expected Result
  ----------------------- ----------------------- -------------------------------
  1                       Play a multiplication   Stacked fractions throughout;
                          wave                    e.g., `1/2 × 6` style Tier 1
                                                  items read clearly; answers
                                                  simplified (`3`, not `6/2`)

  2                       Play a division wave    `3 ÷ 1/4` style items present
                                                  early; later items need
                                                  multiply-by-reciprocal; `÷`
                                                  symbol used, no
                                                  fraction-over-fraction stacks

  3                       Answer wrong            Red flash on tapped button,
                          deliberately            mistake logged with readable
                                                  fraction text; life consumed
                                                  exactly once

  4                       Inspect several         All four choices share one
                          multi-step items        representation (all improper-
                                                  stacked or all mixed) so format
                                                  never reveals the answer

  5                       Run full GUT suite      New tests + full prior suite
                                                  pass, 0 failures
  -------------------------------------------------------------------------------

**Definition of Done:** all four fraction operations exist as
registered strategies with tiered, unlike-skill difficulty ladders,
simplified value-distinct answers, stacked display, category sprites,
authored waves, and full green GUT coverage --- with zero logic edits
to the Phase 13 foundation.
