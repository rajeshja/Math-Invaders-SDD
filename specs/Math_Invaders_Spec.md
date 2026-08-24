# Math Invaders (Godot Edition): Game Specification

## 1. Game Overview

**Math Invaders** is a portrait-mode mobile math game built in Godot.
Players defend against waves of enemy ships by answering multiple-choice
math questions. Answering correctly fires a bullet that destroys the
targeted enemy; answering wrong deals one point of damage by consuming one life. By default, each question has
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
    category sequence but raises difficulty (larger numbers, tighter
    time pressure), and later levels introduce new categories as
    additional waves (e.g., a "Prime Numbers" wave added once players
    reach an advanced level).
-   At the end of a wave, a brief transition ("Wave Complete!") shows
    before the next wave's fresh set of 10 enemies appears. At the end
    of a level, a "Level Complete!" transition shows before the next
    level begins.

This replaces the original "continuous descending waves" concept with a
**structured, per-category mini-level format** where the full 10-enemy
formation is visible at once and visibly shrinks as the player answers
correctly --- making progress legible to a young player ("I'm on Level
2, Subtraction, 4 enemies left") and making it straightforward to
control exactly which math skill is being practiced at any moment.

------------------------------------------------------------------------

## 3. Screen Layout (Portrait, e.g. 720×1280 base resolution)

    ┌─────────────────────────────┐
    │ Score:120  Lvl 2  🚀x2  ♥♥♥  │  ← HUD (top)
    │         Subtraction  6/10    │  ← Wave/category + remaining count
    │   *  E  E  E  *  E  E  ·     │
    │  ·    E     E    ·   E  *    │  ← Full formation of remaining
    │     E    *      E    ·       │     enemies, shrinks as answered
    │      ·        *        ·     │     Deep space bg (near-black/
    │                  ↑            │     dark navy, sparse stars)
    │                bullet         │
    │                               │
    │           🚀 (player)         │  ← Player ship, fixed near bottom
    ├──────────────────────────────┤
    │      What is 15 − 8?          │  ← Question panel
    │  [ 7 ]  [ 8 ]  [ 6 ]  [ 9 ]  │  ← Answer buttons
    └──────────────────────────────┘

-   **Background:** Near-black / dark navy scene with a sparse,
    slowly-parallaxing starfield.
-   **Player ship:** Fixed horizontal position near the bottom, above
    the question panel; visually fires when a correct answer is chosen.
-   **Enemies:** All 10 enemies for the current wave spawn together in a
    formation at the start of the wave and remain stationary while the
    player answers. One enemy at a time is the "active" target tied to
    the current question; as questions are answered correctly, that
    enemy is destroyed and removed, visibly shrinking the formation. A
    wrong answer does not move or remove any enemy.
-   **Question panel:** Anchored to the bottom of the screen, always
    visible, holding the question text and 4 tappable answer buttons.
-   **HUD (top of screen):**
    -   Score
    -   **Level** (new)
    -   **Lives**
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
4.  **Correct:** player ship fires a bullet at the active enemy; the
    enemy is destroyed and removed from the formation --- the player
    visibly sees the remaining count drop (e.g., 10 → 9); score
    increases; wave progress updates (e.g., "6/10 remaining"); a new
    question loads, linked to the next active enemy.
5.  **Incorrect:** the active enemy and the rest of the formation remain
    in place. The selected answer button flashes red and the player takes
    one point of damage: exactly one life is consumed. With the default
    `tries_per_question = 1`, the current question is retired and a new
    question is loaded. If the current level overrides the setting to a
    value greater than 1, the same question may remain active until the
    configured number of attempts has been used; every wrong attempt still
    consumes exactly one life. No enemy is destroyed or moved by a wrong
    answer.
6.  **Life depletion:** when lives reach 0, the game enters `GAME_OVER`
    immediately and disables further answering. The number of starting
    lives is configurable at project level; the default is 3.
7.  When all 10 enemies in the current wave are eliminated → "Wave
    Complete" → a **fresh set of 10 enemies** spawns for the next wave
    (next category).
8.  When all waves in the level are cleared → "Level Complete" → the
    player's lives reset to the configured starting-lives value, then
    the next level begins with increased difficulty (and, at later
    levels, additional categories), again starting with a full set of 10
    enemies.
9.  Game over → compare score to stored high score, update if beaten,
    show result screen with "Play Again."

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
-   **Lives are the only mistake budget:** each wrong answer consumes
    one life; no enemy descent or timer is used as a penalty in the
    current design.

### Stage C --- New concepts (advanced levels)

-   New wave categories added to the rotation: prime number
    identification, factors/multiples, simple fractions/percentages
    (stretch goal)

### Distractor & Difficulty Rules

-   Distractors avoid duplicates and nonsensical values.
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
wave they are 4. **Lives** --- remaining lives. Wrong-answer feedback is
shown on the tapped answer button by a brief red flash.

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

  Player ship         `player_ship.png`                   128×128            Yes             Faces upward; fixed near
                                                                                             the bottom of the screen
                                                                                             above the question panel

  Player              `player_bullet.png`                 16×48              Yes             Travels upward from the
  bullet/projectile                                                                          player ship to the
                                                                                             active enemy

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
  (Stage C)                                                                                  dimensions as the other
                                                                                             enemy sprites

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
