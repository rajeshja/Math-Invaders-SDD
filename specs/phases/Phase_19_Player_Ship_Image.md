# Phase 19 --- Player Ship Image Per Level

**Goal:** let each level select its own player ship image via
`LevelConfig`, completing the per-level visual configuration trio
(points in Phase 17, enemy ships in Phase 18, player ship here). Empty
selection keeps the default `player_ship.png`; a configured path is
applied at level start and re-applied on every level transition and
session restart.

**Source docs:** Build Plan §Phase 19, Spec §13 (Visual & Scoring Level
Configuration --- authoritative), §7 (sprite assets --- `player_ship.png`
remains the default; variants match 128×128), Tech Stack §5
(`player.gd` wiring), Phase 18 FRs 18.3--18.4 (fallback + hand-off
patterns reused).

------------------------------------------------------------------------

## 1. Requirements

### Functional Requirements

-   FR19.1 --- `LevelConfig.gd` gains an exported field
    `player_ship_texture: String = ""` (empty = use the default ship),
    editable per level in the Inspector.
-   FR19.2 --- Resolution rule: empty string or a path failing
    `ResourceLoader.exists()` → the default
    `assets/images/ships/player_ship.png`; a missing configured file
    logs one `push_warning` at resolution (not every frame).
-   FR19.3 --- Application points: the resolved texture is applied to
    the player sprite when a level starts --- covering session start
    from the menu/debug level, natural level advancement, and Play Again
    (which restarts at the session's original level and therefore
    re-applies that level's ship). Suggested flow: `Main` listens to
    `level_changed` (already wired) and calls a small method on
    `player.gd` (e.g., `apply_ship_texture(path)`); `player.gd` keeps no
    path knowledge of its own.
-   FR19.4 --- The override swaps ONLY the ship's texture: size,
    position, muzzle offset for bullets, fire/hit feedback animations,
    and all gameplay behavior are untouched. Supplied variant art should
    match the default's 128×128 footprint so no layout tuning is needed
    (Spec §7).
-   FR19.5 --- Different levels may select different ships (including
    within one session as levels advance); returning to the Main Menu
    and starting another level applies that level's choice.
-   FR19.6 --- Level authoring: at least one shipped level demonstrates
    the feature with a real-or-placeholder variant; later levels may
    carry their own custom ships.

### Non-Functional Requirements

-   NFR19.1 --- Presentation only: selection never affects hitboxes
    (none exist), damage timing, bullet travel, scoring, or lives.
-   NFR19.2 --- With every level left empty, visuals are identical to
    Phase 18 (regression-protected by unmodified suites).
-   NFR19.3 --- The resolution helper is unit-testable without the
    scene tree (path-in → effective-path-out), mirroring Phase 18's
    normalization-helper pattern.

### Out of Scope

-   Multiple simultaneous player skins, unlocks tied to mastery,
    or menu-side ship pickers (a future stretch concern).
-   Bullet/enemy-bullet restyling.

------------------------------------------------------------------------

## 2. Detailed Implementation Plan

1.  **`LevelConfig.gd`**: add the field plus a resolution helper
    (e.g., `resolved_player_ship_texture() -> String`) implementing
    FR19.2's fallback/warning logic once.
2.  **`player.gd`**: add `apply_ship_texture(path: String)` assigning
    the `Sprite2D.texture` when the resource exists (defensive check as
    in FR19.2); no other changes.
3.  **`main.gd`**: on `_on_level_changed(level)`, resolve through the
    active config (`LevelManager.resolved_config_for`) and call the new
    player method (FR19.3). Verify Play Again path re-runs it via the
    existing restart flow.
4.  **Authoring**: configure a demo level `.tres` (FR19.6) with a
    placeholder variant PNG if real art is unavailable.
5.  **GUT tests** alongside steps 1--2 (see Testing Plan).

------------------------------------------------------------------------

## 3. Testing Plan

### Automated Tests (GUT)

**`test_level_config.gd` (extended)** --- empty/default resolution
returns the default path without warning; configured valid path returns
itself; nonexistent path returns the default and warns exactly once per
call-site contract.

**Player apply test (light)** --- `apply_ship_texture()` with a valid
resource changes the sprite texture; with a bogus path leaves the prior
texture intact (headless-safe using a tiny generated Texture2D).

**Regression** --- full prior suite passes unmodified (NFR19.2).

### Manual Test Checklist

  -------------------------------------------------------------------------------
  \#                      Scenario                Expected Result
  ----------------------- ----------------------- -------------------------------
  1                       Configure Level 2 with  Starting/advancing into Level 2
                          a fighter ship         shows the fighter; Level 1
                                                  keeps the default ship

  2                       Fire and take hits      Muzzle position, fire flash,
                          with the fighter        hit flash, and bullets behave
                          equipped                identically to the default ship

  3                       Game Over → Play Again  The session-start level's ship
                                                  is applied again (not stuck on
                                                  a later level's)

  4                       Put a bogus path in a   One warning; game runs with the
                          level                   default ship; no crash

  5                       Run full GUT suite      Extended tests + full prior
                                                  suite pass, 0 failures
  -------------------------------------------------------------------------------

**Definition of Done:** each level can author its own player ship image
with safe fallbacks, applied consistently across session start, level
advance, and Play Again; presentation-only change verified; green GUT
coverage --- completing the per-level visual/scoring configuration set.
