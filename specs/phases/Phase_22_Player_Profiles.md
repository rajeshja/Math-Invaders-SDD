# Phase 22 --- Per-Player Profiles (Unlocked Levels & Streak Progress)

**Goal:** make progression per-player. Today `HighScoreManager` stores a
single flat profile in `user://highscore.json` --- one `unlocked_level`,
one `personal_bests` dictionary, and one `flawless_streaks` dictionary ---
so every player on a shared device shares the same unlocked levels and
streak progress. This phase keys that progression data by the player name
entered on the Main Menu (FR9.10), so each player has their own unlocked
levels, personal bests, and flawless streak history. The device-wide high
score and its holder's name stay a single leaderboard value. No gameplay,
scoring, or timing behavior changes.

**Source docs:** Spec §11 (Level Configuration & Player Experience ---
Mastery and Sequential Unlocking, Assumed Full Score, Player Name Setup),
Tech Stack §5 (`HighScoreManager.gd`), Phase 9 FRs 9.3--9.11, Phase 7
FR7.1--FR7.10.

------------------------------------------------------------------------

## 1. Requirements

### Functional Requirements

-   FR22.1 --- **Per-player progression:** the save schema gains a
    `profiles` dictionary keyed by player name. Each profile holds that
    player's `unlocked_level`, `personal_bests`, and `flawless_streaks`.
    All progression reads and writes in `HighScoreManager` operate on the
    active player's profile only.
-   FR22.2 --- **Active profile selection:** the name entered on the Main
    Menu (FR9.10) selects the active profile. A name with no existing
    profile starts fresh: `unlocked_level = 1`, empty `personal_bests`,
    and empty `flawless_streaks`. A blank name keeps the last-used
    profile (unchanged from FR9.10's blank-name guard). The profile is
    created only when the player starts playing (START); typing or
    previewing a name in the menu must never create a profile, so
    partial names never leak into the save file.
-   FR22.3 --- **Isolation:** one player's unlocked levels, personal
    bests, and flawless streaks never affect another player's. Unlocking
    (FR9.4), the assumed full score (FR9.7), and streak bookkeeping
    (FR9.3) are all computed from the active player's profile only.
-   FR22.4 --- **Global high score unchanged:** `high_score` and its
    holder `player_name` remain a single device-wide leaderboard value
    (Phase 7/9 behavior preserved). Only progression data becomes
    per-player. The holder name is updated **only** when a new high
    score is set (`save_if_higher`), tagged to the active player; entering
    a different name on the Main Menu must never re-tag the existing high
    score to that name.
-   FR22.5 --- **Legacy migration:** existing flat-schema save files load
    gracefully by wrapping the stored `unlocked_level`, `personal_bests`,
    and `flawless_streaks` under the persisted `player_name` (default
    `"Player"`), preserving all progression. The file is upgraded in
    place on the next write.
-   FR22.6 --- **Best scores per profile:** each profile stores its
    player's best 3 session scores (`top_scores`, descending, capped at
    3). A finished session's final score is recorded into the active
    profile's top 3 when it qualifies. Top scores are per-player and
    persist with the profile.

### Non-Functional Requirements

-   NFR22.1 --- Backward compatible: legacy flat save files load without
    data loss and are upgraded in place on next write (mirrors NFR9.3).
-   NFR22.2 --- No gameplay changes: questions, difficulty, lives,
    timing, and per-level scoring are untouched.
-   NFR22.3 --- The active profile is unit-testable without the scene
    tree (name in → profile out), mirroring the existing
    `HighScoreManager` test pattern.

### Out of Scope

-   Changing the global high-score leaderboard into a per-player
    leaderboard (FR22.4 keeps it device-wide).
-   Multiple simultaneous profiles, profile switching mid-session, or
    profile management UI (delete/rename).
-   Cloud sync or cross-device profile storage.
-   Any gameplay, question, difficulty, lives, or timing changes.

------------------------------------------------------------------------

## 2. Detailed Implementation Plan

1.  **`HighScoreManager.gd`:** add a `profiles: Dictionary` (name →
    profile) and an `active_player_name: String`; add a private
    `_active_profile() -> Dictionary` helper that returns a fresh profile
    for the active name **without storing it** (reads never create
    profiles), plus a private `_ensure_active_profile() -> Dictionary`
    that stores a fresh profile on first write. Refactor
    `get_unlocked_level()`, `get_personal_best()`, `get_flawless_streak()`,
    `record_personal_best()`, `record_flawless_clear()`,
    `reset_flawless_streak()`, and `get_assumed_score_for_level()` to
    read/write the active profile instead of the flat top-level fields.
    Add `last_player_name` (the last player who started a session, used to
    restore the active profile on launch and to prefill the menu) and
    `top_scores` per profile (FR22.6). `save_if_higher()` tags the holder
    `player_name` to the active player only when a new record is set
    (FR22.4); `set_player_name()` selects the active profile and persists
    `last_player_name` but never touches the holder. Update
    `load_high_score()` and `_write_save_file()` for the new schema,
    including the FR22.5 legacy migration path.
2.  **`MainMenu.gd`:** when the player's name is set (FR9.10), set
    `HighScoreManager.active_player_name` before the level grid is
    populated, so the grid reflects that player's unlocked levels.
    Prefill the name field with the last-used player name, and show the
    active player's best 3 scores. Typing a name only previews the grid;
    the profile is committed (created) when START is pressed.
3.  **`Main.gd`:** on Game Over, record the session's final score into the
    active profile's top 3 alongside the existing `save_if_higher()` call
    (FR22.6).
4.  **GUT tests** alongside step 1 (see Testing Plan).

------------------------------------------------------------------------

## 3. Testing Plan

### Automated Tests (GUT)

**`test_save_data.gd` (updated)** --- the new `profiles` schema
round-trips through a fresh instance; two players' profiles persist
independently; a legacy flat-schema file migrates its progression into
the stored name's profile without losing the high score; corrupt or
malformed profile entries are dropped, not crashed on; previewing partial
names never creates profiles while START commits one; and each profile's
best 3 scores are recorded, capped, and persisted per player.

**`test_mastery.gd` (updated)** --- mastering a level under player A
unlocks only A's next level; player B still starts at Level 1 with no
streak progress; streaks are tracked per player, not shared.

**`test_assumed_score.gd` (updated)** --- the assumed full score uses the
active player's personal bests only; a player with no bests for skipped
levels starts at zero regardless of another player's bests.

**`test_high_score_manager.gd` (updated)** --- entering a new player name
never re-tags the existing high score to that name; the holder is only
updated when a new record is set, tagged to the active player (FR22.4).

**Regression** --- full prior suite passes unmodified (NFR22.2).

### Manual Test Checklist

  -------------------------------------------------------------------------------
  \#                      Scenario                Expected Result
  ----------------------- ----------------------- -------------------------------
  1                       Enter name "A", master   Level 2 unlocks for "A" only
                          Level 1 (3 flawless
                          clears)

  2                       Restart, enter name      Level 1 only; no personal
                          "B"                      bests or streak progress

  3                       Switch back to "A"       Level 2 still unlocked; streak
                                                  and personal bests intact

  4                       Start at Level 2 as      Score seeds with "A"'s Level 1
                          "A"                      personal best; as "B" it seeds
                                                  with 0

  5                       Load a legacy flat       Progression preserved under the
                          save file                stored name; file upgraded on
                                                  next write

  6                       Type "Mohan" in the      No profiles are created while
                          name field (partial      typing; only "Mohan" exists
                          keystrokes) then START   after starting play

  7                       "A" sets the high        Entering "B" afterwards keeps
                          score, then "B"          the high score tagged to "A";
                          enters their name        only beating it re-tags to "B"

  8                       Play 4 sessions as       The profile keeps only the best
                          "A"                      three scores, descending

  9                       Run full GUT suite       Updated tests + full prior
                                                  suite pass, 0 failures
  -------------------------------------------------------------------------------

**Definition of Done:** each player's unlocked levels, personal bests,
and flawless streak progress are isolated per name; a new name starts
fresh; typing a name never creates profiles until play starts; the global
high score and holder remain a single leaderboard value tagged to the
player who achieved it; each profile persists its best 3 scores; legacy
flat save files migrate without data loss; and the full GUT suite is
green.
