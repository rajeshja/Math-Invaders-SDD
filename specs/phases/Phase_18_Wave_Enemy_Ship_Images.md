# Phase 18 --- Per-Wave Enemy Ship Image Sets (Level Config)

**Goal:** let each level configure which enemy ship images its waves
use, per wave. When a wave is given multiple images, all 10 enemies of
that wave use them **in order, cycling** --- e.g., a Wave 1 set of
`borg-1.png, borg-2.png` renders the formation as
`borg-1, borg-2, borg-1, borg-2, borg-1, borg-2, borg-1, borg-2,
borg-1, borg-2`. When no set is
configured, the existing category sprite (`enemy_ship_addition.png`,
etc.) is used exactly as today.

**Source docs:** Build Plan §Phase 18, Spec §13 (Visual & Scoring Level
Configuration --- authoritative, includes the ordering rule), §7
(sprite assets), Tech Stack §4 (`WaveManager` spawn flow), §8
(enemy texture wiring), Phase 2 FR2.7 / Phase 8 FR8.3 (per-instance
texture-swap mechanism this phase extends).

------------------------------------------------------------------------

## 1. Requirements

### Functional Requirements

-   FR18.1 --- `LevelConfig.gd` gains an exported field
    `wave_enemy_textures: Array = []`, index-aligned with
    `category_sequence`: element `i` configures the images for the wave
    at `category_sequence[i]`. Each element is an Array of texture path
    Strings (e.g., `["res://assets/images/enemies/borg-1.png", ...]`);
    an empty element (or an empty outer array) means "no override" for
    that wave.
-   FR18.2 --- **Ordering rule (authoritative, mirrors Spec §13):**
    within a configured wave, spawn slot `k` (0-based,
    `k < enemies_per_wave`) uses element `textures[k %
    textures.size()]` of that wave's set. With 10 enemies and a
    2-image set this produces exactly:
    `borg-1, borg-2, borg-1, borg-2, borg-1, borg-2, borg-1, borg-2,
    borg-1, borg-2`. Slot order is the existing formation layout order (the
    same index fed to `_formation_position`), so the pattern reads
    left-to-right, top-to-bottom across the triangle.
-   FR18.3 --- Fallbacks are safe and non-crashing: a missing/empty set
    element falls back to the category default sprite; a configured
    path that fails `ResourceLoader.exists()` logs one `push_warning`
    per wave (not per enemy) and falls back to the category default for
    that slot only.
-   FR18.4 --- Flow: `LevelManager.start_level()` hands the level's
    `wave_enemy_textures` to `WaveManager` (new setter alongside
    `set_generation_options`, e.g., `set_wave_texture_sets()`).
    `WaveManager.start_wave()` selects the set aligned to the SAME wave
    index it uses to pick the category from `category_sequence`
    (including `start_first_wave()` and post-clear advancement), and
    passes each slot's resolved override into the spawned enemy.
-   FR18.5 --- `enemy.gd setup()` gains an optional third parameter
    (e.g., `texture_override: String = ""`) applied AFTER the category
    default so overrides win and empty overrides change nothing; the
    single-scene texture-swap architecture is unchanged, explosion/
    return-fire visuals unaffected.
-   FR18.6 --- The same image may appear multiple times in one set, sets
    may contain a single image (all 10 identical), and different waves
    in one level may use completely different sets --- all supported by
    the modulo rule with zero special-casing.
-   FR18.7 --- Level authoring: at least one shipped level `.tres`
    demonstrates the feature (recommended: Level 1 Wave 1 uses a
    two-image set); later levels may carry their own per-wave sets.
    Placeholders follow Spec §7's
    same-dimension placeholder rule.

### Non-Functional Requirements

-   NFR18.1 --- No gameplay effect: image selection never touches
    questions, difficulty, scoring, lives, or timing --- presentation
    only.
-   NFR18.2 --- With all `wave_enemy_textures` empty, spawned textures
    are byte-identical to Phase 17 behavior (regression-protected by
    unmodified suites).
-   NFR18.3 --- `WaveManager` remains scene-tree-testable: the texture
    selection logic is exercised through the existing injectable
    `enemy_scene` double pattern (Phase 3 NFR3.2) with no new hard
    dependencies.

### Out of Scope

-   Player ship selection (Phase 19).
-   In-wave randomization or animated palette swaps (fixed cyclic order
    only this phase).
-   Mid-wave texture changes (assignment happens once at spawn).

------------------------------------------------------------------------

## 2. Detailed Implementation Plan

1.  **`LevelConfig.gd`**: add the export group + field (FR18.1) plus a
    small normalization helper returning a per-index `Array[String]`
    (empty when unset) so callers never re-implement alignment checks;
    validate element types defensively in `.tres` load tests.
2.  **`enemy.gd`**: extend `setup()` with the optional override
    parameter (FR18.5); resolve via `ResourceLoader.exists()` before
    assignment so bad paths degrade gracefully even if reached directly.
3.  **`WaveManager.gd`**: add `set_wave_texture_sets()` storing a
    duplicated array; in `start_wave()`, resolve the current wave's set
    from the sequence index used for category selection and pass
    slot-resolved paths into each `setup()` call (FR18.4/FR18.2);
    include the per-slot fallback (FR18.3). `clear_all()` resets stored
    sets so restarted sessions can't leak a previous level's art.
4.  **`LevelManager.gd`**: forward the active config's field at level
    start (FR18.4).
5.  **Authoring + placeholders**: add the demo configuration to a
    level `.tres`; drop placeholder PNGs where real art is missing
    (FR18.7).
6.  **GUT tests** alongside steps 2--4 (see Testing Plan).

------------------------------------------------------------------------

## 3. Testing Plan

### Automated Tests (GUT)

**`test_level_config.gd` (extended)** --- field defaults empty;
alignment helper returns per-index sets including out-of-range indices →
empty; malformed elements tolerated without crashing.

**`test_wave_manager.gd` (extended)** --- using a recording enemy
double: a 2-image set on a 10-enemy wave assigns textures in the exact
FR18.2 cyclic order (assert the full 10-element sequence); a 1-image set
assigns it to all 10; an empty set assigns the category default to all
10; a nonexistent path slot falls back to the default while other slots
keep their configured images; advancing waves picks the NEXT index's
set; `clear_all()` + restart uses the fresh session's sets.

**Regression** --- full prior suite passes unmodified (NFR18.2).

### Manual Test Checklist

  -------------------------------------------------------------------------------
  \#                      Scenario                Expected Result
  ----------------------- ----------------------- -------------------------------
  1                       Configure Level 1       The 10 ships render exactly in
                          Wave 1 with borg-1/2    the order borg-1, 2, 1, 2, 1, 2,
                          per FR18.2              1, 2, 1, 2 reading
                                                  left-to-right/top-to-bottom

  2                       Leave Wave 2            Wave 2 shows the standard
                          unconfigured            category sprite for all 10

  3                       Put a bogus path in     One warning in the log; that
                          one wave's set          slot (and only that slot) shows
                                                  the category sprite; no crash

  4                       Play Again / advance a  New level's sets apply at its
                          level                   first wave; previous level's
                                                  sets do not leak

  5                       Run full GUT suite      Extended tests + full prior
                                                  suite pass, 0 failures
  -------------------------------------------------------------------------------

**Definition of Done:** levels can author per-wave enemy image sets
with the exact cyclic ordering rule, robust fallbacks, no gameplay
side effects, demonstrated configuration in shipped content, and green
GUT coverage.
