# Math Invaders (Godot Edition): Technology Stack & Architecture

## 1. Technology Stack

  -----------------------------------------------------------------------
  Layer                               Choice
  ----------------------------------- -----------------------------------
  Engine                              **Godot 4.x** (stable)

  Language                            **GDScript** (fast iteration; C#
                                      optional later if needed)

  Rendering                           Godot's 2D renderer,
                                      `CanvasItem`/`Node2D` scene tree

  UI                                  Godot `Control` nodes (`Button`,
                                      `Label`, `GridContainer`, etc.)
                                      with `CanvasLayer` for HUD and
                                      question panel

  Input                               Touch (primary), mouse (desktop
                                      testing)

  Persistence                         `FileAccess`/`ConfigFile` or JSON
                                      in `user://` for high scores and
                                      progress

  Export targets                      Android & iOS via Godot's built-in
                                      exporters; HTML5 build for quick
                                      in-browser testing

  Version control                     Git / GitHub

  Unit testing                        **GUT (Godot Unit Test)** ---
                                      GDScript unit testing addon, run
                                      from the editor, CLI, or CI
  -----------------------------------------------------------------------

Godot replaces a Phaser+React+Capacitor style stack with a single
integrated engine --- no separate UI framework or native-wrapper layer
is needed, since Godot exports natively to Android/iOS and handles UI,
physics, and rendering itself.

------------------------------------------------------------------------

## 2. Scene Structure

    Main.tscn (root)
    ├── Background (Node2D — starfield)
    ├── GameWorld (Node2D)
    │   ├── Player (CharacterBody2D/Sprite2D)
    │   ├── Enemies (Node2D — holds up to 10 concurrent enemy instances, arranged in a formation)
    │   └── Bullets (Node2D — holds active player AND enemy bullet instances)
    ├── HUD (CanvasLayer)
    │   ├── ScoreLabel
    │   ├── LevelLabel
    │   ├── TimeLabel               # remaining level time, e.g. "⏱ 87"
    │   ├── WaveProgressLabel      # e.g. "Subtraction 6/10 remaining"
    │   └── LivesDisplay
    └── QuestionPanel (CanvasLayer/Control)
        ├── QuestionLabel
        └── AnswerButtons (GridContainer of Button nodes)

------------------------------------------------------------------------

## 3. Question Generation Architecture: Strategy Pattern

Rather than a single monolithic question-generator file, question
creation is split into **one strategy per math category**, all
implementing a shared interface. This keeps each category's logic
isolated and makes it easy to add new categories (e.g., primes,
fractions) without touching existing code.

### File Layout

    scripts/
    └── questions/
        ├── question_strategy.gd        # Base class / interface
        ├── question_generator.gd       # Dispatcher/factory — picks a strategy by category
        └── strategies/
            ├── addition_strategy.gd
            ├── subtraction_strategy.gd
            ├── multiplication_strategy.gd
            ├── division_strategy.gd
            └── prime_strategy.gd       # Added later (Stage C content)

### `question_strategy.gd` (base class)

Defines the contract every strategy must implement: -
`generate(difficulty: int) -> Dictionary` --- returns
`{ question_text, correct_answer, choices: [] }` - Shared helper methods
(e.g., distractor-building utilities) can live here or in a small shared
`distractor_utils.gd` that strategies call into, so each concrete
strategy stays focused on its own operation logic.

### Concrete Strategies

Each concrete script (`addition_strategy.gd`, `subtraction_strategy.gd`,
etc.) extends `question_strategy.gd` and implements
`generate(difficulty)` using rules specific to that category --- e.g.: -
`addition_strategy.gd`: picks two operands sized according to
`difficulty` (1-digit at low difficulty, up to 2--3 digit at higher
difficulty), computes the sum, generates plausible wrong-answer
distractors. - `division_strategy.gd`: picks a divisor/quotient pair
first (to guarantee whole-number results) and derives the dividend. -
`prime_strategy.gd` (later): generates a set of numbers, one of which is
prime, and asks the player to identify it --- demonstrating that the
same interface supports categories that aren't pure arithmetic.

### `question_generator.gd` (dispatcher)

-   Holds a mapping of category name → strategy instance (e.g.,
    `{"addition": AdditionStrategy.new(), "subtraction": SubtractionStrategy.new(), ...}`).
-   Exposes a single method the rest of the game calls:
    `generate_question(category: String, difficulty: int) -> Dictionary`,
    which simply delegates to the matching strategy.
-   This is the **only** class other systems (like `WaveManager`) talk
    to --- they never need to know which concrete strategy is running.

### Why this pattern

-   Adding a new math category (primes, fractions, factors) means adding
    one new strategy file and registering it --- no changes to existing
    category logic.
-   Each category's difficulty scaling and distractor logic can evolve
    independently.
-   Keeps files small and testable in isolation --- each strategy has a
    corresponding **GUT** unit test that calls `generate(difficulty)`
    directly and checks the returned answer/choices, without needing the
    rest of the game running (see Section 8, Testing Strategy).

------------------------------------------------------------------------

## 4. Wave & Level Management

-   `WaveManager.gd` --- defines the category sequence for the current
    level (e.g.,
    `["addition", "subtraction", "multiplication", "division"]`) and
    owns the full lifecycle of a wave:
    -   **Wave start:** instantiates all **10 `enemy.tscn` instances at
        once**, arranged in a formation (e.g., a grid), and calls
        `QuestionGenerator.generate_question(current_category, current_difficulty)`
        once per enemy, linking each enemy to its own question up front
        (or generating the next question just-in-time for whichever
        enemy becomes "active" --- either approach is valid; see Phase 3
        of the Build Plan for the initial simple version).
    -   **Tracking the active enemy:** determines which single enemy is
        currently "targeted" by the question panel (e.g., the frontmost
        one), and displays its linked question.
    -   **On correct answer:** removes the active enemy from the
        `Enemies` container (`queue_free()`), decrements the remaining
        count, updates the HUD's wave-progress display, and advances the
        question panel to the next active enemy's question.
    -   **On incorrect answer:** leaves the entire formation stationary,
        emits/handles a single wrong-answer event, and keeps the same
        active question selected so it can be retried. `WaveManager`
        must not implement enemy descent as a wrong-answer penalty.
    -   **On wave clear (0 enemies remaining):** triggers "Wave
        Complete," then spawns a **fresh set of 10 enemies** for the
        next category in the sequence.
    -   **On level clear (all waves in the sequence complete):** signals
        `LevelManager.gd` to advance the level.
-   `LevelManager.gd` --- tracks the current level number, raises the
    difficulty parameter passed to `QuestionGenerator` as levels
    increase, and (at defined thresholds) adds new categories into
    `WaveManager`'s sequence. Tells `WaveManager` to reset and spawn the
    first wave's full set of 10 enemies when a new level begins.

------------------------------------------------------------------------

## 5. Other Key Autoloads / Singletons

-   `GameManager.gd` --- overall game state (playing/paused/game-over),
    score, and lives; an incorrect answer consumes exactly one life.
    `GameManager` also owns the level timer: `time_remaining`,
    `level_time_limit`, and `last_game_over_reason`
    (`NONE`/`LIVES_DEPLETED`/`TIME_EXPIRED`), advanced via an explicit
    `tick(delta)` that only acts while `PLAYING`. It emits `score_changed`,
    `lives_changed`, `time_changed`, and
    `game_over` signals; the signal fires exactly once per game end,
    whichever cause (lives at zero or time at zero) triggers it first. There is no health pool in the current gameplay
    model.
-   `HighScoreManager.gd` --- reads/writes persisted high score
    (JSON/`ConfigFile` in `user://`).

## Key Scene Scripts

-   `player.gd` --- handles firing animation/position

-   `enemy.gd` --- a per-instance template (not a manager): handles this
    enemy's own movement, holds a reference to its linked question,
    plays its own destruction animation, and plays its wrong-answer
    fire animation (a short telegraph plus one `enemy_bullet.tscn`
    instance aimed at the player). Up to 10 instances of this script run
    concurrently within a wave, each independent, spawned and tracked by
    `WaveManager.gd`

-   `bullet.gd` --- movement and collision with enemy; all travel is a
    fixed-duration tween (`TRAVEL_TIME := 0.3` seconds) shared by the
    player bullet and the enemy bullet, so travel time never varies
    with distance

-   `question_panel.gd` --- renders question/choices, emits a signal
    when the player taps an answer

-   `hud.gd` --- updates score, level, wave-progress, lives, and
    time-remaining displays in response to `GameManager`/`WaveManager`
    signals

-   `GameConfig.gd` --- a small configuration-access singleton/helper
    that owns the names/defaults for project-level gameplay settings.
    Gameplay code reads `starting_lives` through this path rather than
    scattering raw `ProjectSettings.get_setting()` calls throughout the
    application.

------------------------------------------------------------------------

## 6. Project Settings & Gameplay Configuration

Gameplay values that are intended to be tuned without code changes live
in Godot Project Settings. The current required settings are:

-   `gameplay/starting_lives` --- integer, default `3`, minimum `1`.
-   `gameplay/enemies_per_wave` --- integer, default `10`, minimum `1`
    (the current game design uses 10).
-   `gameplay/tries_per_question` --- integer, default `1`, minimum `1`.
-   `gameplay/tries_per_question_by_level` --- Dictionary, default `{}`;
    optional level-number → positive-integer overrides.
-   `gameplay/seconds_per_wave` --- float, default `30`, minimum `1`;
    seconds granted per wave when computing a level's default time limit.
-   `gameplay/level_time_limit_by_level` --- Dictionary, default `{}`;
    optional level-number → positive-seconds total time-limit overrides.

`GameConfig.gd` exposes `get_tries_per_question(level)` which returns the
level override when present and valid, otherwise the global setting. This is
the only supported access path for the effective attempt count. It likewise
exposes `get_seconds_per_wave()` and
`get_level_time_limit(level, wave_count)` (override when valid, otherwise
`wave_count × seconds_per_wave`) as the only supported access path for the
effective level time limit.

The authoritative access path is `GameConfig.gd` (autoload/helper).
`GameManager` reads the configured starting-lives value through
`GameConfig`; `WaveManager` reads the configured wave size and effective
question-attempt count through the same abstraction. `QuestionPanel` owns
the immediate red-flash visual response for an incorrect button tap, while
the game-state layer owns life consumption and question sequencing. Do not scatter raw environment/project-setting reads
across gameplay classes.

A level completion resets `GameManager.lives` to the configured
`starting_lives` value. A session restart also resets lives to the same
configured value. The persisted high score is unaffected.

------------------------------------------------------------------------

## 7. Persistence Details

-   High scores and (optionally) last-reached level/category performance
    are stored locally via `FileAccess`/`ConfigFile` or a small JSON
    file in `user://`, so they survive app restarts without requiring a
    backend.
-   No cloud sync or backend is required for the initial build; this can
    be layered in later without restructuring the above architecture.

------------------------------------------------------------------------

## 8. Image Asset Integration

The full sprite list and dimensions live in the **Spec** document
(Section 7); this section covers how they're organized and wired into
the project.

### Folder Structure

    assets/
    └── images/
        ├── background/
        │   ├── background_space.png
        │   └── starfield_overlay.png
        ├── ships/
        │   ├── player_ship.png
        │   ├── player_bullet.png
        │   └── enemy_bullet.png
        ├── enemies/
        │   ├── enemy_ship_addition.png
        │   ├── enemy_ship_subtraction.png
        │   ├── enemy_ship_multiplication.png
        │   ├── enemy_ship_division.png
        │   └── enemy_ship_prime.png
        ├── ui/
        │   ├── question_panel_bg.png
        │   ├── answer_button_normal.png
        │   ├── answer_button_pressed.png
        │   ├── heart_icon.png
        │   ├── life_icon.png
        │   ├── wave_complete_banner.png
        │   └── level_complete_banner.png
        └── effects/
            └── enemy_explosion_spritesheet.png

### Wiring Sprites to Scenes

-   `player.tscn`'s root `Sprite2D` references `player_ship.png`
    directly; `player.gd` doesn't need to know the file path --- it just
    triggers animations/effects on the node.
-   `enemy.tscn` uses a `Sprite2D` whose texture is **set per-instance**
    by `WaveManager.gd` at spawn time, based on the current wave's
    category (e.g., `subtraction` → `enemy_ship_subtraction.png`). This
    means one `enemy.tscn`/`enemy.gd` pair still serves all categories
    --- only the texture swaps.
-   `question_panel.tscn` uses `question_panel_bg.png` as a
    `NinePatchRect` (or plain `TextureRect`) background, with
    `AnswerButtons` using
    `answer_button_normal.png`/`answer_button_pressed.png` as the
    `Button` node's theme textures.
-   `hud.tscn` uses `life_icon.png` in an `HBoxContainer` that repeats
    the icon per life remaining, plus a `TimeLabel` bound to
    `GameManager.time_changed`. `heart_icon.png` is not part of the
    current gameplay HUD because health has been removed from the damage
    model.
-   `bullet.tscn` and `enemy_bullet.tscn` both use `bullet.gd`'s shared
    fixed 0.3-second travel tween; `player_bullet.png` faces upward,
    `enemy_bullet.png` is rotated to face downward toward the player.
-   `Background` node uses `background_space.png` as a full-screen
    `TextureRect`/`Sprite2D`, with `starfield_overlay.png` layered above
    it (optionally animated via a slow `AnimationPlayer` scroll or
    `Sprite2D` offset tween for parallax).

### Import Settings

-   Import filter: **Linear/Filter on** for illustrated or
    higher-resolution art (avoids a pixelated look when scaled); switch
    to **Nearest/Filter off** only if the supplied art is intentionally
    pixel-art style.
-   Mipmaps: off (2D game, no camera zoom-out that would need them).
-   Compression: Godot's default "Lossless" import is fine for this
    project's asset count and sizes; switch to "VRAM Compressed" only if
    build size becomes a concern on export.

### Placeholder Strategy

Until a given real asset is supplied, a solid-color image saved at the
**exact target dimensions** from the Spec's asset table should be
dropped into the matching folder under the same filename. This means
scenes and scripts are written once against the final file names/sizes,
and swapping in the real art later is a drag-and-drop replacement with
no code or layout changes.

------------------------------------------------------------------------

## 9. Testing Strategy: GUT (Godot Unit Test)

Unit testing is part of the development process from the first phase
that introduces testable logic, not something added at the end. **GUT**
is installed as an editor addon and used to write GDScript unit tests
alongside the scripts they cover.

### Setup

-   Install GUT via the Godot AssetLib panel (or as a Git submodule
    under `addons/gut/`) and enable it under **Project Settings →
    Plugins**.
-   A `.gutconfig.json` at the project root configures default test
    directories and settings so tests can be run identically from the
    editor's GUT panel, the command line
    (`godot --headless -s addons/gut/gut_cmdln.gd`), and CI.

### File Layout

    test/
    └── unit/
        ├── questions/
        │   ├── test_addition_strategy.gd
        │   ├── test_subtraction_strategy.gd
        │   ├── test_multiplication_strategy.gd
        │   ├── test_division_strategy.gd
        │   ├── test_prime_strategy.gd
        │   └── test_question_generator.gd
        ├── test_wave_manager.gd
        ├── test_level_manager.gd
        ├── test_game_manager.gd
        └── test_game_config.gd
        └── test_high_score_manager.gd

Test files mirror the `scripts/` folder structure 1:1 (e.g.,
`scripts/questions/strategies/addition_strategy.gd` ↔
`test/unit/questions/test_addition_strategy.gd`), so it's always obvious
which script a test file covers and whether a given script is missing
test coverage.

### What Gets Unit Tests

-   **Question strategies** (highest priority): each strategy's
    `generate(difficulty)` is tested for a correct result, exactly one
    correct answer among the 4 choices, no duplicate distractors, and
    sensible scaling as `difficulty` increases. Because strategies have
    no dependency on the scene tree, these are pure logic tests --- the
    primary payoff of the Strategy Pattern from Section 3.
-   **`question_generator.gd`**: dispatches to the right strategy for a
    given category name, and handles an unknown category gracefully.
-   **`WaveManager.gd`**: wave-clear detection (0 enemies remaining),
    correct category sequencing, and that a fresh set of 10 spawns on
    wave clear --- using GUT's double/stub tooling to avoid depending on
    real enemy scenes.
-   **`LevelManager.gd`**: difficulty increases correctly across levels,
    and new categories are added to the rotation at the right
    thresholds.
-   **`HighScoreManager.gd`**: high score is only updated when the new
    score is higher, and persists/reloads correctly (using GUT's
    temp-file helpers rather than the real `user://` save file).
-   **`GameManager.gd`**: each wrong-answer damage event consumes
    exactly one life; losing the final life triggers game over;
    configured starting lives are restored at level/session reset. The
    level timer is tested by driving `tick(delta)` directly: time
    decreases only while `PLAYING`, expiry triggers `game_over` exactly
    once with reason `TIME_EXPIRED`, post-game-over ticks are no-ops,
    and `reset_session()` restores the configured limit.
-   **`GameConfig.gd`**: default fallbacks and per-level override
    resolution for both the attempt count and the level time limit
    (`wave_count × seconds_per_wave` when no valid override exists).

Scene-heavy nodes with mostly visual behavior (`player.gd`, `enemy.gd`'s
movement/animation, `hud.gd`'s display updates) are lower priority for
unit testing and are primarily verified through manual playtesting,
though simple state changes on these scripts can still get basic GUT
coverage where useful.

### When Tests Are Written

Tests are written **alongside** the script they cover, in the same
phase, rather than retrofitted later --- see the Build Plan document for
exactly which tests are added in each phase.


## 9. Question Attempt Handling

`GameConfig.gd` must expose:

- `get_starting_lives() -> int`
- `get_enemies_per_wave() -> int`
- `get_tries_per_question(level: int) -> int`
- `get_seconds_per_wave() -> float`
- `get_level_time_limit(level: int, wave_count: int) -> float`

The effective attempt count is resolved once for a level and supplied to the
question-flow logic. The default is one attempt. For an incorrect answer,
`QuestionPanel` flashes the tapped button red, the game consumes one life,
the active enemy fires its bullet at the player (0.3-second travel), and
then either retires the question (attempt limit reached) or permits the
next attempt on the same question (limit > 1). With the default of one, the
next question is loaded after the red feedback.

The feedback duration must not become a gameplay timer: it is a short visual
acknowledgement only. If the final wrong attempt causes Game Over, no next
question is loaded.
