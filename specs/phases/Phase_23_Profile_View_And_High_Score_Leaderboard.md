# Phase 23 --- Profile View & High Score Leaderboard

**Goal:** turn the single device-wide high score into a top-5 leaderboard
with player names and rank medal icons, add a per-player Profile View
(best scores, record count, highest level reached, per-level bests), and
celebrate on the Game Over screen with a large rank medal when the player
sets a new record or lands in the top 5, plus a "Personal Best!"
congratulation when they beat their own best session score.

**Source docs:** Spec §14 (Profile View & High Score Leaderboard), Spec §4
step 10 (game over), Spec §8 (medal assets), Tech Stack §5
(`HighScoreManager.gd`), §7 (Persistence), Phase 7 FR7.1--FR7.10, Phase 22
FR22.1--FR22.6.

-----------------------------------------------------------------------

## 1. Requirements

### Functional Requirements

**Device-wide top-5 leaderboard**

-   FR23.1 --- `HighScoreManager` persists a device-wide top-5
    leaderboard: an ordered list of `{ name, score }` entries, descending
    by score, capped at 5. The existing `high_score`/`player_name` remain
    the top entry, so the Phase 7/9/22 single-value behavior (FR7.3,
    FR22.4) is preserved.
-   FR23.2 --- `submit_score(score: int) -> Dictionary` is the single
    game-over entry point. It inserts the active player's final score
    into the leaderboard when it qualifies, updates
    `high_score`/`player_name` when it becomes the new #1, records the
    session score into the active profile's best 3, and returns
    `{ rank, new_record, beat_personal_best, leaderboard }`.
-   FR23.3 --- Qualification rule: a score qualifies when the board has
    fewer than 5 entries, or when it is strictly greater than the current
    5th (lowest) entry. Ties at the boundary do not displace an existing
    entry (consistent with NFR7.3). Scores ≤ 0 are never submitted.
-   FR23.4 --- `get_leaderboard() -> Array` returns a copy of the top-5
    entries (name + score), so callers cannot mutate the stored list.
-   FR23.5 --- The Main Menu replaces the single "High Score: X - Name"
    label with a leaderboard table: one row per entry, each row = rank
    medal icon + player name + score. Medals: rank 1 `medal-gold.png`, 2
    `medal-silver.png`, 3 `medal-bronze.png`, 4 `medal-iron.png`, 5
    `medal-wood.png` (all under `assets/images/ui/`, 164×196).

**Profile View**

-   FR23.6 --- A Profile View, accessible from the Main Menu, shows the
    active player's:
    -   best session scores (top 3),
    -   how many times they have set a new device-wide high score record
        (`record_count`),
    -   the highest level they have reached (`highest_level_reached`),
    -   their best score in each level (`personal_bests`).
-   FR23.7 --- Each profile gains `record_count: int` (default 0) and
    `highest_level_reached: int` (default 1). `record_count` increments
    only when the player's submitted score becomes the new #1 (strictly
    greater than the previous high score); a tie never increments it.
    `highest_level_reached` is updated to `max(current, level)` whenever a
    level starts.
-   FR23.8 --- `get_record_count() -> int`, `get_highest_level_reached()
    -> int`, and `record_highest_level_reached(level: int) -> void`
    operate on the active profile only (FR22.3 isolation).

**Game Over celebration**

-   FR23.9 --- On Game Over, when the final score qualifies for the top
    5, the screen announces it with a large rank medal icon:
    -   rank 1: gold medal + "New High Score!" (replacing the current
        text-only callout),
    -   ranks 2--5: the corresponding medal + a "Top 5!" / "Rank #N!"
        announcement.
-   FR23.10 --- When the final score beats the player's own previous best
    session score, the Game Over screen shows a "Personal Best!"
    congratulation, in addition to any leaderboard announcement.
-   FR23.11 --- Sessions that neither qualify for the top 5 nor beat a
    personal best keep the existing "High Score: X - Name" fallback text.

### Non-Functional Requirements

-   NFR23.1 --- Backward compatible: existing save files (Phase 7/9/22
    schema) load without data loss; the leaderboard is reconstructed from
    `high_score`/`player_name` when absent, and the new profile fields
    default safely.
-   NFR23.2 --- No gameplay changes: questions, difficulty, lives,
    timing, and per-level scoring are untouched.
-   NFR23.3 --- Leaderboard and profile logic are unit-testable without
    the scene tree, using GUT's temp-file helpers (NFR7.1/NFR22.3
    pattern).
-   NFR23.4 --- The leaderboard table and Profile View are touch-safe
    (interactive rows ≥ 110 design px, per Phase 11) and safe-area aware.

### Out of Scope

-   Cloud sync or cross-device leaderboards.
-   Profile management UI (delete/rename) or profile switching
    mid-session.
-   Any gameplay, question, difficulty, lives, or timing changes.

-----------------------------------------------------------------------

## 2. Detailed Implementation Plan

1.  **`HighScoreManager.gd`:**
    -   Add `leaderboard: Array` (device-wide) and the per-profile fields
        `record_count` and `highest_level_reached`.
    -   Add `submit_score(score) -> Dictionary` implementing
        FR23.2/FR23.3/FR23.10: qualify/insert into the leaderboard, update
        `high_score`/`player_name` on a new #1, increment the active
        profile's `record_count` on a new record, record the session score
        into the active profile's best 3, and compute `beat_personal_best`
        against the pre-recording best.
    -   Refactor `save_if_higher()` to delegate to `submit_score()` and
        return its `new_record` field, preserving the existing contract
        for Phase 7 tests.
    -   Add `get_leaderboard()`, `get_record_count()`,
        `get_highest_level_reached()`, and
        `record_highest_level_reached(level)`.
    -   Update `load_high_score()`/`_write_save_file()` for the new
        schema, including the NFR23.1 migration path (reconstruct the
        leaderboard from `high_score`/`player_name` when the `leaderboard`
        key is absent).
2.  **`LevelManager.gd`:** call
    `HighScoreManager.record_highest_level_reached(current_level)` in
    `start_level()` so session start, level advance, and Play Again all
    update the active profile's highest level reached (FR23.7).
3.  **`Main.gd`:** in `_on_game_over()`, replace the
    `save_if_higher()` + `record_session_score()` pair with a single
    `submit_score()` call and pass the result dictionary to the Game Over
    overlay.
4.  **`GameOverOverlay`:** add a large rank-medal display + announcement
    (FR23.9) and the "Personal Best!" congratulation (FR23.10); keep the
    fallback text (FR23.11).
5.  **`MainMenu`:** replace the high-score label with the leaderboard
    table (FR23.5) and add the Profile View (FR23.6) --- either a panel in
    the menu or a small separate scene opened from a button.
6.  **GUT tests** alongside steps 1--3 (see Testing Plan).

-----------------------------------------------------------------------

## 3. Testing Plan

### Automated Tests (GUT)

**`test_high_score_manager.gd` (extended)** --- leaderboard insertion and
qualification (fewer than 5 entries; strictly-greater-than-5th rule; ties
at the boundary do not displace); `submit_score()`'s result dictionary
(`rank`, `new_record`, `beat_personal_best`, `leaderboard`); `record_count`
increments only on a new #1 and never on a tie; `highest_level_reached`
is monotonic; `save_if_higher()` still returns `true` only on a strictly
greater score; legacy save files migrate (leaderboard reconstructed, new
fields defaulted); save/reload round-trips the new schema.

**`test_save_data.gd` (extended)** --- the new profile fields persist per
player; the leaderboard persists device-wide and is shared across
profiles; corrupt entries are dropped, not crashed on.

**Regression** --- `test_mastery.gd`, `test_assumed_score.gd`, and the
full prior suite pass unmodified (NFR23.2).

### Manual Test Checklist

  -------------------------------------------------------------------------------
  \#                      Scenario                Expected Result
  ----------------------- ----------------------- -------------------------------
  1                       Play and set a new       Game Over shows a large gold
                          device-wide record      medal + "New High Score!"
                                                  (+ "Personal Best!" if it also
                                                  beats the player's own best)

  2                       Play and land in the    Game Over shows the rank medal
                          top 5 (rank 2--5)       (silver/bronze/iron/wood) +
                                                  "Top 5!" announcement

  3                       Play and beat only      Game Over shows "Personal
                          your own best (not      Best!" without a leaderboard
                          in the top 5)           medal

  4                       Play and neither        Game Over shows the existing
                          qualify nor beat        "High Score: X - Name" text
                          your own best

  5                       Open the Main Menu      Leaderboard table shows up to
                          with 5+ records         5 rows: medal icon + name +
                                                  score, descending

  6                       Open the Profile View   Shows best 3 scores, record
                                                  count, highest level reached,
                                                  and per-level bests for the
                                                  active player

  7                       Switch player names     Profile View and level grid
                          on the Main Menu        reflect the other player's
                                                  data; leaderboard unchanged

  8                       Load a legacy save      Leaderboard reconstructed from
                          file                    high_score/player_name; new
                                                  fields default; no data loss

  9                       Run full GUT suite       Updated tests + full prior
                                                  suite pass, 0 failures
  -------------------------------------------------------------------------------

**Definition of Done:** the device-wide high score is a top-5 leaderboard
with player names and rank medal icons on the Main Menu; each player's
Profile View shows their best scores, record count, highest level reached,
and per-level bests; the Game Over screen announces top-5 finishes with a
large rank medal and congratulates personal-best beats; legacy saves
migrate without data loss; and the full GUT suite is green.
