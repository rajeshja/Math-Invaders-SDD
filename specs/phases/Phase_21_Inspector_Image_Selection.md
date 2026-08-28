# Phase 21 --- Native Inspector Image Selection (Level Config)

**Goal:** remove the need to hand-type path Strings and category keys
into the level `.tres` files. The image fields on `LevelConfig` --- the
per-wave enemy ship sets (`wave_enemy_textures`, Phase 18) and the
per-level player ship (`player_ship_texture`, Phase 19) --- currently
store raw path Strings that must be typed into free-text Inspector
fields, and the wave/category sequence (`category_sequence`) is a
free-text String array. This phase converts the image fields to native
Godot `Texture2D` resource exports (real image picker: thumbnail
preview, drag-and-drop from the FileSystem dock, and a file dialog
restricted to image files) and constrains `category_sequence` to an
`@export_enum` dropdown of the canonical categories. No gameplay,
scoring, or timing behavior changes.

**Source docs:** Build Plan §Phase 18 / §Phase 19, Spec §13 (Visual &
Scoring Level Configuration --- authoritative), Tech Stack §4
(`WaveManager` spawn flow), §5 (`player.gd` wiring), §8 (enemy texture
wiring), Phase 18 FRs 18.1--18.7, Phase 19 FRs 19.1--19.6.

------------------------------------------------------------------------

## 1. Requirements

### Functional Requirements

-   FR21.1 --- `LevelConfig.gd` changes `player_ship_texture` from
    `@export var player_ship_texture: String = ""` to
    `@export var player_ship_texture: Texture2D = null`. A `null`
    (unset) selection means "use the default ship", exactly as the empty
    String did before. The Inspector now renders a texture picker with a
    preview instead of a free-text path field.
-   FR21.2 --- `LevelConfig.gd` changes `wave_enemy_textures` from
    `@export var wave_enemy_textures: Array = []` to
    `@export var wave_enemy_textures: Array[Array[Texture2D]] = []`,
    keeping the Phase 18 index-alignment with `category_sequence`:
    element *i* is the set of `Texture2D` images for wave *i*. Each
    inner array element is edited through a native texture picker.
-   FR21.3 --- Resolution helpers keep their existing contracts but
    operate on `Texture2D` resources instead of path Strings:
    -   `resolved_player_ship_texture() -> Texture2D` returns the
        configured texture when set, otherwise the default
        `assets/images/ships/player_ship.png` (now a preloaded
        `Texture2D` constant). Because a `Texture2D` is either a valid
        loaded resource or `null`, the old `ResourceLoader.exists()`
        path-existence check and its one-time warning are no longer
        needed for the configured value.
    -   `resolved_wave_texture_sets() -> Array` returns one
        `Array[Texture2D]` per `category_sequence` entry, empty when
        unset; malformed elements (non-`Texture2D` entries, non-Array
        elements) are still tolerated by being dropped so bad authored
        data can never crash spawning.
-   FR21.4 --- Consumers switch from path Strings to `Texture2D`:
    -   `enemy.gd setup(p_category, p_question, texture_override:
        Texture2D = null)`; `_apply_override_texture(texture:
        Texture2D)` assigns the sprite texture directly (no
        `load()`/`exists()` needed). `null` overrides change nothing.
    -   `wave_manager.gd` `_resolved_slot_paths()` becomes
        `_resolved_slot_textures() -> Array[Texture2D]`, applying the
        unchanged FR18.2 modulo rule (`slot k` uses
        `set[k % set.size()]`) and the FR18.3 fallback (empty/missing
        entries fall back to the category default for that slot).
        `set_wave_texture_sets(sets: Array)` keeps its signature but
        carries `Texture2D` values.
    -   `player.gd apply_ship_texture(path: String)` becomes
        `apply_ship_texture(texture: Texture2D)`; a `null` texture is
        ignored defensively so a bad configuration can never blank the
        ship.
    -   `main.gd` `_on_level_changed()` passes the resolved
        `Texture2D` straight through (FR19.3 application points
        unchanged: session start, level advance, Play Again).
-   FR21.5 --- The shipped level `.tres` files are re-authored to store
    `ExtResource` references to the image files instead of inline path
    Strings, e.g.:
    ```
    [ext_resource type="Texture2D" uid="uid://..." path="res://assets/images/ships/player_ship_alt.png" id="2"]
    ...
    player_ship_texture = ExtResource("2")
    ```
    and for a wave set:
    ```
    wave_enemy_textures = [Array[Texture2D]([ExtResource("2"), ExtResource("3"), ExtResource("4")])]
    ```
    Level 1 keeps its three-image Wave 1 demo (FR18.7) and Level 2 keeps
    its variant ship demo (FR19.6); all other levels stay unset.
-   FR21.6 --- The default player ship is exposed as a preloaded
    `Texture2D` constant (`DEFAULT_PLAYER_SHIP_TEXTURE`) so
    `resolved_player_ship_texture()` needs no scene tree or filesystem
    lookup.
-   FR21.7 --- `LevelConfig.gd` changes `category_sequence` from a
    free-text `@export var category_sequence: Array[String]` to an
    enum-constrained export so each element is chosen from a dropdown
    instead of being typed:
    `@export_enum("integer_addition", "integer_subtraction",
    "integer_multiplication", "integer_division", "prime",
    "fraction_addition", "fraction_subtraction",
    "fraction_multiplication", "fraction_division", "decimal_addition",
    "decimal_subtraction", "decimal_multiplication", "decimal_division",
    "ratio_proportion", "hcf_lcm") var category_sequence: Array[String]`.
    The enum list is the canonical category registry from
    `QuestionGenerator.DISPLAY_NAMES` (Phase 12 FR12.4) --- the only
    categories the game can actually generate.
-   FR21.8 --- The enum list is kept in sync with the canonical registry:
    adding a category in `QuestionGenerator` (strategy + `DISPLAY_NAMES`
    entry) must also add it to the `@export_enum` list, so the dropdown
    never offers a category the generator cannot dispatch. A test asserts
    the two lists match (see Testing Plan).

### Non-Functional Requirements

-   NFR21.1 --- Presentation only: image selection never touches
    questions, difficulty, scoring, lives, or timing (unchanged from
    NFR18.1 / NFR19.1).
-   NFR21.2 --- With every image field left unset, spawned textures are
    byte-identical to Phase 20 behavior (regression-protected by
    unmodified suites).
-   NFR21.3 --- Resolution helpers remain unit-testable without the
    scene tree (texture-in → effective-texture-out), mirroring the
    Phase 18/19 normalization-helper pattern.
-   NFR21.4 --- Authoring ergonomics: a non-programmer can change any
    level's enemy or player ship image entirely from the Inspector
    using the native texture picker, with no knowledge of resource paths.

### Out of Scope

-   Non-image, non-category `LevelConfig` fields (`difficulty`,
    `max_operand_size`, timing, fraction/decimal rules, scoring) ---
    these keep their current editors.
-   Audio assets, UI theme resources, and the GUT addon `.tres` files.
-   Adding new image fields or changing the FR18.2 cyclic ordering rule.
-   A custom editor plugin or drag-and-drop palette (native `Texture2D`
    exports and `@export_enum` already provide the pickers; no plugin is
    required).

------------------------------------------------------------------------

## 2. Detailed Implementation Plan

1.  **`LevelConfig.gd`**: change the two image field declarations to
    `Texture2D`-typed exports (FR21.1/FR21.2); replace the
    `DEFAULT_PLAYER_SHIP_TEXTURE` String constant with a preloaded
    `Texture2D` (FR21.6); rewrite `resolved_player_ship_texture()` to
    return the configured texture or the default (dropping the
    `ResourceLoader.exists()`/warning path); rewrite
    `resolved_wave_texture_sets()` to normalize `Array[Texture2D]`
    per index (FR21.3); constrain `category_sequence` with
    `@export_enum` listing the canonical registry (FR21.7/FR21.8).
2.  **`enemy.gd`**: change `setup()`'s override parameter and
    `_apply_override_texture()` to `Texture2D` (FR21.4).
3.  **`wave_manager.gd`**: rename `_resolved_slot_paths()` →
    `_resolved_slot_textures()` returning `Array[Texture2D]`, keeping the
    modulo + fallback logic; `set_wave_texture_sets()` unchanged in
    signature (FR21.4).
4.  **`player.gd`**: change `apply_ship_texture()` to accept a
    `Texture2D` (FR21.4).
5.  **`main.gd`**: update the `_on_level_changed()` call site to pass the
    resolved `Texture2D` (FR21.4).
6.  **Authoring**: re-save `level_1.tres` and `level_2.tres` with
    `ExtResource` texture references (FR21.5); leave the other levels
    unset.
7.  **GUT tests** alongside steps 1--5 (see Testing Plan).

------------------------------------------------------------------------

## 3. Testing Plan

### Automated Tests (GUT)

**`test_level_config.gd` (updated)** --- field defaults are `null` /
empty; `resolved_player_ship_texture()` returns the default texture when
unset and the configured texture when set; `resolved_wave_texture_sets()`
returns per-index `Array[Texture2D]` including out-of-range indices →
empty; malformed elements (non-`Texture2D` entries, non-Array elements)
tolerated without crashing; Level 1's demo set holds three non-null
`Texture2D` values; Level 2's ship resolves to the variant texture.

**`test_wave_manager.gd` (updated)** --- using a recording enemy double
with `Texture2D` values: a 3-texture set on a 10-enemy wave assigns
textures in the exact FR18.2 cyclic order; a 1-texture set assigns it to
all 10; an empty set assigns the category default to all 10; advancing
waves picks the NEXT index's set; `clear_all()` + restart uses the fresh
session's sets.

**`test_enemy.gd` / player apply test (updated)** --- `setup()` with a
`Texture2D` override swaps the sprite; `null` leaves the category
default; `apply_ship_texture()` with a valid texture changes the sprite
and with `null` leaves the prior texture intact (headless-safe using a
tiny generated `Texture2D`).

**`test_level_config.gd` (category dropdown)** --- the `@export_enum`
list on `category_sequence` matches the canonical
`QuestionGenerator.DISPLAY_NAMES` keys exactly (FR21.8), so the dropdown
can never offer an undispatchable category; every shipped level's
`category_sequence` entries are all present in that list.

**Regression** --- full prior suite passes unmodified (NFR21.2).

### Manual Test Checklist

  -------------------------------------------------------------------------------
  \#                      Scenario                Expected Result
  ----------------------- ----------------------- -------------------------------
  1                       Open Level 1 in the     `wave_enemy_textures` shows a
                          Inspector               texture picker (preview) for
                                                  each of the three Wave 1
                                                  images; no free-text path field

  2                       Open Level 2 in the     `player_ship_texture` shows a
                          Inspector               texture picker with the variant
                                                  ship preview; unset levels show
                                                  an empty picker

  3                       Change a wave image     The 10 ships render with the
                          via the picker and      new image in the FR18.2 cyclic
                          play Level 1            order; no path typing

  4                       Change the player       Starting/advancing into that
                          ship via the picker     level shows the new ship;
                          and play                default ship elsewhere

  5                       Clear a selection       Falls back to the category /
                          (set to null)           default ship; no warning, no
                                                  crash

  6                       Edit a level's          Each `category_sequence`
                          category sequence       element is a dropdown of the
                                                  supported categories; no free
                                                  text; only valid categories
                                                  can be chosen

  7                       Run full GUT suite      Updated tests + full prior
                                                  suite pass, 0 failures
  -------------------------------------------------------------------------------

**Definition of Done:** every level's enemy and player ship image is
selectable through a native Godot `Texture2D` picker in the Inspector,
and each `category_sequence` element is chosen from a dropdown of the
canonical categories --- with no path Strings or category keys to type;
the FR18.2 cyclic ordering and FR18.3 / FR19.2 fallbacks are preserved;
shipped `.tres` files use `ExtResource` references; and the full GUT
suite is green.
