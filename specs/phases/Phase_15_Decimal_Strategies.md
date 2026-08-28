# Phase 15 --- Decimal Addition, Subtraction, Multiplication & Division Strategies

**Goal:** add the four decimal strategies --- `decimal_addition`,
`decimal_subtraction`, `decimal_multiplication`, `decimal_division` ---
as one coherent phase. They are individually simple but share one
critical piece of machinery: exact **scaled-integer arithmetic** (never
binary floats) plus a canonical decimal formatting rule. Difficulty
scales along the existing `max_decimal_places` LevelConfig knob and
operand magnitude.

Decimals render as plain text (no stacked layout needed), so this phase
is presentation-light and leans on the Phase 13 answer-value model:
answers are canonical decimal strings compared by exact equality.

**Source docs:** Build Plan §Phase 15, Spec §5 (Stage C), §12 (category
registry & answer-value model), Tech Stack §3, Phase 9 FR9.3
(`max_decimal_places` knob already exists in `LevelConfig`), Phase 13
FR13.1/FR13.2 (answer-value model being reused).

------------------------------------------------------------------------

## 1. Requirements

### Functional Requirements

-   FR15.1 --- `decimal_addition_strategy.gd`,
    `decimal_subtraction_strategy.gd`, `decimal_multiplication_strategy.gd`,
    and `decimal_division_strategy.gd` are added under
    `scripts/questions/strategies/`, registered under keys
    `"decimal_addition"`, `"decimal_subtraction"`,
    `"decimal_multiplication"`, `"decimal_division"` with display names
    "Decimal Addition", "Decimal Subtraction", "Decimal Multiplication",
    "Decimal Division" (Spec §12).
-   FR15.2 --- **Scaled-integer arithmetic is mandatory:** every
    strategy computes on integers scaled by a power of ten (e.g., work
    in tenths/hundredths) and formats back to a string at the end.
    Binary floating-point arithmetic must not decide any correct
    answer. A shared formatting helper (suggested:
    `scripts/questions/support/math_format.gd`, or an extension of the
    Phase 13 support folder) owns scale/format logic for all four
    strategies.
-   FR15.3 --- **Canonical decimal format:** no trailing zeros after the
    decimal point (`"0.5"` not `"0.50"`), a single leading zero before
    the point (`"0.25"` not `".25"`), no plus signs, no thousands
    separators. All choices use the canonical format so string equality
    in the answer flow (Spec §12) is safe; results that come out whole
    may be rendered either as an integer string or with `".0"` ---
    whichever form is chosen must be used consistently across all four
    choices of that question.
-   FR15.4 --- **Difficulty ladder (all four strategies):** difficulty
    scales BOTH operand magnitude AND decimal-place count. Tier 1:
    tenths only, single-digit whole parts. Tier 2: hundredths enter;
    larger whole parts. Tier 3: up to thousandths as allowed;
    multi-digit whole parts. Tier 4+: places approach the configured
    cap; magnitudes grow further. The effective place cap comes from
    `LevelConfig.max_decimal_places` (existing knob) when set (> 0),
    overriding the tier curve exactly like `max_operand_size` does for
    integer strategies.
-   FR15.5 --- Per-operation guarantees:
    -   **Addition/Subtraction:** results never negative; column
        alignment is never required to spot-check plausibility at Tier 1
        (small magnitudes).
    -   **Multiplication:** operands chosen so the exact product's place
        count stays within the active cap (pick factors, then derive the
        product's scaling); small whole-number-friendly structures at
        low tiers (e.g., `0.5 × 4`).
    -   **Division:** built divisor-first with a chosen quotient
        (mirroring `integer_division`'s pattern), then dividend derived
        --- guaranteeing **terminating decimals only**, no repeating or
        rounded answers ever; divisors never zero; dividend ÷ divisor
        structure avoids ambiguity about which operand is which.
-   FR15.6 --- Distractors model real student errors: place-value shifts
    (×10 / ÷10 of the true result), off-by-one in the final decimal
    place, wrong-operation result, aligning/multiplying ignoring the
    decimal points (integer product of the scaled digits where it
    differs), and swapped operand order for subtraction (clamped
    non-negative). All distractors pass through the same canonical
    formatter; no duplicate or value-equal-to-correct strings among the
    four choices.
-   FR15.7 --- New category sprites `enemy_ship_decimal_addition.png`,
    `enemy_ship_decimal_subtraction.png`,
    `enemy_ship_decimal_multiplication.png`,
    `enemy_ship_decimal_division.png` (96×96,
    placeholder-acceptable) are added under `assets/images/enemies/`
    and wired into `enemy.gd`'s texture map.
-   FR15.8 --- Level authoring: a level's `.tres` gains decimal waves
    (recommended: Level 5), with `max_decimal_places = 1` on their
    debut level rising on later levels. Final pacing/tuning belongs to
    Phase 20.

### Non-Functional Requirements

-   NFR15.1 --- No scene-tree dependency; all four strategies pure
    logic, GUT-testable in isolation.
-   NFR15.2 --- Zero edits to fraction strategies, integer strategies,
    `FractionValue`, or the question panel's rendering path --- decimals
    ride the existing plain-text/int-or-string answer pipeline from
    Phase 13 unchanged.
-   NFR15.3 --- The scaled-integer helper is shared by all four
    strategies (no per-strategy reimplementation of scale/format logic),
    keeping Phase 16 able to reuse it if needed.

### Out of Scope

-   Percentage questions (remains stretch content, Build Plan Phase 21).
-   Fraction↔decimal conversion items.
-   Repeating-decimal or rounding-based questions (division guarantees
    terminating results only).

------------------------------------------------------------------------

## 2. Detailed Implementation Plan

1.  **Shared scale/format helper** (FR15.2/FR15.3): parse-free API ---
    construct from scaled ints (`from_scaled(value, places)`), add /
    subtract / multiply / divide on scaled representations, emit
    canonical strings. Unit-test FIRST against hand-computed cases and
    property checks (format round-trips: canonical string → scaled int →
    identical string).
2.  **Addition/subtraction strategies**: generate operand pairs within
    tier bounds (same place count or mixed place counts from Tier 2 ---
    mixed counts make alignment the skill); compute via the helper;
    build FR15.6 distractors; assemble standard question Dictionary
    (plain text, no `answer_layout`).
3.  **Multiplication strategy**: pick factor pair + place split so the
    product respects the active cap (FR15.5); compute scaled; same
    assembly path.
4.  **Division strategy**: pick divisor and quotient first (quotient
    within tier magnitude), derive dividend = divisor × quotient exactly
    on scaled ints; assert terminating result by construction.
5.  **Register** all four categories (generator map + display names);
    wire the four enemy sprites (FR15.7).
6.  **Author levels** (FR15.8): extend the target `.tres` sequences with
    `max_decimal_places = 1`; raise it on a later level; adjust
    `time_limit_seconds` if wave count grew.
7.  **GUT tests** alongside each step (see Testing Plan).

------------------------------------------------------------------------

## 3. Testing Plan

### Automated Tests (GUT)

**`test_math_format.gd`** (or equivalent name for the shared helper) ---
canonical formatting rules from FR15.3 exhaustively (trailing zeros,
leading zero, whole-result policy consistency); scaled add/sub/mul/div
match reference big-number computations across randomized cases;
division-by-construction terminates.

**Per-strategy tests** (`test_decimal_addition_strategy.gd`,
`test_decimal_subtraction_strategy.gd`,
`test_decimal_multiplication_strategy.gd`,
`test_decimal_division_strategy.gd`) --- marked-correct choice equals
the independently computed exact result parsed as a rational/scalar;
exactly one correct choice among 4 unique canonical strings; no
negative results from subtraction; division divisors nonzero and
results terminating; place counts respect the tier curve AND
`max_decimal_places` override; higher tiers produce more decimal places
and/or larger operands than Tier 1; distractors include at least one
place-shift error at some seed (probabilistic assertion kept loose to
avoid flakiness); all choices canonically formatted.

**`test_question_generator.gd` (extended)** --- dispatches for all four
new keys.

**Regression** --- full prior suite (integers, fractions, wave/level)
passes unmodified.

### Manual Test Checklist

  -------------------------------------------------------------------------------
  \#                      Scenario                Expected Result
  ----------------------- ----------------------- -------------------------------
  1                       Play a decimal wave     Questions read naturally
                          debut level             ("What is 0.4 + 0.23?"); every
                                                  choice canonically formatted
                                                  (no "0.50", no ".25")

  2                       Answer several          Correct/wrong flow identical to
                          questions               integer waves (red flash, life
                                                  loss, attempt rule); buttons
                                                  show full decimal strings
                                                  without truncation

  3                       Reach multiplication/   Products and quotients stay
                          division items          exact --- never a rounded or
                                                  repeating value; division reads
                                                  unambiguously

  4                       Check Mistake Review    Selected/correct decimals shown
                                                  exactly as displayed in play

  5                       Run full GUT suite      New tests + full prior suite
                                                  pass, 0 failures
  -------------------------------------------------------------------------------

**Definition of Done:** all four decimal operations exist as registered
strategies computing exclusively via shared scaled-integer arithmetic,
with canonical formatting, tiered difficulty governed by
`max_decimal_places`, category sprites, authored waves, and full green
GUT coverage --- with zero edits to existing strategy or rendering code.
