# Phase 25 --- Playtesting & Balancing

> Renumbering note: this phase was previously numbered Phase 12, then
> Phase 20. The strategy-expansion and level-visual-configuration work
> now occupies Phases 12--19, and the fraction layout fix is Phase 20;
> playtesting moved to Phase 25 so the build being tested includes that
> content.

**Goal:** run the finished, exported build (Phases 10--11, extended by
Phases 12--19) past players in the target age group, and tune existing
parameters --- difficulty pacing, distractor plausibility, wave feel,
lives/mistake-budget feel, per-level point values, and the new
fraction/decimal/ratio/HCF-LCM category pacing --- based on what's
observed, without restructuring the underlying architecture.

**Source docs:** Build Plan §Phase 25, Spec §1 (target audience --- ages
6--12), §5 (educational content progression, distractor & difficulty
rules), §12 (category naming & answer model), Tech Stack §3
(per-strategy difficulty scaling), §4 (`WaveManager`/`LevelManager`
tunables), §9 (full GUT suite as the regression backstop).

------------------------------------------------------------------------

## 1. Requirements

### Functional Requirements

-   FR20.1 --- Structured playtesting sessions are conducted with
    players in the target 6--12 age range, per Spec §1.
-   FR20.2 --- Observations are captured against tuning dimensions:
    question difficulty pacing per level, distractor plausibility, wave
    length feel, lives/mistake-budget feel, the level time-limit feel,
    the per-level `points_per_question` values introduced in Phase 17,
    and the pacing of the fraction/decimal/ratio/HCF-LCM waves
    introduced in Phases 13--16.
    **All level balancing must be done by directly editing the `LevelConfig.tres` Custom Resources in the Godot Inspector**, rather than tweaking hardcoded math formulas.
-   FR20.3 --- Difficulty parameters (operand ranges per Spec §5's Stage
    A/B tiers, LevelConfig `difficulty`/`max_operand_size`,
    `allow_unlike_denominators`, and `max_decimal_places`) are adjusted
    based on playtesting findings, without changing any strategy's
    `generate(difficulty, options)` interface/contract.
-   FR20.4 --- Distractor-generation logic in one or more strategies is
    revisited if playtesting surfaces confusing or implausible wrong
    answers, while preserving the "no duplicates, no nonsensical values"
    rule from Spec §5 --- including the value-equality rule for
    fraction/decimal choices (Spec §12): no choice may ever be
    value-equal to the correct answer or to another choice.
-   FR20.5 --- Bugs found during playtesting are triaged, fixed, and
    re-verified.
-   FR20.6 --- The full GUT suite is re-run after every round of
    balancing changes, to catch regressions in difficulty scaling,
    distractor generation, or wave/level logic before the next
    playtesting round.

### Non-Functional Requirements

-   NFR20.1 --- Balancing changes stay within the existing architecture
    (tunable parameters/constants within strategies, `WaveManager`,
    `LevelManager`, `LevelConfig` resources, and project settings) ---
    this is a tuning phase, not a redesign phase; no new classes,
    signals, or structural changes are introduced.
-   NFR20.2 --- Any balancing change that touches strategy, wave, or
    level logic must have its corresponding existing GUT coverage (from
    Phases 2, 3, 6, 8, and 12--19) re-validated as passing before the
    change is considered done --- tuning changes are never shipped
    untested.

### Out of Scope

-   New features, categories, or platform targets (all prior phases).
-   Stretch content such as percentages, profiles, or non-math modules
    (Phase 26).

------------------------------------------------------------------------

## 2. Detailed Implementation Plan

1.  **Define the playtesting protocol**: session length, number of
    participants spanning the 6--12 target range, what's observed during
    play (time-to-answer, hesitation/confusion, engagement
    vs. frustration signals, verbal feedback), and how findings are
    recorded --- organized against the tuning dimensions named in
    the Build Plan (difficulty pacing, distractor plausibility, wave
    length feel, lives/mistake budget, question-attempt count,
    wrong-answer feedback clarity, per-level point values, and
    fraction/decimal/ratio/HCF-LCM pacing).
2.  **Run sessions** and capture findings under each of the
    dimensions.
3.  **Translate findings into concrete, scoped changes**:
    -   **Difficulty pacing** → adjust operand ranges within a strategy,
        adjust the LevelConfig `difficulty`/`max_operand_size` values, or
        adjust which levels introduce which category waves (Phases
        13--16 authoring).
    -   **Distractor plausibility** → adjust distractor-construction
        logic within the relevant strategy file(s) (Phases 2/3/8/12--16),
        keeping Spec §5's no-duplicate/no-nonsense rule and Spec §12's
        value-equality rule.
    -   **Wave length feel** → tune within the existing fixed "10
        enemies per wave" design (Spec §2); if playtesting suggests the
        fixed count of 10 itself needs to change, flag this explicitly
        as a structural question for the team rather than silently
        altering a core rule of the Spec.
    -   **Level time-limit feel** → tune `time_limit_seconds` in each
        level's `.tres` (the Project-Setting override dictionaries were
        retired by Phase 9). Timeouts that feel frequent indicate the
        budget (or question difficulty) is too tight; a budget nobody
        comes close to using is too generous. The 0.3-second bullet
        travel time and the timer's pause/wave-transition behavior are
        not tuning dimensions.
    -   **Question-attempt feel** → tune `tries_per_question` in the
        relevant `.tres` files and evaluate the clarity of the red
        wrong-answer feedback. Enemy descent is not a tuning dimension
        because wrong answers never move the formation.
    -   **Per-level scoring feel** → tune `points_per_question`
        (Phase 17) so higher-difficulty categories feel appropriately
        rewarding without making earlier integer levels pointless to
        replay.
    -   **Ship-image variety** → tune the `wave_enemy_textures` /
        `player_ship_texture` selections (Phases 18--19) purely for
        presentation; image selection never affects difficulty.
4.  **Re-run the full GUT suite** after each round of changes, before
    the next playtesting round, per FR20.6/NFR20.2.
5.  **Triage and fix bugs** surfaced during sessions (crashes, HUD/state
    desyncs, incorrect or duplicate distractors, malformed stacked
    fraction rendering, etc.), verifying each fix both manually and
    against the relevant existing GUT test file.
6.  **Repeat** the playtest → adjust → retest cycle until pacing,
    distractor quality, wave feel, scoring feel, and the lives/mistake
    budget, question-attempt count, and wrong-answer feedback clarity
    are judged appropriate for the target age group.

------------------------------------------------------------------------

## 3. Testing Plan

### Automated Tests (GUT)

-   No new dedicated test file is expected for this phase --- this is a
    tuning/QA pass over existing systems, not new logic.
-   **Regression bar:** the full existing GUT suite (all strategy tests
    including the Phase 12--19 additions, `question_generator`,
    `WaveManager`, `LevelManager`, `GameManager`, `HighScoreManager`,
    `LevelConfig`, save-data tests) must pass with 0 failures after
    **every** round of balancing changes, before that round is
    considered complete.

### Manual Test Checklist

  -----------------------------------------------------------------------------
  \#                      Scenario                      Expected Result
  ----------------------- ----------------------------- -----------------------
  1                       Run at least one full         Findings captured
                          playtesting session with      against all tuning
                          target-age-group players      dimensions: difficulty
                                                        pacing, distractor
                                                        plausibility, wave
                                                        length feel,
                                                        lives/mistake budget,
                                                        level time-limit feel,
                                                        question-attempt count,
                                                        wrong-answer feedback
                                                        clarity, per-level
                                                        point values, and
                                                        new-category pacing

  2                       Review each captured finding  Each has either an
                                                        implemented parameter
                                                        change or a documented
                                                        decision not to change
                                                        it

  3                       Re-play after a round of      Changes are noticeably
                          difficulty/distractor/speed   applied and align with
                          adjustments                   the playtesting
                                                        feedback that prompted
                                                        them

  4                       Confirm fraction/decimal      Stacked fractions remain
                          rendering survives tuning     readable at every
                          changes                       difficulty tier; no
                                                        answer button overflows
                                                        or becomes untappable

  5                       Any bugs found during         Fixed and re-verified,
                          sessions                      both manually and
                                                        against existing GUT
                                                        coverage where
                                                        applicable

  6                       Run full GUT suite after the  0 failures across the
                          final round of changes        full existing suite
  -----------------------------------------------------------------------------

**Definition of Done:** the game has been played by target-age-group
testers, tuning adjustments to difficulty pacing, distractor
plausibility, wave feel, the lives/mistake budget, the level time-limit
budget, question-attempt count, per-level point values, ship-image
variety, and wrong-answer feedback clarity have been made based on that
feedback (or explicitly deferred with rationale), all
playtesting-surfaced bugs are fixed and verified, and the full GUT suite
passes after the final round of balancing changes --- leaving a
balanced, kid-tested build ready for wider release.


## 4. Question Attempt Balancing

Playtesting must explicitly evaluate the configured `tries_per_question`
behavior. The global default remains one attempt, and selected levels may
override it via their `.tres` files. Test whether one attempt produces an
appropriate practice challenge across ALL categories --- especially the
multi-step fraction operations, where a single attempt may be harsh ---
and whether any higher-attempt level overrides improve learning without
creating excessive repetition.

Also verify that the red flash on an incorrect answer is immediately visible,
understood as feedback rather than success, and does not prevent the next
question from appearing when the attempt limit is reached.

## 5. Level Time-Limit Balancing

Playtesting must explicitly evaluate the level time budget for every
level, with particular attention to the levels that add
fraction/decimal/ratio/HCF-LCM waves: those questions take longer to read
and answer, so a flat per-wave budget may need raising via
`time_limit_seconds` once those waves join a level. Observe whether
target-age players can realistically finish while still feeling gentle
time pressure. Confirm the HUD countdown, pause freezing,
wave-transition continuity, and the "Time's up!" Game Over path all
remain intact after any tuning change (full GUT regression required).

## 6. Per-Level Scoring Balance

Playtesting must evaluate whether the configured `points_per_question`
values (Phase 17) produce sensible score progression: harder categories
should be worth proportionally more so that starting at a later unlocked
level does not feel strictly worse than grinding early levels. Verify
that personal bests, assumed-full-score on level skip, and high-score
persistence still behave correctly after any change (they operate on
totals and are unaffected structurally, but the regression run must
confirm it).
