# Phase 16 --- Ratio & Proportion and HCF & LCM Strategies

**Goal:** round out the new question categories with the two remaining
concept families: `ratio_proportion` (proportion solving, ratio
sharing, unit-rate scaling) and `hcf_lcm` (highest common factor /
lowest common multiple identification). Both produce integer answers,
so they ride the original int answer pipeline --- no rendering work is
needed; this phase is generation logic, registration, sprites, and
level authoring.

**Source docs:** Build Plan §Phase 16, Spec §5 (Stage C), §12 (category
registry), Tech Stack §3 (strategy pattern extensibility), Phase 8
(`prime_strategy.gd`) as the template for non-arithmetic categories.

------------------------------------------------------------------------

## 1. Requirements

### Functional Requirements

#### Ratio & Proportion
-   FR16.1 --- `ratio_proportion_strategy.gd` is added under
    `scripts/questions/strategies/`, registered under key
    `"ratio_proportion"` with display name "Ratio & Proportion"
    (Spec §12). Question text must state unambiguously what to find.
-   FR16.2 --- **Question forms, tiered by difficulty:**
    -   **Tier 1 --- Proportion solve:** `a : b = c : ?` find the
        missing term, with `b` dividing `c`-friendly structures
        (integer scale factor); magnitudes ≤ ~20.
    -   **Tier 2 --- Sharing:** divide a total T in a two-part ratio
        `a : b`; find one named share; T always exactly divisible by
        `(a + b)`.
    -   **Tier 3 --- Three-part sharing & larger factors:** ratios like
        `a : b : c` over T; find the largest or smallest share;
        magnitudes grow.
    -   **Tier 4+ --- Unit-rate scaling:** "n items cost X; what do m
        items cost?" style with clean integer rates; mixed-form items
        combining a proportion step with a comparison ("who got more?"),
        still answering with a single integer.
-   FR16.3 --- Answers are integers; distractors model real errors:
        wrong-part share (the other ratio term's share), sum of parts,
        off-by-one-scale results, share computed from an incorrect total
        division, and for proportions the cross-product misapplied
        (`c × b ÷ a` vs correct `c × b ÷ a` variants that differ by using
        the wrong pairing).

#### HCF & LCM
-   FR16.4 --- `hcf_lcm_strategy.gd` is added under
    `scripts/questions/strategies/`, registered under key `"hcf_lcm"`
    with display name "HCF & LCM" (Spec §12). Each question asks
    explicitly for the HCF or the LCM (never ambiguous).
-   FR16.5 --- **Tiered generation:**
    -   **Tier 1:** HCF of two numbers ≤ 20 with a common factor > 1;
        LCM of two numbers ≤ 10 whose LCM ≤ 60.
    -   **Tier 2:** two numbers ≤ 100 (HCF) / LCM ≤ 240.
    -   **Tier 3:** three numbers for HCF; LCM of a coprime-ish pair
        (product = LCM cases excluded from low tiers deliberately so
        multiplication isn't rewarded as an LCM shortcut too early).
    -   **Tier 4+:** three-number LCM within bounded magnitude; larger
        ranges throughout.
    A shared factor/multiple helper (local to the strategy or lifted
    into the support folder next to `FractionValue` if Phase 20 tuning
    wants it elsewhere) computes ground truth via Euclid's algorithm
    for HCF and `a × b ÷ hcf(a, b)` for LCM.
-   FR16.6 --- Distractors are mathematically meaningful near-misses:
        the other member of the HCF/LCM pair (classic confusion), a
        common-but-not-highest factor / common-but-not-least multiple,
        the product of the numbers, their difference, and ±small
        offsets. All distractors positive integers; no duplicates; none
        equal to the correct answer.
-   FR16.7 --- New category sprites `enemy_ship_ratio_proportion.png`
        and `enemy_ship_hcf_lcm.png` (96×96, placeholder-acceptable)
        are added under `assets/images/enemies/` and wired into
        `enemy.gd`'s texture map.
-   FR16.8 --- Level authoring: a level's `.tres` gains
        `ratio_proportion` and `hcf_lcm` waves. If the current roster
        (Levels 1--5) is already carrying fraction + decimal waves,
        extend `LevelConfig.LEVEL_RESOURCE_PATHS` with a new
        `level_6.tres` hosting these debut waves --- appending levels is
        explicitly supported by the registry pattern. Final pacing/
        tuning belongs to Phase 20.

### Non-Functional Requirements

-   NFR16.1 --- No scene-tree dependency in either strategy; pure logic,
    GUT-testable in isolation.
-   NFR16.2 --- Zero edits to all previously existing strategy files ---
    this phase adds files and registration lines only (Tech Stack §3
    extensibility contract).
-   NFR16.3 --- Integer answers mean no changes to the answer pipeline,
    rendering, or mistake log from this phase.

### Out of Scope

-   Percentage questions (stretch content, Build Plan Phase 21).
-   Visual ratio diagrams/pie models (text-only questions this phase).
-   Prime-factorization-as-method questions (LCM/HCF asked by value
    only).

------------------------------------------------------------------------

## 2. Detailed Implementation Plan

1.  **`ratio_proportion_strategy.gd`**: implement the FR16.2 form
    ladder --- construct totals/ratios divisible by design (pick shares
    first, derive the total --- same derive-backwards pattern as the
    division strategies); compute ground truth on ints; build FR16.3
    distractors; assemble standard int-answer Dictionary.
2.  **`hcf_lcm_strategy.gd`**: implement Euclid-based helper plus the
    FR16.5 tier bounds; pick number sets satisfying the tier's
    structural exclusions; build FR16.6 distractors filtered through
    uniqueness/correctness checks.
3.  **Register** both categories (generator map + display names);
    wire the two enemy sprites (FR16.7).
4.  **Author levels** (FR16.8): create `level_6.tres` if needed, add it
    to `LEVEL_RESOURCE_PATHS`, set its category sequence to carry the
    new waves (optionally interleaved with review waves from earlier
    categories); adjust its `time_limit_seconds` for wave count.
5.  **GUT tests** alongside each step (see Testing Plan).

------------------------------------------------------------------------

## 3. Testing Plan

### Automated Tests (GUT)

**`test_ratio_proportion_strategy.gd`** --- every generated item is
internally consistent (stated total equals sum of shares for sharing
forms; stated proportion actually holds); marked-correct equals the
true missing term/share/rate; exactly one correct choice among 4 unique
positive integers; totals divisible by part-sums at every tier; higher
tiers yield bigger magnitudes and richer forms (assert form markers if
exposed, else distributional checks across seeds).

**`test_hcf_lcm_strategy.gd`** --- cross-check the marked-correct value
against an independent HCF/LCM implementation written in the test (not
the strategy's own helper); distractors are never equal to the correct
value and are plausible (all positive, within a sane band); Tier 1
bounds respected; Tier 3+ introduces three-number HCF items; LCM items
at low tiers exclude product-equal cases per FR16.5.

**`test_question_generator.gd` (extended)** --- dispatches for both new
keys.

**Regression** --- full prior suite passes unmodified (NFR16.2 verified
by diff).

### Manual Test Checklist

  -------------------------------------------------------------------------------
  \#                      Scenario                Expected Result
  ----------------------- ----------------------- -------------------------------
  1                       Play a ratio wave       Questions state plainly what
                                                  to find; e.g., "Share 24 in the
                                                  ratio 3:5. What is the larger
                                                  share?"; answers integer and
                                                  unique among choices

  2                       Play an HCF/LCM wave    Every question names HCF or LCM
                                                  explicitly; small friendly
                                                  numbers early; no ambiguity

  3                       Answer wrong            Standard wrong-answer flow
                          deliberately            unchanged (red flash, life,
                                                  attempt rule); mistake log
                                                  shows readable text

  4                       Check HUD labels        Waves show "Ratio & Proportion"
                                                  and "HCF & LCM" (display-name
                                                  registry), not raw keys

  5                       Run full GUT suite      New tests + full prior suite
                                                  pass, 0 failures
  -------------------------------------------------------------------------------

**Definition of Done:** ratio/proportion and HCF/LCM categories exist
as registered, tiered, sprite-dressed strategies with meaningful
distractors, authored waves in the level roster (extending it if
needed), and green GUT coverage --- completing the Spec §12 category
registry defined for Phases 12--16 with zero edits to existing
strategies.
