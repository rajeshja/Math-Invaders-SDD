# Phase 0 --- Project Setup

**Goal:** an empty-but-correctly-structured Godot project that runs,
with GUT installed and runnable, ready for Phase 1 to build on. No
gameplay yet.

**Source docs:** Build Plan §Phase 0, Tech Stack §1 (stack), §2 (scene
structure --- not yet built), §7 (asset folders), §8 (GUT setup), Spec
§7 (asset table, for placeholder sizing).

------------------------------------------------------------------------

## 1. Requirements

### Functional Requirements

-   FR0.1 --- A Godot 4.x project exists, opens in the editor without
    errors, and runs (F5) to a blank/default screen on desktop.

-   FR0.2 --- Project display settings are configured for portrait
    mobile: base resolution **720×1280**, stretch mode `canvas_items`,
    aspect `keep` (or `expand`, per Tech Stack §1 rendering notes),
    orientation locked to portrait.

-   FR0.3 --- Folder structure exists exactly as specified in Tech Stack
    §7 and §3:

        scripts/questions/strategies/
        test/unit/questions/
        assets/images/background/
        assets/images/ships/
        assets/images/enemies/
        assets/images/ui/
        assets/images/effects/

-   FR0.4 --- Every asset filename listed in Spec §7's table exists on
    disk under the correct subfolder, at the **exact dimensions**
    specified --- using real supplied art where available, and
    solid-color placeholder PNGs at the correct size everywhere else.

-   FR0.5 --- GUT addon is installed under `addons/gut/`, enabled in
    Project Settings → Plugins, and a `.gutconfig.json` at project root
    points at `test/unit/`.

-   FR0.6 --- Project-level gameplay settings are registered and visible
    under Project Settings: `gameplay/starting_lives` (integer, default
    3, minimum 1) and `gameplay/enemies_per_wave` (integer, default 10,
    minimum 1).

-   FR0.7 --- GUT runs successfully with zero tests present, both from
    the in-editor GUT panel and from the command line
    (`godot --headless -s addons/gut/gut_cmdln.gd`).

-   FR0.8 --- A Git repository is initialized with a `.gitignore`
    appropriate for Godot 4 (`.godot/`, `*.translation`, export
    artifacts, etc.), and the initial structure is committed.

### Non-Functional Requirements

-   NFR0.1 --- No gameplay scripts, scenes, or logic are written in this
    phase --- setup only.
-   NFR0.2 --- Placeholder assets must be pixel-exact substitutes so
    that no later phase needs to resize, re-anchor, or re-layout a scene
    when real art is dropped in (Tech Stack §7, "Placeholder Strategy").
-   NFR0.3 --- Project must run in both the Godot editor and (at
    minimum) a headless/CLI context, since GUT CLI runs are used later
    in CI-style workflows.
-   NFR0.4 --- Gameplay tuning values that are explicitly
    project-configurable must have a single authoritative access path;
    gameplay scripts must not scatter raw
    `ProjectSettings.get_setting()` calls.

### Out of Scope

-   Any `Main.tscn` scene content, player/enemy/UI nodes --- that's
    Phase 1.
-   Any real GUT test files --- Phase 0 only proves the *harness* runs;
    first real tests appear in Phase 2.

------------------------------------------------------------------------

## 2. Architecture Ownership Note

The project-wide singleton/autoload boundary is fixed here so later
phase documents do not need to make separate architecture decisions:
**`GameManager.gd` and `HighScoreManager.gd` are autoloads/singletons.
`WaveManager.gd` and `LevelManager.gd` are scene-owned managers,
instantiated/owned by the game scene (via `Main.gd`) and are not
autoloads.** This matches Tech Stack §5, while keeping wave/level
lifecycle scoped to the active game session.

## 3. Detailed Implementation Plan

1.  **Install Godot 4** (stable channel). Confirm version via
    `Help → About` or CLI `godot --version`.

2.  **Create the project**: `New Project`, name it (e.g.,
    `math_invaders`), choose a project folder, select the **Mobile**
    rendering method (Tech Stack §1: 2D renderer,
    `CanvasItem`/`Node2D`).

3.  **Configure display settings**
    (`Project → Project Settings → Display → Window`):

    -   `viewport width` = 720, `viewport height` = 1280
    -   `stretch/mode` = `canvas_items`, `stretch/aspect` = `keep`
    -   Set orientation to `portrait` under mobile export config
        (revisited fully in Phase 9, but set the baseline now).

4.  **Create folder structure** via the FileSystem dock or `mkdir`:

        scripts/questions/strategies/
        test/unit/questions/
        assets/images/background/
        assets/images/ships/
        assets/images/enemies/
        assets/images/ui/
        assets/images/effects/

5.  **Register gameplay configuration**: define the project settings
    `gameplay/starting_lives = 3` and `gameplay/enemies_per_wave = 10`,
    with type/range metadata and a single `GameConfig.gd` access path.

6.  **Populate assets**: for each row in Spec §7's asset table, either
    copy the supplied real PNG into the matching folder, or generate a
    solid-color PNG at the exact target dimensions (e.g., via a quick
    script or image editor) and save it under the same filename.
    Cross-check every filename/dimension against the table --- this is
    the contract later phases will code against.

7.  **Install GUT**:

    -   Via AssetLib panel inside Godot, search "Gut", install into
        `addons/gut/`. (Alternative: `git submodule add` if managing as
        a submodule.)

    -   Enable under `Project → Project Settings → Plugins → Gut`.

    -   Create `.gutconfig.json` at project root:

        ``` json
        {
          "dirs": ["res://test/unit/"],
          "should_exit": true,
          "log_level": 1
        }
        ```

8.  **Verify GUT runs with zero tests**:

    -   In-editor: open the GUT panel (bottom dock after enabling
        plugin), click Run All --- expect "0 tests, 0 passed, 0 failed"
        with no errors.
    -   CLI:
        `godot --headless -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json`
        --- expect a clean exit code (0) and matching zero-test summary.

9.  **Git init**: `git init`, add a Godot-4-appropriate `.gitignore`
    (`.godot/`, `.import/`, `*.translation`, `export_presets.cfg` if it
    contains secrets, build output dirs), commit as "Phase 0: project
    setup."

------------------------------------------------------------------------

## 4. Testing Plan

Phase 0 has no application logic, so there are no GUT *unit* tests to
write yet. Testing here is entirely **environment verification**:

  -----------------------------------------------------------------------------------------------------
  Check                   Method                                          Pass Criteria
  ----------------------- ----------------------------------------------- -----------------------------
  Project opens & runs    Open in editor, press F5                        Blank scene runs with no
                                                                          console errors

  Display config correct  Inspect Project Settings → Display              720×1280, canvas_items
                                                                          stretch, portrait

  Gameplay config present Inspect Project Settings                        `gameplay/starting_lives`
                                                                          defaults to 3 and
                                                                          `gameplay/enemies_per_wave`
                                                                          defaults to 10

  Folder structure        `view`/`ls` against Tech Stack §7 & §3 layout   Every listed folder exists
  complete                                                                

  Asset completeness      Script or manual diff of files-on-disk vs. Spec Every filename present, every
                          §7 table                                        dimension matches exactly

  GUT installed & enabled Project Settings → Plugins                      "Gut" shows as enabled, no
                                                                          load errors

  GUT runs (editor)       GUT panel → Run All                             0 tests, 0 failures, no
                                                                          errors

  GUT runs (CLI)          `godot --headless -s addons/gut/gut_cmdln.gd`   Exit code 0, matching summary

  Git history exists      `git log`                                       Initial commit present with
                                                                          expected structure
  -----------------------------------------------------------------------------------------------------

**Definition of Done:** all checks above pass; a teammate could clone
the repo, open it in Godot, run the (empty) GUT suite from the CLI, and
see no errors --- before any gameplay code exists.


## 5. Question Attempt Settings

Register the following Project Settings and verify them in the editor:

- `gameplay/tries_per_question` — integer, default `1`, minimum `1`.
- `gameplay/tries_per_question_by_level` — Dictionary, default `{}`.

The latter stores optional level-number overrides. Add the `GameConfig.gd`
access path so later gameplay code does not read these settings directly.
