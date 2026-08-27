# Math Invaders (Godot Edition): Build Plan

The guiding rule: **after every phase, the game should run and be
playable end-to-end**, even if it looks and feels rough. Each phase adds
one layer of depth on top of a working loop, rather than building all
systems in parallel before anything is playable. See the companion
**Spec** and **Tech Stack** documents for the detailed rules and
architecture each phase implements.

Unit testing with **GUT** (see Tech Stack, Section 8) is part of the
development process, not a separate pass --- each phase below includes
writing/updating GUT tests for the non-visual logic it introduces, and a
phase isn't considered done until its tests are green alongside the
playable milestone.

------------------------------------------------------------------------

### Phase 0 --- Project Setup (½--1 day)

-   Install Godot 4, create project, set portrait resolution (e.g.,
    720×1280) and mobile render settings.
-   Register the gameplay project settings `gameplay/starting_lives`
    (default 3) and `gameplay/enemies_per_wave` (default 10), with a
    single configuration-access path.
-   Set up Git repo and folder structure, including
    `scripts/questions/strategies/`, `test/unit/questions/`, and
    `assets/images/` (background/, ships/, enemies/, ui/, effects/ per
    the Tech Stack doc).
-   Import whichever real image assets are already available (even a
    partial set); drop same-dimension placeholder PNGs into the matching
    asset folders for anything not yet supplied, per the Spec's asset
    table.
-   Install the **GUT** addon (AssetLib or Git submodule under
    `addons/gut/`), enable it under Project Settings → Plugins, and add
    a `.gutconfig.json` pointing at `test/unit/`. Confirm it runs (even
    with zero tests) from both the editor GUT panel and the command
    line.
-   **Milestone:** empty Godot project runs on device/emulator and
    in-editor, with the asset folder structure in place, GUT installed
    and runnable, and ready to reference.

### Phase 1 --- Minimum Playable Loop (first thing you can actually play)

-   Real background image (`background_space.png`, or its placeholder)
    as a full-screen `TextureRect`/`Sprite2D` --- no stars/parallax
    animation yet, just the static image.
-   Real player ship sprite (`player_ship.png`) on the `Player` node
    instead of a `ColorRect`.
-   One enemy using its real category sprite (e.g.,
    `enemy_ship_addition.png`) that appears at the top (the full
    10-enemy formation is introduced in Phase 3 --- this phase just
    proves out spawn → answer → destroy).
-   One hardcoded addition question, with the question panel and answer
    buttons already using `question_panel_bg.png` and
    `answer_button_normal.png` rather than default Godot theme buttons.
-   Tapping correct answer: enemy disappears (no bullet sprite/animation
    yet), score +1 shown as plain text.
-   Tapping wrong answer: Phase 1 itself still has no damage system; it
    simply keeps the question active. The mistake/lives consequence is
    introduced in Phase 2.
-   **Milestone: fully playable, single-question game loop, already
    built on the real (or correctly-sized placeholder) art assets** ---
    not colored rectangles. This is the "something to see and play"
    deliverable, and it already looks like the intended game rather than
    a wireframe.

### Phase 2 --- Question Strategy Pattern & Bullets

-   Implement `question_strategy.gd` (base class) and the first two
    concrete strategies: `addition_strategy.gd`,
    `subtraction_strategy.gd`.
-   Implement `question_generator.gd` as the dispatcher that delegates
    to the right strategy by category name.
-   Add the real bullet sprite (`player_bullet.png`): player fires a
    visible projectile on correct answer that travels to the enemy
    before it's destroyed.
-   Wrong answer: the enemy/formation is unaffected and remains
    stationary. Emit the wrong-answer event used by the later life
    system; do not implement enemy descent as a penalty.
-   Enemy sprite now swaps correctly between `enemy_ship_addition.png`
    and `enemy_ship_subtraction.png` depending on which category is
    active, confirming the per-instance texture-swap approach from the
    Tech Stack doc.
-   **Testing:** add `test_addition_strategy.gd` and
    `test_subtraction_strategy.gd` (correct result, exactly one correct
    choice among 4, no duplicate distractors) and
    `test_question_generator.gd` (dispatches to the right strategy by
    category name; handles an unknown category gracefully).
-   **Milestone:** playable game where questions are procedurally
    generated (not hardcoded) for two categories, with visible shooting
    feedback and category-correct enemy art --- and
    `addition`/`subtraction`/`question_generator` tests passing under
    GUT.

### Phase 3 --- Wave Structure (10 Enemies Visible per Screen)

-   Implement `WaveManager.gd`: a wave = 10 enemies from a single
    category, **all spawned together in a formation when the wave
    starts**, not one at a time --- each using the real sprite for that
    wave's category.
-   Wrong answers never move the formation. The active enemy and
    question remain selected until the answer is correct; this is the
    core practice mechanic.
-   One enemy at a time is "active" (linked to the currently-displayed
    question); on a correct answer that enemy is destroyed and removed,
    so the player sees the on-screen formation visibly shrink (10 → 9 →
    8 → ...).
-   Add `multiplication_strategy.gd` and `division_strategy.gd`,
    registered in `question_generator.gd`, along with their matching
    `enemy_ship_multiplication.png`/`enemy_ship_division.png` sprites.
-   Wire up wave sequencing: Addition (10) → Subtraction (10) →
    Multiplication (10) → Division (10). When a wave's 10 enemies are
    all cleared, a **fresh set of 10** spawns for the next category.
-   Add the `wave_complete_banner.png` transition between waves.
-   Update HUD to show enemies remaining in the current wave (e.g.,
    "6/10 remaining"), matching the visible formation count.
-   **Testing:** add `test_multiplication_strategy.gd` and
    `test_division_strategy.gd`; add `test_wave_manager.gd` covering
    wave-clear detection, correct category sequencing, fresh 10-enemy
    spawns, deterministic active-enemy selection, and the invariant that
    a wrong answer does not move the formation.
-   **Milestone:** a full playthrough of one level's worth of waves,
    each starting with a full 10-enemy formation of correctly-skinned
    ships that visibly shrinks as questions are answered correctly, with
    a clear sense of progress both on screen and in the HUD --- backed
    by passing strategy and `WaveManager` tests.

### Phase 4 --- Lives, Wrong-Answer Feedback & Game Over

-   Implement the lives-only damage model: every wrong answer consumes
    exactly one life; no health pool and no enemy-bottom damage trigger.
-   Configure `gameplay/starting_lives` in Project Settings (default 3);
    render repeated `life_icon.png` in the HUD.
-   Wrong-answer feedback includes the active enemy visibly firing an
    `enemy_bullet.png` projectile at the player (purely presentational;
    damage stays event-driven).
-   **Parallel answer resolution:** all gameplay consequences of an
    answer resolve immediately --- on a correct answer, score, enemy
    destruction, and the next question happen in the same frame the
    bullet *launches*; on a wrong answer, life loss/attempts/Game Over
    resolve instantly and only the next question's display may wait out
    the brief red-flash interval. No question ever waits on bullet
    travel, so flight time never eats into answering time.
-   Fixed bullet travel: all bullets --- player and enemy --- take
    exactly **0.3 seconds** to reach their target in all cases
    (fixed-duration tween, distance-independent), replacing any slow
    travel.
-   When lives reaches 0, enter Game Over immediately and disable
    answer input ("Out of lives!"); `last_game_over_reason` records
    why (`LIVES_DEPLETED`; `TIME_EXPIRED` joins in Phase 5).
-   **Testing:** add/update `test_game_manager.gd` covering
    one-life-per-wrong-answer, no damage on correct answers, game over
    exactly at zero lives, configured starting lives, session reset,
    reason recording --- plus `test_game_config.gd` coverage of
    starting-lives fallbacks.
-   **Milestone:** full round-trip play session (start → answer
    correctly/incorrectly → see enemy return fire → run out of lives →
    game over screen), with questions always answerable while bullets
    are still mid-flight, and the lives/attempt state machine covered
    by passing tests.

### Phase 5 --- Level Timer

-   Add the per-level time limit: configurable via
    `gameplay/seconds_per_wave` (default 30) with optional per-level
    overrides in `gameplay/level_time_limit_by_level`; the default limit
    is waves × seconds-per-wave (120 s for the four-wave Level 1).
-   Expiring fails the level via Game Over ("Time's up!", reason
    `TIME_EXPIRED`). HUD shows a live countdown bound to
    `GameManager.time_remaining`; the timer runs only while playing,
    never resets between waves, and answers/bullets never add to or
    pause it beyond real elapsed ticks.
-   `GameManager` owns `time_remaining`/`level_time_limit` and advances
    through a deterministic `tick(delta)` so GUT tests need no scene
    tree or wall clock. Answer resolution precedes expiry processing
    each frame.
-   **Testing:** extend `test_game_manager.gd` with timer
    tick/expiry/pause/reset cases and `test_game_config.gd` with the
    new time-limit settings and override resolution.
-   **Milestone:** beat-the-clock sessions --- clear every wave inside
    the level budget or lose to "Time's up!" --- with the timer state
    machine covered by passing tests.

### Phase 6 --- Level Progression

-   Implement `LevelManager.gd`: completing all waves in a level
    triggers the `level_complete_banner.png` transition and advances to
    the next level.
-   Increase difficulty parameter passed into `QuestionGenerator` as
    levels increase (larger numbers within the same four categories).
-   Update HUD to display the current **Level** alongside score and
    lives.
-   When a level is completed, reset lives to the configured
    `gameplay/starting_lives` value and restart the level timer at the
    new level's resolved limit (`GameConfig.get_level_time_limit(level,
    wave_count)`) before starting the next level. This
    is the proficiency checkpoint: the player must clear every wave in
    the current level --- within its time budget --- to advance.
    Ordinary wave transitions never reset the timer.
-   **Testing:** add `test_level_manager.gd` covering difficulty
    scaling, category sequencing, level advancement, the
    level-boundary lives reset, and the level-boundary timer
    resolution/reset (including that per-level overrides change only
    that level's budget).
-   **Milestone:** playing through multiple levels, each with the same
    wave/category structure but increasing difficulty, with
    `LevelManager` behavior covered by passing tests.

### Phase 7 --- Score & High Score Persistence

-   Score display refined (top of screen, styled with the HUD's chosen
    font/iconography).
-   `HighScoreManager.gd` saves/loads high score to local storage
    (`user://`).
-   Game Over screen shows "New High Score!" when beaten, and shows
    current high score otherwise.
-   **Testing:** add `test_high_score_manager.gd` covering that the
    stored high score only updates when the new score is higher, and
    that save/reload round-trips correctly --- using GUT's temp-file
    helpers rather than the real `user://` save file.
-   **Milestone:** high scores persist across app restarts, with
    `HighScoreManager`'s save/compare logic covered by passing tests.

### Phase 8 --- New Question Categories (Stage C Content)

-   Add `prime_strategy.gd` (and any other advanced-concept strategies)
    as new files under `scripts/questions/strategies/`, registered with
    `question_generator.gd` --- no changes needed to existing category
    strategies.
-   Add the matching `enemy_ship_prime.png` sprite for the new category.
-   Update `LevelManager.gd` to introduce these new categories as
    additional waves once a player reaches a defined advanced level.
-   **Testing:** add `test_prime_strategy.gd` (mirroring the existing
    strategy tests) and extend `test_level_manager.gd` to cover that the
    new category is added to the rotation at the correct threshold.
-   **Milestone:** advanced levels include new wave types (e.g., a
    "Prime Numbers" wave) layered on top of the existing four core
    categories, each with its own correct art, and covered by the same
    strategy-level test pattern established in earlier phases.

### Phase 9 --- Level Configuration & Player Experience

-   Introduce `LevelConfig.gd` as a Custom Resource to centralize level definitions (categories, difficulty, timer, attempts).
-   Update `LevelManager.gd` to load `.tres` level files.
-   Add a Mastery condition: clear a level flawless (0 lives lost) 3 times in a row to unlock the next level.
-   Allow players to select their starting level from unlocked levels, and initialize the game with their personal best score from skipped levels.
-   Add a Name Entry on the Main Menu and a Splash Screen.
-   Add a "Review Mistakes" button on Game Over to review incorrect answers.
-   Add a Developer Level Select toggle to force start at any level.
-   **Milestone:** Game incorporates centralized level configs, persists unlocked progression, handles assumed score on level skip, and includes Mistake Review and Splash Screen UI.

### Phase 10 --- Effects, Animation & Audio Polish

-   Add the `enemy_explosion_spritesheet.png` destruction animation on
    correct answers (replacing the simple "disappear" from earlier
    phases).
-   Add the `starfield_overlay.png` parallax/scroll animation over the
    background (replacing the static background image from Phase 1).
-   Add screen shake or flash on taking damage, and polished tap/press
    feedback using `answer_button_pressed.png`.
-   Add sound effects (fire, hit, miss, enemy return fire, player hit,
    wave complete, level complete, game over) and background music.
    Add a low-time warning: the HUD timer label pulses red and/or ticks
    audibly during the final 10 seconds of a level's budget
    (presentational only).
-   Any remaining placeholder images (from Section 7 of the Spec) are
    swapped for final art at this point, if not already replaced in
    earlier phases.
-   **Milestone:** game looks and sounds like a finished mobile game.

### Phase 11 --- Mobile Export & Touch Optimization

-   Configure Android/iOS export presets in Godot.
-   Verify touch target sizes for answer buttons (44px+ minimum touch
    targets), test on real devices/emulators.
-   Handle safe-area insets for notches on portrait phones.
-   **Milestone:** installable build running on Android and/or iOS
    device.

### Phase 12 --- Integer Strategy Renaming & Category Key Migration

-   Rename the four core strategies end-to-end: `addition` →
    `integer_addition`, `subtraction` → `integer_subtraction`,
    `multiplication` → `integer_multiplication`, `division` →
    `integer_division` (files, classes, generator keys, enemy texture
    map, default sequences, all level `.tres` files, tests).
-   Introduce the category display-name registry so the HUD keeps
    showing "Addition"/"Subtraction"/... rather than raw keys.
-   Pure refactor: behavior-preserving, full GUT suite green.
-   **Milestone:** naming foundation for the number-type categories,
    game plays identically to Phase 11. See
    `specs/phases/Phase_12_Integer_Strategy_Renaming.md`.

### Phase 13 --- Fraction Foundations: Addition & Subtraction

-   Extend the answer-value model so `correct_answer`/`choices` may be
    canonical strings; add the shared `FractionValue` helper.
-   Add `fraction_addition` and `fraction_subtraction` strategies with
    the two-axis difficulty ladder (operand size AND unlike
    denominators at higher tiers), proper/improper/mixed representation
    mix, mandatory simplification, and value-distinct choices.
-   Stacked fraction rendering (numerator above denominator) in the
    question text AND on all four answer buttons, preserving touch
    targets/red flash/safe areas.
-   Category sprites + level authoring (fraction debut waves).
-   **Milestone:** fraction waves playable with stacked simplified
    answers; reusable foundation for Phases 14--16. See
    `specs/phases/Phase_13_Fraction_Addition_And_Subtraction.md`.

### Phase 14 --- Fraction Multiplication & Division

-   Add `fraction_multiplication` and `fraction_division` reusing the
    Phase 13 foundation: tiered ladders through cross-canceling and
    reciprocal reasoning, mixed-number operands at higher tiers,
    simplified value-distinct answers, stacked display.
-   Category sprites + level authoring.
-   **Milestone:** all four fraction operations shipped with zero edits
    to the Phase 13 foundation files. See
    `specs/phases/Phase_14_Fraction_Multiplication_And_Division.md`.

### Phase 15 --- Decimal Strategies (Add/Sub/Mul/Div)

-   Add the four decimal strategies computing exclusively via shared
    scaled-integer arithmetic (never floats), canonical formatting
    rules, terminating-decimal-only division built divisor-first, and
    difficulty scaling along `max_decimal_places` plus magnitude.
-   Place-shift/off-by-one distractors, category sprites, level
    authoring.
-   **Milestone:** exact decimal arithmetic across all four operations
    on the existing plain-text answer pipeline. See
    `specs/phases/Phase_15_Decimal_Strategies.md`.

### Phase 16 --- Ratio & Proportion and HCF & LCM

-   Add `ratio_proportion` (proportion solving, ratio sharing,
    unit-rate scaling --- tiered forms) and `hcf_lcm` (tiered HCF/LCM
    identification with meaningful near-miss distractors).
-   Integer answers: no rendering/pipeline changes; registration,
    sprites, level roster extension (`level_6.tres` if needed).
-   **Milestone:** Spec §12 category registry complete with zero edits
    to existing strategies. See
    `specs/phases/Phase_16_Ratio_Proportion_HCF_LCM.md`.

### Phase 17 --- Configurable Points Per Question Per Level

-   `LevelConfig` gains `points_per_question` (default `1`,
    Inspector-editable, validated ≥ 1); `Main` awards the resolved
    value per correct answer instead of hardcoded `+1`.
-   Personal bests, assumed full score, high scores verified untouched
    (totals only).
-   **Milestone:** per-level scoring tuned via `.tres` files; defaults
    byte-identical to prior behavior. See
    `specs/phases/Phase_17_Points_Per_Question_Scoring.md`.

### Phase 18 --- Per-Wave Enemy Ship Image Sets

-   `LevelConfig` gains `wave_enemy_textures` (index-aligned with
    `category_sequence`); a wave's set of images is assigned to spawn
    slots cyclically --- slot `k` uses `set[k % set.size()]` (10 slots /
    3 images → ship1, 2, 3, 1, 2, 3, 1, 2, 3, 1).
-   Empty sets fall back to the category sprite; bad paths warn and
    fall back per slot; presentation only.
-   **Milestone:** per-wave ship art variety configured entirely in
    level resources. See
    `specs/phases/Phase_18_Wave_Enemy_Ship_Images.md`.

### Phase 19 --- Player Ship Image Per Level

-   `LevelConfig` gains `player_ship_texture` (empty = default
    `player_ship.png`; missing files fall back with a warning),
    applied at every level start, transition, and Play Again.
-   **Milestone:** completes the per-level visual/scoring configuration
    trio (17--19). See `specs/phases/Phase_19_Player_Ship_Image.md`.

### Phase 20 --- Fraction Question & Answer Layout Fix

-   Fix stacked-fraction rendering so fraction questions and answer
    buttons are **centered** (not left-aligned): the stacked-fraction
    control added to each answer button fills the button and centers its
    content, and the question stack host spans the panel width and
    centers its segments.
-   Redefine the question panel layout to give the question area more
    vertical space and eliminate the overlap between the question text
    and the answer buttons (question row 16--76 → 8--88; answer grid
    moved down so the buttons sit at y 95--335).
-   Preserve the 360px panel height and the Phase 11 safe-area insets
    behavior unchanged; the new internal layout stays within the panel.
-   **Milestone:** fraction questions and answers render centered and
    readable with no overlap, integer (plain-text) questions unchanged,
    full GUT suite green. See
    `specs/phases/Phase_20_Fraction_Question_Answer_Layout_Fix.md`.

### Phase 25 --- Playtesting & Balancing

-   Playtest with target age group; adjust question difficulty pacing
    per level, distractor plausibility, wave length feel, and the
    level time-limit feel based on observations --- now spanning ALL
    categories (integers, fractions, decimals, ratio/HCF-LCM) plus the
    per-level point values and ship-image selections.
-   Fix bugs found during testing; run the full GUT suite after
    balancing changes to catch regressions in difficulty scaling,
    distractor generation, and wave/level logic.
-   **Milestone:** balanced, kid-tested build ready for wider release,
    with the full GUT suite passing.

### Phase 26 --- Stretch / Future Expansion

-   Additional math concepts as new strategies (percentages;
    fraction-decimal-percent conversions).
-   Player profiles for multiple kids on one device.
-   Wave/level select or endless-mode toggle.
-   Additional non-math subject modules (spelling, science) reusing the
    same wave/level and strategy-pattern framework.


## Phase Change Note — Configurable Question Attempts

The gameplay contract now includes a configurable maximum number of attempts
per question. The global Project Setting `gameplay/tries_per_question`
defaults to `1`; `gameplay/tries_per_question_by_level` can override it for
individual levels. A wrong answer flashes the tapped button red and consumes
one life. With one allowed attempt, the next question is loaded after the
feedback. With a higher level override, the same question remains active until
its allowed attempts are exhausted.

This replaces the previous assumption that a wrong answer should keep the same
question indefinitely. Enemy/formation descent remains removed.


## Phase Change Note — Level Timer, Enemy Return Fire, and Fixed Bullet Travel Time

Three related gameplay changes extend Phase 4/5 and ripple forward:

1. **Per-level time limit (now its own Phase 5).** New Project Settings
   `gameplay/seconds_per_wave` (default `30`) and
   `gameplay/level_time_limit_by_level` (default `{}`). A level's
   effective limit is a valid per-level override, otherwise
   `wave_count × seconds_per_wave` — 120 seconds for the four-wave
   Level 1. The timer runs only while playing, never resets between
   waves, and expiry fails the level via Game Over with reason
   `TIME_EXPIRED`. `GameManager` owns `time_remaining` and is ticked
   deterministically for testability; `GameConfig.gd` is the only
   access path.
2. **Enemy return fire on wrong answers (Phase 4).** The active enemy plays a
   brief fire animation and shoots an `enemy_bullet.png` projectile at
   the player whenever an answer is wrong. It is purely presentational:
   one life is still consumed by the authoritative event path, and no
   collision-based damage may be introduced.
3. **Fixed bullet travel time (Phase 4).** All bullets — player and enemy — take
   exactly **0.3 seconds** from source to target in every case,
   implemented as a fixed-duration tween shared via `bullet.gd`
   (`TRAVEL_TIME`), replacing distance-dependent/slow travel.

Phase 6 restarts the timer at each level boundary; Phase 10 adds
enemy-fire/player-hit sounds and a low-time warning; Phase 25 (renumbered
from 12 --- see the final change note) treats the time budget as a tuning
dimension.


## Phase Change Note — Parallel Answer Resolution, Triangle Formation, and the Phase 4 Split

Three changes, applied to both the requirements and the existing code:

1. **Parallel answer resolution.** Bullet flight is now strictly
   cosmetic in both directions. On a correct answer, score, active-enemy
   destruction, and loading the next question resolve in the same frame
   the player bullet launches — the player can answer again while the
   bullet is still mid-flight. On a wrong answer, life loss, attempt
   counting, and any Game Over resolve immediately; only the next
   question's display may wait out the ~0.18 s red-flash interval, and
   it never waits for the enemy bullet's launch or arrival. This makes
   bullet travel (0.3 s each way) cost zero answering time. Normative
   home: Phase 4 FR4.13; Spec §10.
2. **Inverted-triangle formation.** The 2×5 grid is replaced by an
   inverted triangle of 4 + 3 + 2 + 1 = 10 enemies, each row centered on
   the screen's horizontal axis. The single bottom tip is the frontmost
   target under the existing active-enemy ordering rule (lowest Y,
   then lowest X). Normative home: Phase 3 FR3.2 and Implementation
   Plan step 3; Spec §3.
3. **Phase 4 split.** The old Phase 4 (lives + level timer + game over)
   was too heavy to land as one playable increment. It is now two
   phases: **Phase 4 — Lives, Wrong-Answer Feedback & Game Over**
   (playable end-to-end without time pressure) and **Phase 5 — Level
   Timer** (the countdown layered onto that working game). All later
   phases shift by one: Level Progression 5→6, Score & High Score 6→7,
   New Categories 7→8, Level Config & Experience 8→9, Effects/Audio 9→10, Mobile Export 10→11,
   Playtesting & Balancing 11→12, Stretch 12→13.

## Phase Change Note — Strategy Expansion, Level Visual Config, and the Phase 12→20 Renumbering

A new requirements batch extends the question categories and per-level
configuration, and the roadmap is renumbered to fit it:

1. **Renumbering.** The old **Phase 12 — Playtesting & Balancing** moves
   to **Phase 25** (its phase doc is now
   `specs/phases/Phase_25_Playtesting_And_Balancing.md`), and the old
   Phase 13 Stretch section becomes **Phase 26**. Phases 0–11 are
   untouched and remain implemented as shipped.
2. **New Phases 12–16 (question strategies).**
   Phase 12 renames the four core strategies/keys to `integer_*`
   (`addition→integer_addition`, `subtraction→integer_subtraction`,
   `multiplication→integer_multiplication`, `division→integer_division`)
   and adds a category display-name registry. Phases 13–14 add the four
   fraction strategies (unlike-denominator difficulty ladder,
   proper/improper/mixed representations, mandatory simplification,
   stacked numerator-over-denominator rendering in questions AND answer
   buttons, canonical string answers via a shared `FractionValue`
   helper). Phase 15 adds the four decimal strategies on shared
   scaled-integer arithmetic with canonical formatting and
   terminating-only division. Phase 16 adds ratio & proportion and
   HCF & LCM. Normative home for keys/display names/answer model:
   Spec §12.
3. **New Phases 17–19 (per-level configuration).** Phase 17 adds
   `points_per_question` per level (default 1). Phase 18 adds
   per-wave enemy image sets assigned cyclically by spawn slot
   (`slot k → set[k mod set.size()]`; 10 slots / 3 images renders
   ship1, ship2, ship3, ship1, … exactly). Phase 19 adds a per-level
   player ship image. All live in `LevelConfig` resources; all are
   presentation/scoring only with safe fallbacks. Normative home:
   Spec §13.
4. **Stretch content moved.** Fractions and factors/multiples-style
   content is now planned work (Phases 13–16); percentages and
   fraction-decimal-percent conversions remain stretch (Phase 26).

Playtesting (Phase 25) therefore tunes the whole expanded game:
category pacing across integers/fractions/decimals/ratio/HCF-LCM,
per-level point values, and ship-image variety.


## Phase Change Note — Fraction Layout Fix and the Phase 20→25 Renumbering

A rendering fix for stacked fractions is inserted as a new phase, and the
roadmap is renumbered to make room for further improvements before
playtesting:

1. **New Phase 20 — Fraction Question & Answer Layout Fix.** Stacked
   fraction questions and answer buttons were rendering **left-aligned**
   (the fraction controls were added to plain `Control` parents without
   anchors, so `ALIGNMENT_CENTER` had no effect), and the question area
   overlapped the answer buttons. The new phase centers the fraction
   content in both the question row and every answer button, enlarges the
   question area, and moves the answer grid down to remove the overlap —
   while preserving the 360px panel height and Phase 11 safe-area
   behavior. Normative home: Spec §5 (clear fraction display) and §3
   (screen layout); Tech Stack §5 (`question_panel.gd`).
2. **Renumbering.** The old **Phase 20 — Playtesting & Balancing** moves
   to **Phase 25** (its phase doc is now
   `specs/phases/Phase_25_Playtesting_And_Balancing.md`), and the old
   Phase 21 Stretch section becomes **Phase 26**. Phases 0–19 are
   untouched and remain implemented as shipped. Phases 21–24 are reserved
   for further improvements and changes before playtesting.
