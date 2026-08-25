# Phase 9 --- Level Configuration & Player Experience

**Goal:** Centralize level definitions using Godot Custom Resources, introduce level mastery and skipping, and improve the player and developer experience with Level Select, Splash Screen, Name Entry, and a Mistake Review system.

**Source docs:** Build Plan §Phase 9, Spec §4 (core loop updates), §6 (high score and persistence updates), Tech Stack §4 (Custom Resources) & §5 (`HighScoreManager.gd`, `LevelManager.gd`).

------------------------------------------------------------------------

## 1. Requirements

### Functional Requirements

#### Level Configuration (Custom Resources)
- FR9.1 --- Introduce a new Godot Custom Resource `LevelConfig.gd` to define a single level. It will store: the level number, categories available, wave sizes, difficulty parameters, time limits, and allowed attempts per question.
- FR9.2 --- `LevelManager.gd` is updated to load `.tres` files for level configuration, replacing hardcoded rules for level progression.

#### Mastery & Sequential Level Unlocking
- FR9.3 --- Introduce a Mastery condition: If a player clears a given level without losing a single life, 3 times in a row, they achieve "Mastery" for that level.
- FR9.4 --- Mastering a level unlocks the ability to start directly from the **next** level (Level $N+1$). Level unlocking is sequential.
- FR9.5 --- `HighScoreManager` (or a dedicated `SaveManager`) tracks and persists unlocked levels, mastery progress (e.g., number of flawless clears in a row per level), and personal best scores per level.

#### Player Level Selection & "Assumed Full Score"
- FR9.6 --- Update the Main Menu / Start Screen to allow players to choose their starting level from the pool of levels they have unlocked.
- FR9.7 --- When starting from a skipped level (e.g., starting at Level 2), the "assumed full score" for the skipped level(s) is calculated using the player's personal best score for those skipped level(s).
- FR9.8 --- The HUD score display correctly initializes with the "assumed full score" before the first question of the skipped level.

#### Developer Level Selection
- FR9.9 --- Allow the developer to start the game directly at any level for testing purposes. This should be exposed via a debug toggle or an `@export` variable on `Main.gd` or `LevelManager.gd`.

#### Player Name Entry
- FR9.10 --- Introduce a Name Entry prompt on the Main Menu (or Splash Screen flow) before the game starts. 
- FR9.11 --- The player's name is saved and associated with the persisted high score, updating the Game Over screen to display the high-score holder's name alongside the score.

#### Splash Screen
- FR9.12 --- Add a Splash Screen at game startup containing the Game Title and Developer Logo. It should display for a short duration before fading directly into the Main Menu.

#### Mistake Review System
- FR9.13 --- The game tracks all incorrect answers provided by the player during the current session (storing the question, selected wrong answer, and correct answer).
- FR9.14 --- Add a "Review Mistakes" button on the Game Over screen.
- FR9.15 --- Tapping "Review Mistakes" opens a scrollable panel displaying a list of the tracked mistakes from the session.

### Non-Functional Requirements
- NFR9.1 --- `LevelConfig` resources must be editable completely within the Godot Inspector, empowering non-programmers to define new levels.
- NFR9.2 --- The Mistake Review UI must handle an arbitrary number of mistakes via a `ScrollContainer` to ensure it works on small screens.
- NFR9.3 --- Player profile data (Name, Personal Bests, Unlocked Levels) must be saved locally and loaded safely on startup alongside the High Score.

------------------------------------------------------------------------

## 2. Detailed Implementation Plan

1. **`LevelConfig.gd` (Custom Resource):**
   - Create a script extending `Resource` with `@export` variables for categories, waves, time limit, and difficulty.
   - Create `.tres` files for Level 1, 2, 3, etc.
   - Refactor `LevelManager.gd` to load an array of these `.tres` files and supply data to `WaveManager` and `GameConfig`.

2. **`SaveManager.gd` (or extended `HighScoreManager.gd`):**
   - Extend the saved JSON schema to include: `player_name: String`, `unlocked_level: int` (default 1), `personal_bests: Dictionary` (level index to score), `flawless_streaks: Dictionary` (level index to integer).
   - Implement methods to record flawless clears and reset flawless streaks on taking damage.

3. **Level Start Flow (`Main.gd` & `LevelManager.gd`):**
   - If starting at Level > 1, sum the `personal_bests` of all levels before the starting level and inject this as the starting score in `GameManager`.

4. **UI Additions:**
   - **Splash Screen:** A `Control` node with `TextureRect` for logos and a `Timer`/`Tween` for fading, which `get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")` upon completion.
   - **Main Menu:** Add a `LineEdit` for Name Entry and a Level Select UI (e.g., `OptionButton` or horizontal scrolling list) populated up to the `unlocked_level`.
   - **Mistake Review:** Update `QuestionGenerator` to emit a `question_failed(question, selected, correct)` signal. `GameManager` connects to this and appends to an array. `GameOverScreen` instantiates a `ReviewPanel.tscn` which iterates over this array and creates label entries.

5. **Developer Tooling:**
   - Add `@export var debug_start_level: int = 0` to `Main.gd`. If > 0, bypass the main menu and force start at that level, ignoring unlock restrictions.

------------------------------------------------------------------------

## 3. Testing Plan

### Automated Tests (GUT)
- **`test_level_config.gd`**: Verify `.tres` files can be loaded and supply expected parameters.
- **`test_save_data.gd`**: Verify the new JSON schema saves and loads correctly without destroying legacy save data (graceful migration).
- **`test_mastery.gd`**: Simulate a flawless level clear 3 times and assert that `unlocked_level` increments. Verify taking damage resets the flawless streak counter.
- **`test_assumed_score.gd`**: Verify that starting at a higher level initializes `GameManager.score` with the sum of personal bests of skipped levels.

### Manual Test Checklist
1. Verify Splash Screen shows and fades to Main Menu correctly.
2. Enter Name, play, get a high score. Restart game and verify name persists on high score.
3. Use developer debug toggle to jump to Level 3. 
4. Play Level 1 flawlessly 3 times. Verify Level 2 unlocks in the UI.
5. Start at Level 2. Verify score is not 0 (is equal to Level 1 personal best).
6. Make deliberate mistakes, reach Game Over. Open Mistake Review and verify all mistakes are listed correctly with the selected and correct answers.
