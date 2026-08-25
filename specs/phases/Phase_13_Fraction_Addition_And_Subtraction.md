# Phase 13 --- Fraction Foundations: Addition & Subtraction Strategies

**Goal:** introduce fraction questions with `fraction_addition` and
`fraction_subtraction` strategies, plus the shared machinery they need:
a canonical answer-value model that supports non-integer answers, a
fraction value/representation helper, and stacked (numerator-above-
denominator) rendering in the question panel. Difficulty for
addition/subtraction scales not only by operand size but by introducing
**unlike denominators** at higher tiers; questions and answers span
**proper, improper, and mixed fractions**; every result must be
**simplified**; and all fractions are displayed stacked, both in the
question text and on the four answer buttons.

This is deliberately the largest of the new-category phases: it lands
the reusable foundation that Phases 14--16 build on.

**Source docs:** Build Plan §Phase 13, Spec §5 (Stage C content), §12
(category registry & answer-value model --- authoritative), Tech Stack
§3 (strategy pattern, support modules), §5 (`question_panel.gd`
rendering), Phase 9 FR9.3 (`allow_unlike_denominators`,
`max_operand_size` knobs already exist in `LevelConfig`).

------------------------------------------------------------------------

## 1. Requirements

### Functional Requirements

#### Answer-Value Model Extension
-   FR13.1 --- The question contract is extended: `correct_answer` and
    each entry of `choices` may now be either an `int` (integer
    categories, unchanged) or a `String` holding the **canonical display
    form** of a fraction value (e.g., `"3/4"`, `"7/3"`, `"2 1/3"`).
    Correctness comparison throughout the answer flow uses exact string
    equality of these canonical forms; producers guarantee canonicity
    (simplified fractions, no leading zeros, no sign on the denominator,
    single spacing in mixed form). Consumers updated accordingly:
    `question_panel.gd` (`answer_selected` payload + button meta store
    the raw value instead of casting to `int`), `main.gd`
    `_on_answer_selected`, `wave_manager.gd` `question_failed` signal,
    and `mistake_tracker.gd` (stores display strings). Integer
    categories keep working exactly as before.
-   FR13.2 --- A shared `FractionValue` helper (suggested:
    `scripts/questions/support/fraction_value.gd`, `RefCounted`) owns
    fraction math and representation: numerator/denominator ints with
    denominator > 0 normalization, `simplify()` via GCD, proper/improper
    classification, mixed-form decomposition `{whole, numerator,
    denominator}`, value equality, and canonical string rendering. All
    three fraction phases (13, 14) use this helper --- no strategy
    implements its own gcd/reduction logic.

#### Stacked Fraction Display
-   FR13.3 --- Fractions are rendered **stacked** --- numerator above a
    horizontal bar above denominator --- in BOTH the question text area
    and every answer button, never as inline "a/b" text during gameplay.
    Mixed numbers render as the whole part followed by the stacked
    remainder; improper fractions may be rendered stacked-improper or as
    mixed numbers per FR13.6's representation choice for that question.
-   FR13.4 --- Rendering must preserve everything Phase 11 established:
    44px+ touch targets on all four buttons, the red wrong-answer flash,
    safe-area handling, and input gating. Suggested implementation: a
    RichTextLabel (BBCode table) for the question line, and each Button
    hosting a centered child control (numerator Label / bar / denominator
    Label with `mouse_filter = IGNORE`) so taps, theme, and flash
    styleboxes keep working untouched. Plain `"a/b"` strings remain
    acceptable ONLY outside gameplay surfaces (Mistake Review panel,
    logs, GUT assertions).
-   FR13.5 --- Stacked layout must stay inside the existing 320×110
    button footprint at the 720×1280 base resolution with readable font
    sizes for ages 6--12; long whole parts (e.g., `"12 5/8"`) shrink the
    fraction block rather than overflowing the button.

#### Fraction Addition & Subtraction
-   FR13.6 --- `fraction_addition_strategy.gd` and
    `fraction_subtraction_strategy.gd` are added under
    `scripts/questions/strategies/`, registered under keys
    `"fraction_addition"` / `"fraction_subtraction"` with display names
    "Fraction Addition" / "Fraction Subtraction" (Spec §12). Both
    guarantee: exactly one correct choice among 4 unique choices; no
    distractor **value-equal** to the correct answer or to another
    distractor (value equality on simplified form --- an unsimplified
    equivalent like `2/4` next to a correct `1/2` is forbidden because
    it is mathematically equal); subtraction results never negative;
    every generated question has exactly one valid correct answer.
-   FR13.7 --- **Difficulty ladder (both strategies)** --- difficulty
    scales along TWO axes per Spec §5:
    -   **Tier 1:** like denominators (≤ 10), small numerators (≤ 9),
        proper-fraction operands, results that stay proper after
        simplification where possible.
    -   **Tier 2:** like denominators up to ~20; sums/differences may be
        improper → simplification plus improper/mixed representation
        becomes required (FR13.8 kicks in here).
    -   **Tier 3:** unlike denominators introduced, first restricted to
        multiple-related pairs (e.g., halves & eighths); LCD reasoning
        required; operands may be mixed numbers.
    -   **Tier 4+:** unlike denominators including coprime pairs (LCD =
        product or non-trivial LCM); larger numerators; mixed-number
        operands common.
    `LevelConfig.allow_unlike_denominators` (existing knob, Phase 9
    FR9.3) gates unlike-denominator generation independently of tier ---
    when `false`, generation stays like-denominator regardless of
    difficulty; when `true`, the tier ladder governs.
    `LevelConfig.max_operand_size` caps numerators/denominators when set.
-   FR13.8 --- Questions AND answers include **proper, improper, and
    mixed fractions**: Tier 1 deals only proper forms; from Tier 2 on,
    each question randomly picks one consistent representation for its
    choices (improper-stacked or mixed) so format never leaks the
    correct answer; operands themselves may be presented as mixed
    numbers at Tier 3+. All representations of the same value are
    accepted internally (comparison happens on canonical simplified
    value, not surface form).
-   FR13.9 --- **Simplification is part of solving:** every correct
    answer is reduced to lowest terms before being rendered as the
    canonical choice (e.g., an item whose raw sum is `4/8` expects
    `1/2`). Distractors model real student errors: adding/subtracting
    both numerators AND denominators straight across, off-by-one
    numerator or denominator, wrong-operation result, subtracting in the
    wrong order (clamped non-negative), forgetting the LCD and using a
    denominator that appears in the operands.
-   FR13.10 --- New category sprites
    `enemy_ship_fraction_addition.png` / `enemy_ship_fraction_subtraction.png`
    (96×96, placeholder-acceptable per Spec §7) are added under
    `assets/images/enemies/` and wired into `enemy.gd`'s texture map.
-   FR13.11 --- Level authoring: at least one level's `.tres`
    (recommended: Level 3) gains `fraction_addition` and
    `fraction_subtraction` waves appended after the integer waves, with
    `allow_unlike_denominators = false` for their debut level so Tier 1/2
    content is served first. Later levels may enable unlike denominators.
    Exact roster/pacing is authoring detail; final tuning belongs to
    Phase 20.

### Non-Functional Requirements

-   NFR13.1 --- Fraction strategies have **no scene-tree dependency**
    (Tech Stack §9): `generate(difficulty, options)` stays pure logic;
    rendering data travels inside the returned Dictionary, and the panel
    interprets it.
-   NFR13.2 --- Adding Phases 14--16 categories requires no edits to
    `fraction_addition_strategy.gd` / `fraction_subtraction_strategy.gd`
    --- one new file, one registration line, one display-name entry.
-   NFR13.3 --- Integer categories' behavior is regression-protected:
    the pre-existing suites pass unmodified except where FR13.1 loosens
    types (int remains a valid answer value everywhere).

### Out of Scope

-   Fraction multiplication/division (Phase 14).
-   Decimal/ratio/HCF-LCM categories (Phases 15--16).
-   Scoring changes (Phase 17) and ship-image configuration
    (Phases 18--19).

------------------------------------------------------------------------

## 2. Detailed Implementation Plan

1.  **`fraction_value.gd`** (FR13.2): implement normalize/simplify/
    mixed-decompose/value-equality/canonical-string helpers with static
    constructors (`from_parts`, `from_common_denominator`); unit-test
    FIRST since every later phase depends on it.
2.  **Answer-value plumbing** (FR13.1): loosen `answer_selected(value)`
    and button meta handling in `question_panel.gd`; update
    `main.gd`'s comparison (string-equality against `correct_answer`);
    loosen `question_failed` parameter typing in `wave_manager.gd`;
    store `str()` values in `mistake_tracker.gd`. Confirm integer flow
    unchanged via existing suites.
3.  **Stacked rendering** (FR13.3--FR13.5): extend `question_panel.gd`
    to detect fraction payloads (suggested: optional
    `answer_layout` array of `{whole, numerator, denominator}` /
    `{numerator, denominator}` entries parallel to `choices`; absent →
    plain-text path used by integer categories). Build the button child
    controls once per question swap; verify flash/safe-area/touch
    behavior manually on-device.
4.  **Strategies** (FR13.6--FR13.9): implement both strategies against
    `FractionValue`: pick operands per the tier ladder; compute exact
    results on integer numerators over a common denominator (never
    floats); simplify; choose representation; build distractors from the
    error patterns; assemble the question Dictionary with
    `question_text` (inline tokens for stacking) + `answer_layout`.
5.  **Register** both categories (generator map + display names) and
    add the two enemy sprites to `enemy.gd`'s texture map (FR13.10).
6.  **Author levels** (FR13.11): update the target `.tres` files
    (category_sequence additions; `allow_unlike_denominators` false on
    debut, true on a later level; adjust `time_limit_seconds` upward if
    wave count grew).
7.  **GUT tests** alongside each step (see Testing Plan).

------------------------------------------------------------------------

## 3. Testing Plan

### Automated Tests (GUT)

**`test_fraction_value.gd`** --- normalization (sign into numerator),
simplify correctness across randomized pairs vs. an independent
reference implementation written in the test, mixed decomposition,
value equality across representations (`2/4 == 1/2 == "0.5"`-free zone:
fractions only), canonical string output.

**`test_fraction_addition_strategy.gd` / `test_fraction_subtraction_strategy.gd`**
--- parse the returned choices back through `FractionValue`; assert the
marked-correct choice equals the true simplified sum/difference; exactly
one value-correct choice among 4; all choices pairwise value-distinct;
subtraction never negative; Tier 1 generates like denominators only;
Tier 3+ (with `allow_unlike_denominators`) produces unlike-denominator
items; higher tiers yield larger numerators/denominators than Tier 1;
correct answers always fully simplified (GCD == 1); representation mix
appears from Tier 2 (some improper, some mixed items across seeds);
`answer_layout` present and consistent with each displayed choice;
`max_operand_size` respected when provided.

**`test_question_generator.gd` (extended)** --- dispatches for
`"fraction_addition"` / `"fraction_subtraction"`; unknown-category path
still safe.

**`test_wave_manager.gd` / `test_main-flow` regressions** --- wrong
answer on a fraction question records the STRING selected/correct pair
in the mistake log; attempt counting/red-flash path unchanged; integer
waves still emit int answers.

### Manual Test Checklist

  -------------------------------------------------------------------------------
  \#                      Scenario                Expected Result
  ----------------------- ----------------------- -------------------------------
  1                       Play a Tier 1 fraction  Fractions render stacked in
                          wave                    question AND all 4 buttons;
                                                  nothing renders as "a/b"
                                                  inline text during play

  2                       Answer several          Buttons stay ≥44dp tappable,
                          fraction questions      red flash works on the tapped
                          including wrong ones    fraction button, next question
                                                  loads after feedback

  3                       Reach a Tier 3+ item    Unlike-denominator question;
                          (unlike denominators    expected answer requires LCD
                          enabled)                work; result shown simplified

  4                       Trigger an improper     Result displays as improper or
                          result                  mixed consistently across all
                                                  four choices (no format tell);
                                                  value accepted as correct

  5                       Lose a life on a        Mistake Review shows the
                          fraction question       question and answers readably
                                                  (plain "w n/d" text acceptable
                                                  here)

  6                       Run full GUT suite      All new fraction tests +
                                                  complete prior suite pass,
                                                  0 failures
  -------------------------------------------------------------------------------

**Definition of Done:** fraction addition/subtraction waves appear in
authored levels with stacked, simplified, representation-mixed
questions/answers governed by the unlike-denominator difficulty ladder,
the answer-value model and shared `FractionValue` helper exist for later
phases, integer gameplay is regression-clean, and the full GUT suite
passes.
