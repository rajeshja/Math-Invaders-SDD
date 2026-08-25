# Phase 12 --- Integer Strategy Renaming & Category Key Migration

**Goal:** rename the four core question strategies and their category
keys so the naming scales to the new number-type categories coming in
Phases 13--16 --- `addition` becomes `integer_addition`,
`subtraction` becomes `integer_subtraction`, `multiplication` becomes
`integer_multiplication`, and `division` becomes `integer_division` ---
as a **pure, behavior-preserving refactor**: identical questions,
identical difficulty curves, identical visuals, full GUT suite green.
This phase establishes the canonical category registry (keys + display
names) that every later phase registers into.

**Source docs:** Build Plan §Phase 12, Spec §12 (Question Categories &
Answer Model --- authoritative key list), §5 (Stage A/B content),
Tech Stack §3 (Strategy Pattern, dispatcher map), §4 (`WaveManager`
category sequence), §9 (test layout mirrors scripts 1:1).

------------------------------------------------------------------------

## 1. Requirements

### Functional Requirements

-   FR12.1 --- The four strategy files are renamed under
    `scripts/questions/strategies/` with matching class renames:

    | Old key / class / file | New key / class / file |
    |---|---|
    | `addition` / `AdditionStrategy` / `addition_strategy.gd` | `integer_addition` / `IntegerAdditionStrategy` / `integer_addition_strategy.gd` |
    | `subtraction` / `SubtractionStrategy` / `subtraction_strategy.gd` | `integer_subtraction` / `IntegerSubtractionStrategy` / `integer_subtraction_strategy.gd` |
    | `multiplication` / `MultiplicationStrategy` / `multiplication_strategy.gd` | `integer_multiplication` / `IntegerMultiplicationStrategy` / `integer_multiplication_strategy.gd` |
    | `division` / `DivisionStrategy` / `division_strategy.gd` | `integer_division` / `IntegerDivisionStrategy` / `integer_division_strategy.gd` |

-   FR12.2 --- `question_generator.gd`'s registration map uses the new
    keys (`"integer_addition"`, `"integer_subtraction"`,
    `"integer_multiplication"`, `"integer_division"`); the `prime`
    entry is unchanged. `generate_question()` behavior, graceful
    unknown-category failure, and `get_categories()` are otherwise
    unchanged.

-   FR12.3 --- Every consumer of the old keys is migrated in the same
    change so no stale key survives anywhere:
    -   `enemy.gd` `CATEGORY_TEXTURES` keys.
    -   `wave_manager.gd` default `category_sequence`.
    -   `level_config.gd` default `category_sequence` and all five
        `resources/levels/*.tres` files.
    -   All GUT test files and their dispatch assertions.
    Git history (renames via `git mv`) keeps the lineage reviewable.

-   FR12.4 --- A single display-name registry maps each internal
    category key to the player-facing label used by the HUD wave-progress
    line ("Subtraction 6/10 remaining"). Suggested home: a static
    dictionary + `static func get_display_name(category: String) -> String`
    on `question_generator.gd`. Required mappings for this phase:
    `integer_addition → "Addition"`, `integer_subtraction → "Subtraction"`,
    `integer_multiplication → "Multiplication"`, `integer_division →
    "Division"`, `prime → "Prime Numbers"`. Unknown keys fall back to
    `String.capitalize()`. `hud.gd` resolves through this registry
    instead of calling `capitalize()` directly, so the HUD text is
    byte-for-byte what it was before the rename.

-   FR12.5 --- Gameplay is observably unchanged after the migration:
    same question shapes, operand ranges, distractor patterns, enemy
    sprites per wave, HUD labels, and wave sequencing as Phase 11.

### Non-Functional Requirements

-   NFR12.1 --- No gameplay logic changes ride along: this phase edits
    names, keys, registrations, and resources only. Any behavioral diff
    found during review is a bug in the refactor, not a feature.
-   NFR12.2 --- The full GUT suite passes with 0 failures immediately
    after the migration; test file renames mirror the script renames
    1:1 (Tech Stack §9 convention).
-   NFR12.3 --- Later phases must be able to add a category by adding a
    strategy file + one registration line + one display-name entry ---
    the registry introduced here is the single place keys are declared.

### Out of Scope

-   Any new category or generation logic (Phases 13--16).
-   Answer-value model changes (still int-only; lands in Phase 13).
-   Level roster changes beyond migrating existing `.tres` keys
    (Phases 13--19 author new waves).

------------------------------------------------------------------------

## 2. Detailed Implementation Plan

1.  **Rename scripts and classes** (`git mv`): the four strategy files
    per FR12.1; update `class_name` declarations and any explicit
    references (`question_generator.gd` `_init()`, test preloads).
2.  **Migrate keys**: update the generator map, `enemy.gd`
    `CATEGORY_TEXTURES`, both default sequences, and all five `.tres`
    files' `category_sequence` arrays to the `integer_*` keys.
3.  **Add the display-name registry** on `question_generator.gd`
    (FR12.4) and switch `hud.gd`'s `update_wave_progress()` to resolve
    labels through it. Verify the HUD string is unchanged for the four
    integer categories and Prime.
4.  **Rename tests** to match: `test_integer_addition_strategy.gd`,
    `test_integer_subtraction_strategy.gd`,
    `test_integer_multiplication_strategy.gd`,
    `test_integer_division_strategy.gd`; update
    `test_question_generator.gd` dispatch cases and every other test
    that references an old key (e.g., wave sequencing fixtures).
5.  **Full-suite regression run** plus a manual smoke playthrough of
    Level 1 (all four waves) confirming sprites, HUD labels, and
    question content are unchanged.

------------------------------------------------------------------------

## 3. Testing Plan

### Automated Tests (GUT)

-   Renamed strategy tests pass unchanged in logic --- only symbols/keys
    moved (FR12.5/NFR12.2).
-   `test_question_generator.gd`: dispatches to the renamed classes for
    the four `integer_*` keys; unknown-category graceful path still
    exercised with a never-valid key.
-   `test_wave_manager.gd` / `test_level_manager.gd`: sequence fixtures
    use the new keys; all prior assertions hold unmodified.
-   New small case(s) for the display-name registry: known keys map to
    the FR12.4 labels; unknown key falls back to `capitalize()`.

### Manual Test Checklist

  -------------------------------------------------------------------------------
  \#                      Scenario                Expected Result
  ----------------------- ----------------------- -------------------------------
  1                       Play Level 1 start      Waves run Addition →
                          to finish               Subtraction → Multiplication →
                                                  Division with correct sprites;
                                                  HUD shows exactly
                                                  "Addition"/"Subtraction"/
                                                  "Multiplication"/"Division"
                                                  (never "Integer Addition")

  2                       Grep the repo for the   Zero remaining occurrences of
                          old keys                `"addition"`/`"subtraction"`/
                                                  `"multiplication"`/`"division"`
                                                  as standalone category keys
                                                  outside historical comments

  3                       Run full GUT suite      0 failures; test filenames
                                                  mirror the renamed scripts
  -------------------------------------------------------------------------------

**Definition of Done:** the four integer strategies are renamed end-to-end
(files, classes, keys, resources, tests), the display-name registry exists
and the HUD output is unchanged, the game plays identically to Phase 11,
and the full GUT suite is green --- leaving a clean naming foundation for
the fraction/decimal/ratio/HCF-LCM strategies of Phases 13--16.
