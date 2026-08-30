# Math Invaders (Godot Edition): Game Specification

## 1. Game Overview

**Math Invaders** is a portrait-mode mobile math game built in Godot.
Players defend against waves of enemy ships by answering multiple-choice
math questions. Answering correctly fires a bullet that destroys the
targeted enemy; answering wrong deals one point of damage by consuming one life,
visualized by the active enemy firing a bullet back at the player. Each level
has a configurable time limit --- defaulting to 30 seconds per wave (120
seconds for the four-wave Level 1) --- and running out of time fails the level
via Game Over. By default, each question has
one allowed attempt: an incorrect answer flashes the selected answer red,
consumes one life, and then the next question is shown. The allowed-attempt
count is configurable globally and can be overridden per level. When a level
allows more than one attempt, an incorrect answer still consumes one life
and flashes red; the same question remains available until its configured
attempt limit is exhausted, after which the next question is shown.

**Target audience:** Primary-school children (ages 6--12), starting with
simple 1--2 digit addition/subtraction/multiplication/division, scaling
up to larger numbers and new concepts (primes, factors, etc.) as players
progress.

**Design priority:** Something playable exists from the very first build
--- a ship, one enemy, one question, and a working
shoot-on-correct-answer loop --- before waves-of-10, levels, and other
systems are layered on.

**Art priority:** The player's own image assets (ships, background,
question/answer UI, etc.) are used starting in the first playable build
--- not swapped in at the end as "polish." See Section 7 for the full
sprite list and Section 8 for how integration is staged across phases.

------------------------------------------------------------------------

## 2. Wave & Level Structure

Rather than enemies spawning continuously and indefinitely, gameplay is
broken into **fixed screens ("waves")** of exactly **10 enemies each**,
and waves are grouped into **levels**:

-   **Wave:** one screen of gameplay = **all 10 enemies appear on screen
    at once** when the wave begins, all drawn from a **single math
    category**. For example, "Wave 1: Addition" starts with 10 enemy
    ships visible, each tied to an addition question.
-   **Visible depletion:** the player answers one question at a time
    (tied to the currently-targeted enemy), and that enemy is
    destroyed/removed on a correct answer. The remaining enemies stay
    visible on screen, so the player can see the formation shrink from
    10 down to 0 as they answer correctly --- this visible reduction is
    the core feedback loop for a wave.
-   **Level:** a set of waves. A level cycles through the core
    categories in sequence, e.g.:
    -   Level 1 → Wave 1: Addition (10 enemies) → Wave 2: Subtraction
        (10 enemies) → Wave 3: Multiplication (10 enemies) → Wave 4:
        Division (10 enemies)
    -   When a wave's 10 enemies are all eliminated, a **new set of 10
        enemies appears** for the next wave/category.
    -   Completing all waves in a level advances the player to the
        **next level**.
-   **Progression across levels:** each new level keeps the same
    category sequence but raises difficulty (larger numbers, and a
    level time limit that must be cleared within the per-level budget),
    and later levels introduce new categories as
    additional waves (e.g., a "Prime Numbers" wave added once players
    reach an advanced level). Because the default limit is computed
    from the wave count, adding a 5th wave raises the default budget to
    150 seconds unless overridden.
-   At the end of a wave, a brief transition ("Wave Complete!") shows
    before the next wave's fresh set of 10 enemies appears. The level
    timer pauses for a configurable `wave_complete_pause_seconds` (default
    2 s) with no question shown, then the next wave's enemies arrive **one
    row at a time** (0.5 s per row; 4 rows = 2 s) before the first question
    appears (Spec §15). At the end of a level, a "Level Complete!"
    transition shows before the next level begins, and the completed
    level's score is adjusted for early-finish bonus and lives-lost
    penalty (Spec §16).

This replaces the original "continuous descending waves" concept with a
**structured, per-category mini-level format** where the full 10-enemy
formation is visible at once and visibly shrinks as the player answers
correctly --- making progress legible to a young player ("I'm on Level
2, Subtraction, 4 enemies left") and making it straightforward to
control exactly which math skill is being practiced at any moment.

------------------------------------------------------------------------

## 3. Screen Layout (Portrait, e.g. 720×1280 base resolution)

    ┌─────────────────────────────┐
    │ Score:120 Lvl 2 🚀x2 ♥♥♥ ⏱87 │  ← HUD (top)
    │         Subtraction  6/10    │  ← Wave/category + remaining count
    │       E   E   E   E          │  ← Formation row 1 (4 enemies)
    │         E   E   E            │  ← Row 2 (3)
    │           E   E              │  ← Row 3 (2) --- shrinks as answered
    │             E                │  ← Row 4: the "tip" (active target)
    │                  ↑            │     Deep space bg (near-black/
    │                bullet         │     dark navy, sparse stars)
    │                               │
    │           🚀 (player)         │  ← Player ship, fixed near bottom
    ├──────────────────────────────┤
    │      What is 15 − 8?          │  ← Question panel
    │  [ 7 ]  [ 8 ]  [ 6 ]  [ 9 ]  │  ← Answer buttons
    └──────────────────────────────┘

-   **Background:** Near-black / dark navy scene with a sparse,
    slowly-parallaxing starfield. The starfield scrolls **downward**
    (stars stream past the camera toward the bottom of the screen),
    matching the player ship's forward/upward motion; scrolling the
    other way makes the ships look like they are flying backward.
-   **Player ship:** Fixed horizontal position near the bottom, above
    the question panel; visually fires when a correct answer is chosen.
-   **Enemies:** All 10 enemies for the current wave spawn together at
    the start of the wave in an **inverted-triangle formation** ---
    rows of 4, 3, 2, and 1 enemies from top to bottom, each row
    centered on the screen's horizontal axis --- and remain stationary
    while the player answers. One enemy at a time is the "active"
    target tied to the current question; by the lowest-Y-then-lowest-X
    ordering this is naturally the triangle's bottom tip first, then
    upward row by row. As questions are answered correctly, that
    enemy is destroyed and removed, visibly shrinking the formation. A
    wrong answer does not move or remove any enemy.
-   **Question panel:** Anchored to the bottom of the screen, always
    visible, holding the question text and 4 tappable answer buttons. The
    question area is sized to fit stacked-fraction questions and is
    separated from the answer grid so the two never overlap (Phase 20);
    the panel keeps its fixed height and safe-area insets.
-   **HUD (top of screen):**
    -   Score
    -   **Level** (new)
    -   **Lives** --- rendered as repeated `life_icon.png` mini-ships in
        the **bottom-left** corner of the screen, clear of the enemy
        formation (the top row of the inverted triangle must never
        overlap the lives display)
    -   **Time remaining in the level** (new)
    -   **Current wave category + enemies remaining in the wave** (e.g.,
        "Subtraction 6/10 remaining") (new)

------------------------------------------------------------------------

## 4. Core Gameplay Loop

1.  When a wave begins, its category (e.g., Addition) is set, and **all
    10 enemies spawn together** in a formation at the top of the screen.
    A question is generated for the current difficulty and linked to one
    "active" enemy (e.g., the frontmost/lowest one).
2.  The question and its 4 choices are shown in the question panel, tied
    to the active enemy.
3.  Player taps an answer button.
4.  **Correct:** player ship fires a bullet at the active enemy and,
    in the same instant, the score increases and the next question loads
    immediately: the player can answer again while the bullet is still
    visibly mid-flight. The targeted enemy remains visible but is excluded
    from active-enemy selection until the bullet's arrival confirms
    the hit, destroying the enemy and updating
    wave progress (e.g., "6/10 remaining"). The player visibly sees
    the remaining count drop (e.g., 10 → 9) upon bullet impact.
5.  **Incorrect:** the active enemy and the rest of the formation remain
    in place. The selected answer button flashes red, the active enemy
    visibly fires a bullet at the player ship (traveling for exactly
    0.3 seconds and ending in a brief player-hit flash --- purely
    presentational), and the player takes
    one point of damage: exactly one life is consumed, immediately ---
    never delayed by any animation. With the default
    `tries_per_question = 1`, the current question is retired and a new
    question is loaded as soon as the brief red-flash interval ends,
    never waiting on the enemy bullet. If the current level overrides
    the setting to a value greater than 1, the same question may remain
    active until the configured number of attempts has been used; every
    wrong attempt still consumes exactly one life. No enemy is destroyed
    or moved by a wrong answer.
6.  **Life depletion:** when lives reach 0, the game enters `GAME_OVER`
    immediately and disables further answering. The number of starting
    lives is configurable at project level; the default is 3.
7.  **Level time limit:** each level has a time limit (default:
    number of waves × 30 seconds; 120 seconds for Level 1) shown as a
    live countdown in the HUD. It runs only during play, continues
    across wave transitions within the level (except that it **pauses
    for the entire wave-transition sequence**, Spec §15), and is not
    consumed or extended by answers. When it reaches zero the level is
    failed and the game enters `GAME_OVER` exactly as for life
    depletion, with a "Time's up!" reason shown.
8.  When all 10 enemies in the current wave are eliminated → "Wave
    Complete" → the level timer pauses for `wave_complete_pause_seconds`
    (default 2 s) with no question shown, then a **fresh set of 10
    enemies** spawns for the next wave (next category) and **arrives one
    row at a time** (0.5 s per row) before the first question appears
    (Spec §15).
9.  When all waves in the level are cleared → "Level Complete" → the
    completed level's score is adjusted for the early-finish bonus and
    the lives-lost penalty (Spec §16), the player's lives reset to the
    configured starting-lives value, the level timer restarts at the new
    level's configured limit, then the next level begins with increased
    difficulty (and, at later levels, additional categories), again
    starting with a full set of 10 enemies.
10. Game over → submit the final score to the device-wide top-5
    leaderboard (Spec §14), update the high score if beaten, and show the
    result screen with a large rank medal when the score qualifies for the
    top 5, a "Personal Best!" congratulation when the player beats their
    own best session score, and a "Play Again" button.

------------------------------------------------------------------------

## 5. Educational Content Progression

### Stage A --- Launch content (earliest playable waves)

-   **Wave categories, in order:** Addition → Subtraction →
    Multiplication → Division
-   1--2 digit operands (e.g., 7+5, 23−9, 6×7, 42÷6)
-   4 answer choices per question: 1 correct + 3 plausible distractors
    (values near the correct answer or results of common mistakes, e.g.,
    off-by-one or wrong operation)

### Stage B --- Expanded difficulty (later levels)

-   Same four wave categories, but with larger numbers (2--3 digit
    operands)
-   **Lives are the only wrong-answer penalty:** each wrong answer consumes
    one life; no enemy descent is used as a penalty. The per-level time
    limit (Section 4, step 7) is a separate level-completion constraint,
    not an answer penalty --- answers never consume or add time.

### Stage C --- New concepts (advanced levels)

-   **Prime numbers** --- shipped in Phase 8 as the extensibility
    proving ground.
-   **Number-type operation families (Phases 13--16)** --- the four core
    operations re-expressed over richer number types, each family as its
    own registered category/wave:
    -   **Fractions:** `fraction_addition`, `fraction_subtraction`,
        `fraction_multiplication`, `fraction_division`.
    -   **Decimals:** `decimal_addition`, `decimal_subtraction`,
        `decimal_multiplication`, `decimal_division`.
-   **Concept categories (Phase 16):** `ratio_proportion` (proportion
    solving, ratio sharing, unit-rate scaling) and `hcf_lcm` (highest
    common factor / lowest common multiple identification).

#### Fraction content rules (Phases 13--14, authoritative with Spec §12)

-   **Difficulty scales on two axes:** not only larger numerators/
    denominators, but also the introduction of **unlike fractions** at
    higher difficulties (multiple-related denominator pairs first, then
    coprime pairs requiring LCD reasoning). The LevelConfig knob
    `allow_unlike_denominators` gates unlike-denominator generation.
-   **Representation coverage:** questions and answers include
    **mixed fractions and improper fractions** alongside proper
    fractions, introduced progressively from Tier 2 upward. Within one
    question all choices share one representation so format never leaks
    the correct answer; equivalence is judged on simplified value, never
    surface form.
-   **Simplification is part of solving:** every expected answer is
    reduced to lowest terms before display (a raw sum of 4/8 expects
    1/2). No choice may be value-equal to the correct answer or another
    choice.
-   **Clear fraction display:** fractions render stacked --- numerator
    above a horizontal bar above denominator --- in both the question
    text and every answer button; mixed numbers show the whole part
    beside the stacked remainder. Inline "a/b" text is acceptable only
    outside gameplay surfaces (Mistake Review, logs). Stacked fractions
    must be **centered** in the question row and in every answer button
    (Phase 20), and the question area must have enough room that it never
    overlaps the answer buttons.

#### Decimal content rules (Phase 15)

-   All arithmetic computed exactly via scaled integers (never binary
    floats); canonical formatting (no trailing zeros, single leading
    zero); division guarantees terminating decimals only, built
    divisor-and-quotient first.

### Distractor & Difficulty Rules

-   Distractors avoid duplicates and nonsensical values.
-   For fraction/decimal categories, "duplicate" includes **value
    equality**: an unsimplified equivalent (2/4 beside a correct 1/2) or
    a re-formatted decimal is still a duplicate of the correct answer
    and forbidden --- see Spec §12's answer-value model.
-   Difficulty (number range and operand size) is parameterized per
    level, not hardcoded per question --- the same category can be asked
    at many difficulty tiers as levels increase.

------------------------------------------------------------------------

## 6. HUD Requirements (Updated)

The HUD must always show, during play: 1. **Score** --- running total,
top of screen 2. **Level** --- current level number 3. **Wave category +
enemies remaining** --- e.g., "Multiplication 7/10 remaining", so the
player knows what skill they're practicing and can see, both in the HUD
text and in the shrinking enemy formation, how far through the current
wave they are 4. **Lives** --- remaining lives, shown as repeated
`life_icon.png` mini-ships in the **bottom-left** corner of the screen
(never overlapping the enemy formation) 5. **Time remaining** ---
the current level's countdown, always matching
`GameManager.time_remaining`. Wrong-answer feedback is shown on the tapped
answer button by a brief red flash plus the active enemy firing a bullet at
the player.

High scores are tracked and persisted across sessions (see Tech Stack
document for storage approach).

------------------------------------------------------------------------

## 7. Project-Level Gameplay Configuration

The following gameplay values are configurable through Godot Project
Settings rather than hardcoded in gameplay scripts:

  -------------------------------------------------------------------------------------
  Setting                       Type                           Default Meaning
  ----------------------------- ---------------- --------------------- ----------------
  `gameplay/starting_lives`     Integer                            `3` Number of lives
                                                                       granted at the
                                                                       start of a
                                                                       session and
                                                                       reset at each
                                                                       level completion

  `gameplay/enemies_per_wave`   Integer                           `10` Number of
                                                                       enemies spawned
                                                                       in each wave;
                                                                       retained as the
                                                                       fixed wave size
                                                                       for the current
                                                                       design

  `gameplay/tries_per_question` Integer                           `1` Default maximum
                                                                       attempts allowed
                                                                       for one question

  `gameplay/tries_per_question_by_level` Dictionary              `{}` Per-level
                                                                       overrides; a
                                                                       level key replaces
                                                                       the global value

  `gameplay/seconds_per_wave`   Float                            `30` Seconds granted per wave
                                                                       when computing a
                                                                       level's default time
                                                                       limit; minimum `1`

`gameplay/level_time_limit_by_level` Dictionary              `{}` Optional per-level total
                                                                       time-limit overrides in
                                                                       seconds; a valid
                                                                       positive value replaces
                                                                       the computed limit for
                                                                       that level

  `gameplay/wave_complete_pause_seconds` Float                     `2.0` Seconds the level timer
                                                                       pauses after a wave is
                                                                       cleared before the next
                                                                       wave's enemies arrive;
                                                                       minimum `0`

  `gameplay/bonus_seconds_per_point` Float                       `5.0` Seconds of remaining
                                                                       level time per
                                                                       early-finish bonus
                                                                       point; minimum `1`

`gameplay/lives_lost_penalty_points` Integer                    `1` Points deducted per
                                                                        life lost during a
                                                                        level; minimum `0`
  -------------------------------------------------------------------------------------

`starting_lives` is the mistake budget for the current level. Every
incorrect answer consumes exactly one life. When it reaches zero, the
game enters Game Over. The value must be read through a single
configuration-access path rather than scattered raw `ProjectSettings`
reads. `tries_per_question` defaults to `1`, so an incorrect answer normally
ends that question and loads the next one. `tries_per_question_by_level`
can override that value for individual levels; overrides must be positive
integers. If an override is greater than 1, the question remains active for
its remaining attempts before advancing. Each wrong attempt still costs one
life.

A level's effective time limit equals its valid per-level override from
`level_time_limit_by_level`, or otherwise `wave_count × seconds_per_wave`
--- with four waves and the default 30 seconds per wave, Level 1 gets
120 seconds. Reaching zero fails the level via Game Over ("Time's up!").
Both timer settings are read only through the same single configuration-
access path as the other gameplay settings.

`wave_complete_pause_seconds` is the number of seconds the level timer
pauses after a wave is cleared before the next wave's enemies arrive
(Spec §15); it is game-wide, not per level. `bonus_seconds_per_point` and
`lives_lost_penalty_points` drive the level-completion scoring
adjustments (Spec §16): completing a level early awards
`floor(time_remaining / bonus_seconds_per_point)` bonus points, and each
life lost during a level deducts `lives_lost_penalty_points` from that
level's score. All three are read only through the same single
configuration-access path as the other gameplay settings.

------------------------------------------------------------------------

## 8. Sprite & Image Asset List

All visual elements should be supplied as PNG files with transparency
where noted, sized for a **720×1280 portrait base resolution** (Godot
will scale for other device sizes). Godot doesn't require power-of-two
dimensions, but matching the sizes below keeps things from stretching or
blurring when the game scales to different screen sizes.

  -------------------------------------------------------------------------------------------------------------------
  Asset               File name (suggested)               Dimensions (px)    Transparency?   Notes
  ------------------- ----------------------------------- ------------------ --------------- ------------------------
  Deep space          `background_space.png`              720×1280 (or       No              Very dark navy/black,
  background                                              720×2560 if a                      sparse stars baked in,
                                                          taller image is                    or paired with a
                                                          supplied for slow                  separate star overlay
                                                          vertical                           below
                                                          scroll/parallax)                   

  Starfield overlay   `starfield_overlay.png`             720×1280,          Yes             Sparse star dots only;
  (optional separate                                      vertically                         layered above the solid
  layer)                                                  tileable                           background for a subtle
                                                                                             parallax scroll effect

  Player ship         `player_ship.png`                   128×128            Yes             Faces upward; fixed near the
                                                                                              bottom of the screen
                                                                                              above the question panel.
                                                                                              **Per-level variants:** each
                                                                                              level may select a different
                                                                                              player ship image via its
                                                                                              `LevelConfig` (Phase 19);
                                                                                              variants should match this
                                                                                              128×128 footprint;
                                                                                              empty selection = this default

  Player              `player_bullet.png`                 16×48              Yes             Travels upward from the
  bullet/projectile                                                                          player ship to the
                                                                                            active enemy in exactly
                                                                                            0.3 seconds

  Enemy               `enemy_bullet.png`                  16×48              Yes             Fired by the active enemy
  bullet/projectile                                                                          at the player on wrong
                                                                                            answers; travels downward
                                                                                            in exactly 0.3 seconds

  Enemy ship ---      `enemy_ship_addition.png`           96×96              Yes             One visual variant per
  Addition                                                                                   wave category so the
                                                                                             player can visually tell
                                                                                             categories apart

  Enemy ship ---      `enemy_ship_subtraction.png`        96×96              Yes             
  Subtraction                                                                                

  Enemy ship ---      `enemy_ship_multiplication.png`     96×96              Yes             
  Multiplication                                                                             

  Enemy ship ---      `enemy_ship_division.png`           96×96              Yes             
  Division                                                                                   

  Enemy ship ---      `enemy_ship_prime.png`              96×96              Yes             Added later alongside
  Advanced/Prime                                                                             the Prime strategy; same
                                                                                             dimensions as the other
                                                                                             enemy sprites

  Enemy ship ---      `enemy_ship_fraction_addition.png`,   96×96            Yes             One sprite per fraction/
  Fraction &          `enemy_ship_fraction_subtraction.png`,                                 decimal category (Phases
  Decimal             `enemy_ship_fraction_multiplication.png`,                              13--15); same dimensions;
  categories          `enemy_ship_fraction_division.png`,                                    placeholders acceptable.
                      `enemy_ship_decimal_addition.png`,                                     Additionally, any wave in
                      `enemy_ship_decimal_subtraction.png`,                                  any level may override its
                      `enemy_ship_decimal_multiplication.png`,                               images entirely via its
                      `enemy_ship_decimal_division.png`                                      LevelConfig's per-wave
                                                                                             image set (Phase 18) ---
                                                                                             e.g., custom `ship1.png`,
                                                                                             `ship2.png`, `ship3.png`
                                                                                             cycled across the formation

  Enemy ship ---      `enemy_ship_ratio_proportion.png`   96×96              Yes             Ratio & Proportion and
  Ratio / HCF-LCM     `enemy_ship_hcf_lcm.png`                                               HCF & LCM categories
  (Stage C)                                                                                  (Phase 16); same
                                                                                             dimensions; placeholders
                                                                                             acceptable

  Enemy explosion /   `enemy_explosion_spritesheet.png`   512×128 (4 frames  Yes             Played when an enemy is
  destruction effect                                      @ 128×128)                         destroyed on a correct
                                                                                             answer

  Question panel      `question_panel_bg.png`             720×360            Optional        Bottom-anchored panel
  background                                                                                 frame behind the
                                                                                             question text and answer
                                                                                             buttons

  Answer button ---   `answer_button_normal.png`          320×100            Yes             Sized to fit 4 buttons
  normal state                                                                               in a grid within the
                                                                                             question panel; large
                                                                                             enough for a child's tap
                                                                                             (44px+ touch target)

  Answer button ---   `answer_button_pressed.png`         320×100            Yes             Shown briefly on tap,
  pressed/selected                                                                           before correct/incorrect
  state                                                                                      feedback resolves

  Health icon (heart) `heart_icon.png`                    48×48              Yes             **Deprecated by the
                                                                                             current requirements;
                                                                                             not used by the
                                                                                             lives-only damage model.
                                                                                             Keep only if already
                                                                                             present for backward
                                                                                             compatibility; it must
                                                                                             not drive gameplay
                                                                                             state**

  Lives icon (mini    `life_icon.png`                     48×48              Yes             Repeated in the HUD to
  ship)                                                                                      show remaining lives

  Wave Complete       `wave_complete_banner.png`          600×200            Yes             Shown briefly between
  banner                                                                                     waves

  Level Complete      `level_complete_banner.png`         600×200            Yes             Shown briefly between
  banner                                                                                     levels

Game Over           `game_over_bg.png`                  720×1280           Optional        Can reuse
  background/frame                                                                           `background_space.png`
                                                                                              with an overlay panel
                                                                                              instead, if a dedicated
                                                                                              image isn't supplied

  Leaderboard medal   `medal-gold.png`                    164×196            Yes             Rank 1 in the top-5
  --- gold                                                                                    leaderboard (Spec §14);
                                                                                              shown large on the Game
                                                                                              Over screen for a new
                                                                                              record

  Leaderboard medal   `medal-silver.png`                   164×196            Yes             Rank 2
  --- silver

  Leaderboard medal   `medal-bronze.png`                   164×196            Yes             Rank 3
  --- bronze

  Leaderboard medal   `medal-iron.png`                     164×196            Yes             Rank 4
  --- iron

Leaderboard medal   `medal-wood.png`                     164×196            Yes             Rank 5
  --- wood
  -------------------------------------------------------------------------------------------------------------------

If a listed asset isn't available up front, a same-dimension placeholder
(solid color or simple shape saved at the exact target size) should be
used so the real asset can be dropped in later without resizing or
re-laying-out any scene.

------------------------------------------------------------------------

## 9. Asset Integration Approach

Image assets are **not** treated as a final-polish step. They're
introduced starting in the first playable phase, using whichever real
assets are available at that point, with additional assets
(category-specific enemy variants, effects, banners) layered in
incrementally as later systems (waves, levels, transitions) are built
--- rather than the whole game running on colored rectangles until a
single "art pass" at the end. See the Build Plan document for the
phase-by-phase breakdown of exactly when each asset is introduced.


## 9. Question Attempts & Wrong-Answer Feedback (Authoritative)

The game uses a configurable maximum-attempt rule per question.

- `gameplay/tries_per_question` is the global default and defaults to `1`.
- `gameplay/tries_per_question_by_level` is a Dictionary of optional per-level overrides.
- `LevelManager`/`GameConfig` resolves the effective value for the current level; gameplay code must not read the raw Project Setting directly.
- Every incorrect answer consumes exactly one life.
- The tapped answer button immediately flashes red for a short, non-blocking feedback interval.
- With one allowed attempt, the wrong answer retires the question and the next question is loaded after the feedback. This is the normal/default behavior.
- With an effective value greater than one, the same question may be attempted again until the configured attempt count is exhausted. The question then advances.
- Correct answers always destroy the active enemy and advance immediately to the next question.
- A wrong answer never moves the formation or active enemy.
- If a wrong answer reduces lives to zero, Game Over takes precedence over question advancement and answer input is disabled.

## 10. Level Time Limit & Bullet Travel (Authoritative)

The game has one time limit per level, independent of the per-question
attempt rule.

- `gameplay/seconds_per_wave` is the global default seconds granted per wave and defaults to `30`.
- `gameplay/level_time_limit_by_level` is a Dictionary of optional per-level total-limit overrides in seconds.
- `GameConfig` resolves the effective value: a valid positive override for the current level, otherwise `wave_count × seconds_per_wave`. Gameplay code must not read the raw Project Settings directly.
- With the four-wave default sequence, the default limit is `4 × 30 = 120` seconds.
- The timer starts at level start, runs only while the game state is `PLAYING`, continues across wave transitions within the level, and freezes while paused. It also **freezes for the entire wave-transition sequence** (the `wave_complete_pause_seconds` pause plus the row-by-row arrival animation, Spec §15), resuming when the new wave's first question is shown.
- Wrong answers never consume time; correct answers never add time.
- When `time_remaining` reaches zero the level is failed: the game enters `GAME_OVER`, emits `game_over` exactly once with reason `TIME_EXPIRED`, disables answer input, and shows "Time's up!" on the Game Over screen alongside the final score.
- Completing all of a level's waves before expiry completes the level; the next level restarts the timer at its own resolved limit.

All bullets --- player bullets on correct answers and enemy bullets on
wrong answers --- take **exactly 0.3 seconds** to travel from source to
target in every case, implemented as a fixed-duration tween rather than a
fixed velocity. The enemy fire visual is presentational only: it must not
block input gating, question advancement, life consumption, or any
Game Over transition, and no collision-based damage path may be introduced.

**Parallel answer resolution (authoritative):** bullet flight time never
takes away from the time available to answer questions. On a correct
answer, score and loading the next
question all resolve at the same instant the player bullet launches; the
targeted enemy remains visible but excluded from selection until the bullet's
arrival confirms the hit and destroys it. On a
wrong answer, life consumption, attempt counting, and any Game Over
transition resolve immediately, and only the next question's *display*
may wait out the brief red-flash feedback interval (~0.18 s) --- never
the launch, telegraph, or arrival of any bullet.

## 11. Level Configuration & Player Experience

- **Custom Resources:** A `LevelConfig.gd` custom resource centralizes definitions for each level (categories, waves, time limits, attempts, difficulty scaling), replacing hard-coded logic in `LevelManager.gd`.
- **Mastery and Sequential Unlocking:** Clearing a level with 0 lives lost, 3 times in a row, unlocks the next level. Unlocking must happen sequentially (Level 2 cannot unlock unless Level 1 is unlocked).
- **Player Level Select:** The Main Menu includes a UI to let players choose any unlocked level to start playing from.
- **Main Menu Fit (post-Phase 26):** The Main Menu must fit entirely on a
  720×1280 portrait screen. The name field, per-level buttons, View Profile
  button, and START button are compact (≈25% smaller than the Phase 11
  touch-target sizes): name field 82 design px tall, level buttons 126×82,
  View Profile and START 270×82, with matching font sizes. This keeps the
  whole menu (title, name card, level grid, leaderboard, and buttons) on
  screen at once. The reduced heights trade off the Phase 11 110-design-px
  touch-target rule for these menu controls so the menu fits on screen.
- **Assumed Full Score:** Skipping a level by starting at a later unlocked level initializes the player's score with the sum of their "personal best" scores for the skipped levels.
- **Player Name Setup:** Before starting the game, players are prompted to enter their name on the Splash Screen or Main Menu. This name is persisted and displayed on the High Score screen.
- **Per-Player Profiles (Phase 22):** Unlocked levels, personal bests,
  and flawless streak progress are stored per player name, so each
  player on a shared device has their own progression. The name entered
  on the Main Menu selects the active profile; a new name starts fresh
  (Level 1 unlocked, no personal bests or streaks). The device-wide high
  score and its holder's name remain a single leaderboard value. See
  `specs/phases/Phase_22_Player_Profiles.md`.
- **Splash Screen:** A startup splash screen featuring the Game Title and Developer Logo fades directly into the Main Menu.
- **Mistake Review:** At the Game Over screen, a "Review Mistakes" button opens a scrollable panel displaying all wrong answers tracked during that session (Question, Selected Answer, Correct Answer).
- **Developer Level Select:** An exported setting (`debug_start_level`) allows developers to force-start the game at any level, bypassing unlocking requirements for testing purposes.
- **Points Per Question (Phase 17):** Each level awards its own
  configured number of points per correct answer via `points_per_question`
  in its `LevelConfig` (default `1`, validated ≥ 1), replacing the
  hardcoded one-point-per-answer. See Section 13.
- **Per-Wave Enemy Ship Images (Phase 18):** Each wave of each level may
  select its own set of enemy ship images; when a set has multiple
  images they are assigned to the formation cyclically by spawn slot.
  See Section 13.
- **Player Ship Per Level (Phase 19):** Each level may select the player
  ship image used while playing it. See Section 13.
- **Profile View & High Score Leaderboard (Phase 23):** The device-wide
  high score becomes a top-5 leaderboard with player names and rank medal
  icons; each player's profile gains a record count and highest-level-
  reached; the Game Over screen celebrates top-5 finishes with a large
  medal and personal-best beats with a congratulation. See Section 14.

## 12. Question Categories & Answer Model (Authoritative)

### Category registry

Internal category keys, player-facing display names, and strategy
classes are declared in ONE place (the generator's registration map plus
its display-name registry). The canonical keys after Phase 12:

| Key | Display name | Introduced |
|---|---|---|
| `integer_addition` | Addition | Phase 12 (renamed from `addition`) |
| `integer_subtraction` | Subtraction | Phase 12 (renamed) |
| `integer_multiplication` | Multiplication | Phase 12 (renamed) |
| `integer_division` | Division | Phase 12 (renamed) |
| `prime` | Prime Numbers | Phase 8 |
| `fraction_addition` | Fraction Addition | Phase 13 |
| `fraction_subtraction` | Fraction Subtraction | Phase 13 |
| `fraction_multiplication` | Fraction Multiplication | Phase 14 |
| `fraction_division` | Fraction Division | Phase 14 |
| `decimal_addition` | Decimal Addition | Phase 15 |
| `decimal_subtraction` | Decimal Subtraction | Phase 15 |
| `decimal_multiplication` | Decimal Multiplication | Phase 15 |
| `decimal_division` | Decimal Division | Phase 15 |
| `ratio_proportion` | Ratio & Proportion | Phase 16 |
| `hcf_lcm` | HCF & LCM | Phase 16 |

The HUD resolves display names through this registry --- raw keys are
never shown to players, and renaming a key must never change its display
name.

### Answer-value model

A question Dictionary keeps the shape
`{ question_text, correct_answer, choices }`, but from Phase 13 onward
`correct_answer` and each entry of `choices` may be:

- an `int` (all integer-answer categories), or
- a `String` holding the **canonical display form** of the value:
  - fractions: fully simplified, denominator > 0, e.g. `"3/4"`,
    `"7/3"`, `"2 1/3"` for mixed;
  - decimals: no trailing zeros, single leading zero, e.g. `"0.5"`,
    `"12.75"`.

Correctness is exact string equality of canonical forms. Producers
(strategies) guarantee canonicity and guarantee that within one question
no two choices are value-equal (an unsimplified equivalent or reformatted
decimal counts as equal). Fraction/decimal rendering data may accompany
the choices (e.g., an `answer_layout` array) so the panel can draw
stacked fractions; consumers must treat answer values as opaque and
compare them only as produced.

### Consumers

Answer values flow through: question panel buttons → answer-selected
event → correctness comparison → wrong-answer/mistake logging. All of
these must accept both ints and strings; none may cast answers to int.

## 13. Visual & Scoring Level Configuration (Authoritative)

All three settings below live in each level's `LevelConfig` custom
resource (`.tres`), editable in the Inspector, with safe fallbacks.
They are presentation/scoring only: none may affect questions,
difficulty, lives, or timing.

### Points per question

- `points_per_question: int = 1` per level; values below `1` clamp to
  `1` with a warning.
- Applied to every correct answer in that level across all waves.
- Default `1` reproduces all pre-Phase-17 score totals exactly;
  personal bests, assumed full score, and high scores operate on totals
  and need no schema changes.

### Per-wave enemy ship images

- `wave_enemy_textures` is index-aligned with `category_sequence`;
  element *i* configures the image set for wave *i* (an Array of texture
  paths). Empty element = use that wave's category sprite as before.
- **Ordering rule:** within a configured wave, spawn slot *k*
  (0-based formation order) uses `textures[k % textures.size()]`.
  Example --- Level 1 Wave 1 configured with `borg-1.png`, `borg-2.png`
  renders its 10 enemies exactly as:
  `borg-1, borg-2, borg-1, borg-2, borg-1, borg-2, borg-1, borg-2,
  borg-1, borg-2`.
- A set of one image repeats it for all 10; duplicate entries are
  allowed; different waves may use entirely different sets.
- Missing/invalid paths warn once per wave and fall back to the
  category default for the affected slots only.

### Player ship per level

- `player_ship_texture: String = ""`; empty (or a path that fails to
  load, with a warning) selects the default `assets/images/ships/
  player_ship.png`.
- Resolved and applied whenever a level starts: session start, natural
  level advance, and Play Again (re-applying the session-start level's
  ship).
- Only the ship's texture changes; size, muzzle position, feedback
  animations, and all gameplay behavior stay fixed.

## 14. Profile View & High Score Leaderboard (Authoritative)

The single device-wide high score (Phase 7/9/22) becomes the top entry of
a **top-5 leaderboard**, and each player's profile (Phase 22) gains a
record count and a highest-level-reached value. The Game Over screen
celebrates top-5 finishes and personal-best beats. All of this is
presentation/persistence only: no gameplay, question, difficulty, lives,
or timing behavior changes.

### Device-wide top-5 leaderboard

- The leaderboard is an ordered list of `{ name, score }` entries,
  descending by score, capped at 5. `high_score` and `player_name` remain
  the top entry, so the Phase 7/9/22 single-value behavior is preserved.
- A finished session's final score is submitted with the active player's
  name. It qualifies when the board has fewer than 5 entries, or when it
  is strictly greater than the current 5th (lowest) entry. Ties at the
  boundary do not displace an existing entry (consistent with the
  strictly-greater rule of §4 step 10 / NFR7.3), and scores ≤ 0 are never
  submitted.
- The leaderboard is displayed on the Main Menu as a table: one row per
  entry, each row showing the rank medal icon, the player's name, and the
  score. Medals by rank: 1 `medal-gold.png`, 2 `medal-silver.png`, 3
  `medal-bronze.png`, 4 `medal-iron.png`, 5 `medal-wood.png` (all under
  `assets/images/ui/`, 164×196, see §8). The table is compact enough that
  all five entries fit on screen and stay centered: rows are 60 design px
  tall, the medal renders at 22×26 (50% of the source 44×52), and the row
  separation is 6 px (50% of the original 12 px), halving the gap between
  the player name and the score.

### Profile View

Each player's profile additionally tracks:

- **Best scores** --- the player's best 3 session scores (existing
  `top_scores`).
- **Record count** --- how many times the player has set a new
  device-wide high score. Incremented only when a submitted score becomes
  the new #1 (strictly greater than the previous high score); a tie never
  increments it.
- **Highest level reached** --- the highest level number the player has
  started, updated monotonically at every level start (session start,
  level advance, and Play Again).
- **Best score per level** --- the existing `personal_bests` (level →
  best score earned in that level).

A **Profile View**, accessible from the Main Menu, shows all four for the
active player. All reads/writes operate on the active profile only
(Phase 22 isolation).

### Game Over celebration

- When the final score qualifies for the top 5, the Game Over screen
  announces it with a **large rank medal**:
  - rank 1: gold medal + "New High Score!" (replacing the current
    text-only callout);
  - ranks 2--5: the corresponding medal + a "Top 5!" / "Rank #N!"
    announcement.
- When the final score beats the player's own previous best session
  score, the screen adds a **"Personal Best!"** congratulation, in
  addition to any leaderboard announcement.
- Sessions that neither qualify for the top 5 nor beat a personal best
  keep the existing "High Score: X - Name" text.

## 15. Wave Transition Pause & Arrival Animation (Authoritative)

Wave transitions have a deliberate rhythm: a configurable pause with the
timer frozen, then a row-by-row enemy arrival reveal. This is timing/
presentation only: formation layout, active-enemy ordering, and question
flow are unchanged.

- `gameplay/wave_complete_pause_seconds` (Float, default `2.0`, minimum
  `0`) is the number of seconds the level timer pauses after a wave is
  cleared before the next wave's enemies arrive. It is game-wide, read
  only through `GameConfig`.
- When a wave is cleared, the level timer pauses and no question is shown
  for `wave_complete_pause_seconds`. The question panel is hidden for the
  **entire** transition (pause + arrival) and is revealed again only when
  the new wave's first question is shown, so the previous wave's last
  question never stays on screen during the transition.
- After the pause, the next wave's enemies spawn and animate into
  formation **one row at a time**, top-to-bottom (4, then 3, then 2, then
  1 for the standard formation). Each row takes `ROW_ARRIVAL_SECONDS`
  (0.5 s); the standard 4-row formation takes 2 s total.
- The first question of the new wave is not shown until every row has
  arrived.
- The level timer is paused for the **entire** wave transition (pause +
  arrival) and resumes when the new wave's first question is shown.
- The "Wave Complete!" banner still shows during the transition; the
  arrival animation is presentational and enemies are not answerable until
  all rows have arrived.
- The row-by-row arrival animation also plays when a new wave's formation
  spawns at session start and on Play Again (no completion pause in those
  cases).

## 16. Level Completion Bonus & Penalty (Authoritative)

Each completed level's score is adjusted at level completion: an
early-finish bonus rewards finishing with time to spare, and a
lives-lost penalty charges for each life lost during the level. This is
scoring only: questions, difficulty, lives, and timing are unchanged.

- `gameplay/bonus_seconds_per_point` (Float, default `5.0`, minimum
  `1.0`) is the number of seconds of remaining level time per bonus point.
- `gameplay/lives_lost_penalty_points` (Integer, default `1`, minimum
  `0`) is the number of points deducted per life lost during a level.
  Both are game-wide and read only through `GameConfig`.
- Completing a level with time remaining awards an early-finish bonus:
  `floor(time_remaining / bonus_seconds_per_point)` points (default 1
  point per full 5 seconds remaining).
- Each life lost during a level deducts `lives_lost_penalty_points` from
  that level's score.
- Both adjustments are applied at level completion:
  `level_score = max(0, earned + bonus - penalty)`, where `earned` =
  correct answers × `points_per_question`.
- The adjusted `level_score` is what is recorded as the level's personal
  best and what is added to the running total (the running total never
  goes below 0).
- Lives lost in a level that is NOT completed (game over) are not
  penalized, and the bonus does not apply to an incomplete level.
- Personal bests, assumed full score, and high scores continue to operate
  on totals (Phase 17 note) and need no schema changes.
