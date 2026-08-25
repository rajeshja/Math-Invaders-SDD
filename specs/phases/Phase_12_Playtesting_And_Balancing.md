# Phase 12 --- Playtesting & Balancing

**Goal:** run the finished, exported build (Phase 10) past players in the
target age group, and tune existing parameters --- difficulty pacing,
distractor plausibility, wave feel, lives/mistake-budget feel --- based
on what's observed, without restructuring the underlying architecture.

**Source docs:** Build Plan §Phase 11, Spec §1 (target audience --- ages
6--12), §5 (educational content progression, distractor & difficulty
rules), Tech Stack §3 (per-strategy difficulty scaling), §4
(`WaveManager`/`LevelManager` tunables), §8 (full GUT suite as the
regression backstop).

------------------------------------------------------------------------

## 1. Requirements

### Functional Requirements

-   FR11.1 --- Structured playtesting sessions are conducted with
    players in the target 6--12 age range, per Spec §1.
-   FR11.2 --- Observations are captured against five defined tuning
    dimensions: question difficulty pacing per level, distractor
    plausibility, wave length feel, the configured
    lives/mistake-budget feel, and the level time-limit feel (whether
    the default waves × 30 s budget --- or any overrides --- produces
    appropriate pressure without frustrating young players).
-   FR11.3 --- Difficulty parameters (operand ranges per Spec §5's Stage
    A/B tiers, and/or the level→difficulty formula from Phase 6) are
    adjusted based on playtesting findings, without changing any
    strategy's `generate(difficulty)` interface/contract.
-   FR11.4 --- Distractor-generation logic in one or more strategies is
    revisited if playtesting surfaces confusing or implausible wrong
    answers, while preserving the "no duplicates, no nonsensical values"
    rule from Spec §5.
-   FR11.5 --- Bugs found during playtesting are triaged, fixed, and
    re-verified.
-   FR11.6 --- The full GUT suite is re-run after every round of
    balancing changes, to catch regressions in difficulty scaling,
    distractor generation, or wave/level logic before the next
    playtesting round.

### Non-Functional Requirements

-   NFR11.1 --- Balancing changes stay within the existing architecture
    (tunable parameters/constants within strategies, `WaveManager`,
    `LevelManager`, and project settings) --- this is a tuning phase,
    not a redesign phase; no new classes, signals, or structural changes
    are introduced.
-   NFR11.2 --- Any balancing change that touches strategy, wave, or
    level logic must have its corresponding existing GUT coverage (from Phases 2, 3, 6, 8) re-validated as passing before the change is
    considered done --- tuning changes are never shipped untested.

### Out of Scope

-   New features, categories, or platform targets (all prior phases).
-   Stretch content such as additional math concepts, profiles, or
    non-math modules (Phase 12).

------------------------------------------------------------------------

## 2. Detailed Implementation Plan

1.  **Define the playtesting protocol**: session length, number of
    participants spanning the 6--12 target range, what's observed during
    play (time-to-answer, hesitation/confusion, engagement
    vs. frustration signals, verbal feedback), and how findings are
    recorded --- organized against the four tuning dimensions named in
    the Build Plan (difficulty pacing, distractor plausibility, wave
    length feel, lives/mistake budget, question-attempt count, and wrong-answer feedback clarity).
2.  **Run sessions** and capture findings under each of the four
    dimensions.
3.  **Translate findings into concrete, scoped changes**:
    -   **Difficulty pacing** → adjust operand ranges within a strategy,
        or adjust the level→difficulty formula in `LevelManager.gd`
        (Phase 6).
    -   **Distractor plausibility** → adjust distractor-construction
        logic within the relevant strategy file(s) (Phase 2/3/8),
        keeping Spec §5's no-duplicate/no-nonsense rule.
    -   **Wave length feel** → tune within the existing fixed "10
        enemies per wave" design (Spec §2); if playtesting suggests the
        fixed count of 10 itself needs to change, flag this explicitly
        as a structural question for the team rather than silently
        altering a core rule of the Spec.
    -   **Level time-limit feel** → adjust `gameplay/seconds_per_wave`
        globally or add/tune entries in
        `gameplay/level_time_limit_by_level` for specific levels.
        Timeouts that feel frequent indicate the budget (or question
        difficulty) is too tight; a budget nobody comes close to using
        is too generous. The 0.3-second bullet travel time and the
        timer's pause/wave-transition behavior are not tuning
        dimensions.
    -   **Question-attempt feel** → adjust the global or per-level
        `tries_per_question` configuration and evaluate the clarity of the
        red wrong-answer feedback. Enemy descent is not a tuning dimension
        because wrong answers never move the formation.
4.  **Re-run the full GUT suite** after each round of changes, before
    the next playtesting round, per FR11.6/NFR11.2.
5.  **Triage and fix bugs** surfaced during sessions (crashes, HUD/state
    desyncs, incorrect or duplicate distractors, etc.), verifying each
    fix both manually and against the relevant existing GUT test file.
6.  **Repeat** the playtest → adjust → retest cycle until pacing,
    distractor quality, wave feel, and the lives/mistake budget, question-attempt count, and wrong-answer feedback clarity are
    judged appropriate for the target age group.

------------------------------------------------------------------------

## 3. Testing Plan

### Automated Tests (GUT)

-   No new dedicated test file is expected for this phase --- this is a
    tuning/QA pass over existing systems, not new logic.
-   **Regression bar:** the full existing GUT suite (all strategy tests,
    `question_generator`, `WaveManager`, `LevelManager`, `GameManager`,
    `HighScoreManager`) must pass with 0 failures after **every** round
    of balancing changes, before that round is considered complete.

### Manual Test Checklist

  -----------------------------------------------------------------------------
  \#                      Scenario                      Expected Result
  ----------------------- ----------------------------- -----------------------
  1                       Run at least one full         Findings captured
                           playtesting session with      against all five tuning
                           target-age-group players      dimensions: difficulty
                                                         pacing, distractor
                                                         plausibility, wave
                                                         length feel,
                                                         lives/mistake budget, level time-limit feel, question-attempt count, and wrong-answer feedback clarity

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

  4                       Any bugs found during         Fixed and re-verified,
                          sessions                      both manually and
                                                        against existing GUT
                                                        coverage where
                                                        applicable

  5                       Run full GUT suite after the  0 failures across the
                          final round of changes        full existing suite
  -----------------------------------------------------------------------------

**Definition of Done:** the game has been played by target-age-group
testers, tuning adjustments to difficulty pacing, distractor
plausibility, wave feel, the lives/mistake budget, the level time-limit
budget, question-attempt count, and wrong-answer feedback clarity have been made
based on that feedback (or explicitly deferred with rationale), all
playtesting-surfaced bugs are fixed and verified, and the full GUT suite
passes after the final round of balancing changes --- leaving a
balanced, kid-tested build ready for wider release.


## 4. Question Attempt Balancing

Playtesting must explicitly evaluate the configured `tries_per_question`
behavior. The global value defaults to one attempt, and selected levels may
use overrides. Test whether one attempt produces an appropriate practice
challenge and whether any higher-attempt level overrides improve learning
without creating excessive repetition.

Also verify that the red flash on an incorrect answer is immediately visible,
understood as feedback rather than success, and does not prevent the next
question from appearing when the attempt limit is reached.

## 5. Level Time-Limit Balancing

Playtesting must explicitly evaluate the level time budget. With the default
`seconds_per_wave = 30`, a four-wave level gives 120 seconds; observe whether
target-age players can realistically finish while still feeling gentle time
pressure. Tune `seconds_per_wave` globally or per level via
`gameplay/level_time_limit_by_level`. Confirm the HUD countdown, pause
freezing, wave-transition continuity, and the "Time's up!" Game Over path all
remain intact after any tuning change (full GUT regression required).
