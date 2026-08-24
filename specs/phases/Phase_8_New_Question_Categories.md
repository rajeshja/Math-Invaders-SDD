# Phase 8 --- New Question Categories (Stage C Content)

**Goal:** validate and exercise the Strategy Pattern's extensibility
(Tech Stack §3) by adding a genuinely new, non-arithmetic category ---
prime number identification --- as an advanced-level wave layered on top
of the existing four categories, without touching their code. The new
category must inherit the same wrong-answer/lives practice behavior as
the core categories: incorrect answers do not move the formation and the
the question-attempt behavior is inherited from the global/per-level
configuration; the default is one attempt, so wrong answers advance to a new
question after red feedback.

**Source docs:** Build Plan §Phase 8, Spec §5 (Stage C --- new
concepts), §7 (`enemy_ship_prime.png` asset), Tech Stack §3
(`prime_strategy.gd`, "Why this pattern"), §4 (`LevelManager.gd`
threshold-based category rotation), §8 (prime strategy + LevelManager
testing extension).

------------------------------------------------------------------------

## 1. Requirements

### Functional Requirements

-   FR8.1 --- `prime_strategy.gd` is added under
    `scripts/questions/strategies/`, implementing the shared
    `question_strategy.gd` contract:
    `generate(difficulty: int) -> Dictionary` returning
    `{ question_text, correct_answer, choices }`.
-   FR8.2 --- `prime_strategy.gd` is registered in
    `question_generator.gd`'s category map (e.g.,
    `{"prime": PrimeStrategy.new()}`) with **zero changes** to
    `addition_strategy.gd`, `subtraction_strategy.gd`,
    `multiplication_strategy.gd`, `division_strategy.gd`, or any of
    their existing call sites --- this is the explicit extensibility
    check called out in Tech Stack §3.
-   FR8.3 --- `enemy_ship_prime.png` is added under
    `assets/images/enemies/` and wired into `WaveManager`'s existing
    per-instance texture-swap mechanism (Tech Stack §7) alongside the
    four existing category sprites, with no change to how that mechanism
    works.
-   FR8.4 --- `LevelManager.gd` is updated to insert `"prime"` into the
    category sequence it hands to `WaveManager` once the player reaches
    a defined advanced-level threshold (e.g., a constant such as
    `ADVANCED_LEVEL_THRESHOLD`), documented in code.
-   FR8.5 --- Below the threshold level, the category sequence and wave
    count are **unchanged** from Phase 6 (Addition → Subtraction →
    Multiplication → Division, 4 waves). At or above the threshold, the
    sequence includes `"prime"` exactly once, in a clearly defined
    position (e.g., appended as a 5th wave), documented in code.
-   FR8.6 --- A "Prime Numbers" wave behaves identically to any other
    wave from `WaveManager`'s perspective (10-enemy formation, visible
    depletion, wave-complete transition) --- no special-casing of prime
    waves in `WaveManager` itself.

### Non-Functional Requirements

-   NFR8.1 --- Prime-strategy distractor generation avoids duplicates
    and nonsensical values, matching the standard set for existing
    strategies in Spec §5.
-   NFR8.2 --- Adding the new category must require **no edits** to any
    existing strategy file --- this is verified explicitly in testing
    (see below), not just asserted in the plan.
-   NFR8.3 --- `WaveManager` must continue to accept and iterate a
    variable-length category sequence (4 or 5 entries) without
    structural changes --- it was already designed against a generic
    `category_sequence: Array` in Phase 3/6.
-   NFR8.4 --- Prime waves use the same lives-only wrong-answer contract
    as every other wave; there is no special descent or damage rule for
    Prime.

### Out of Scope

-   Other Stage C concepts (factors/multiples, fractions/percentages)
    --- flagged as later/stretch content per Spec §5 and Build Plan Phase 12.
-   Any change to Stage A/B difficulty scaling for the existing four
    categories (Phase 6, unchanged).

------------------------------------------------------------------------

## 2. Detailed Implementation Plan

1.  **`prime_strategy.gd`**: implement
    `generate(difficulty: int) -> Dictionary` following the interface
    established in Phase 2/3:
    -   Generate a small set of distinct numbers (count fixed at 4 to
        match the answer-choice format; range/size scaled by
        `difficulty`), where **exactly one** number in the set is prime.
    -   `correct_answer` = the prime number; `choices` = the full
        generated set (already exactly one correct answer among 4,
        satisfying the standard distractor-count rule without a separate
        distractor-generation step).
    -   `question_text` = e.g., `"Which of these numbers is prime?"`.
    -   Add a small `is_prime(n: int) -> bool` helper --- either local
        to `prime_strategy.gd` or lifted into the shared
        `distractor_utils.gd` referenced in Tech Stack §3 if other
        future strategies might reuse it.
2.  **Register in `question_generator.gd`**: add the single new map
    entry for `"prime"`. Confirm via a diff/review that no other lines
    in the file, nor any of the four existing strategy files, were
    touched --- this is the concrete validation of Tech Stack §3's
    extensibility claim.
3.  **Add `enemy_ship_prime.png`** to `assets/images/enemies/`; extend
    `WaveManager`'s existing category → texture lookup (the same
    dictionary/switch used for the other four categories since Phase
    2/3) with the new entry --- no new mechanism.
4.  **`LevelManager.gd` threshold logic**: define
    `const ADVANCED_LEVEL_THRESHOLD := 5` (or the team's chosen value)
    at the top of the script. In `start_level()`, extend the
    `category_sequence` array it already builds and passes to
    `WaveManager` (via the `set_category_sequence()` hand-off
    established in Phase 6, FR6.5/FR6.6) as: base 4-category list, plus
    `"prime"` appended when `current_level >= ADVANCED_LEVEL_THRESHOLD`.
5.  **No `WaveManager` changes required** beyond what Phase 6 already
    built --- `WaveManager` already accepts an externally-provided
    `category_sequence` and iterates whatever it's given (Phase 6,
    NFR6.3); this phase confirms that generality holds for a 5-entry
    sequence too, not just the original 4-entry one.
6.  **Write GUT tests** for `prime_strategy.gd` and extend
    `test_level_manager.gd` (see Testing Plan).

------------------------------------------------------------------------

## 3. Testing Plan

### Automated Tests (GUT)

**`test_prime_strategy.gd`** (mirrors the existing strategy test pattern
from Phase 2/3) - `correct_answer` returned by `generate(difficulty)` is
actually prime (cross-checked against a known-correct primality check
independent of `is_prime()`, to avoid a test that just re-asserts the
implementation). - Exactly one correct choice among the 4 returned
`choices`, and the other 3 are confirmed **not** prime. - No duplicate
values within `choices`. - Difficulty scaling sanity check (e.g., number
range/size increases as `difficulty` increases).

**`test_question_generator.gd` (extended)** - Dispatches to
`PrimeStrategy` correctly for category `"prime"`, using the same
dispatch test pattern as the existing four categories.

**`test_level_manager.gd` (extended)** - Below
`ADVANCED_LEVEL_THRESHOLD`, the `category_sequence` handed to (a
stubbed) `WaveManager` equals exactly the original 4-category list, with
`"prime"` absent. - At and above `ADVANCED_LEVEL_THRESHOLD`,
`category_sequence` includes `"prime"` exactly once, at the documented
position. - All of Phase 6's existing `test_level_manager.gd` cases
(difficulty scaling, level-advance signal, category-sequence reset)
continue to pass unmodified --- an explicit regression check that adding
the new category didn't disturb prior behavior.

### Manual Test Checklist

  ------------------------------------------------------------------------------------------------------
  \#                      Scenario                Expected Result
  ----------------------- ----------------------- ------------------------------------------------------
  1                       Play up to a level      Exactly 4 waves per level, in the original category
                          below the advanced      order, no Prime wave present
                          threshold               

  2                       Reach the               A 5th wave appears, themed "Prime Numbers," using
                          advanced-level          `enemy_ship_prime.png` for all 10 enemies
                          threshold               

  3                       Answer several          Questions ask to identify the prime among 4 numbers;
                          prime-identification    the marked-correct number is genuinely prime;
                          questions               distractors are plausible non-primes with no
                                                  duplicates

  4                       Diff the change set for `addition_strategy.gd`, `subtraction_strategy.gd`,
                          this phase              `multiplication_strategy.gd`, `division_strategy.gd`
                                                  show **no modifications**

  5                       Run full GUT suite      `test_prime_strategy.gd` and the extended
                                                  `test_question_generator.gd`/`test_level_manager.gd`
                                                  cases pass, 0 failures, with no regressions in any
                                                  prior phase's tests
  ------------------------------------------------------------------------------------------------------

**Definition of Done:** advanced levels include a fully art-dressed
"Prime Numbers" wave layered on top of the existing four-category
rotation exactly as designed, added without modifying any existing
strategy file, and covered by the same strategy-level and
level-threshold test patterns established in earlier phases.


## 4. Question Attempt Behavior

Prime and future categories use the same global/per-level
`tries_per_question` rule as existing categories. `WaveManager` must not
special-case the attempt count by category. Wrong answers flash the selected
answer red, consume one life, and either retire the question at the configured
attempt limit or leave it active for another allowed attempt.
