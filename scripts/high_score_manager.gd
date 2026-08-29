## Persists the player profile and session records to a small JSON file in
## user:// so they survive app restarts (Tech Stack §5/§7).
##
## Phase 9 extends the original single-key high-score schema (FR9.5) with:
##   player_name      - name entered on the Main Menu (FR9.10/FR9.11)
##   unlocked_level   - highest level selectable on the Main Menu; grows
##                      only via mastery of the previous level (FR9.4)
##   personal_bests   - level number -> best score achieved *in* that level;
##                      sums into the "assumed full score" when skipping
##                      ahead (FR9.7)
##   flawless_streaks - level number -> consecutive flawless clears
##                      (mastery progress, FR9.3)
##
## Deliberately decoupled from GameManager (Phase 0 architecture note):
## gameplay code calls the record/save methods; this autoload never reads
## game state on its own. `save_path` is a settable property purely so
## tests can redirect I/O away from the real save file (NFR7.1).
extends Node

const DEFAULT_SAVE_PATH := "user://highscore.json"
const HIGH_SCORE_KEY := "high_score"
const PLAYER_NAME_KEY := "player_name"
const UNLOCKED_LEVEL_KEY := "unlocked_level"
const PERSONAL_BESTS_KEY := "personal_bests"
const FLAWLESS_STREAKS_KEY := "flawless_streaks"

const DEFAULT_UNLOCKED_LEVEL := 1
## Flawless clears in a row required to master a level (FR9.3) and unlock
## the next one.
const MASTERY_REQUIRED_CLEARS := 3
const DEFAULT_PLAYER_NAME := "Player"

var save_path: String = DEFAULT_SAVE_PATH
var high_score: int = 0
var player_name: String = ""
var unlocked_level: int = DEFAULT_UNLOCKED_LEVEL
var personal_bests: Dictionary = {}
var flawless_streaks: Dictionary = {}


func _ready() -> void:
	load_high_score()


## Reads the persisted profile. A missing file (first run), a legacy
## Phase 7 schema, or malformed content all fall back to safe defaults
## rather than raising an error (FR7.3/NFR7.2/NFR9.3 graceful migration).
func load_high_score() -> void:
	high_score = 0
	player_name = ""
	unlocked_level = DEFAULT_UNLOCKED_LEVEL
	personal_bests = {}
	flawless_streaks = {}
	if not FileAccess.file_exists(save_path):
		return

	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_warning("HighScoreManager: could not open %s for reading." % save_path)
		return

	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	# Instance-level parse() returns an Error instead of printing one, keeping
	# corrupt saves a silent fallback-to-default rather than a runtime error.
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return

	var data: Dictionary = json.data
	_high_score_from_value(data.get(HIGH_SCORE_KEY, 0))
	player_name = _player_name_from_value(data.get(PLAYER_NAME_KEY, ""))
	unlocked_level = _unlocked_level_from_value(data.get(UNLOCKED_LEVEL_KEY, DEFAULT_UNLOCKED_LEVEL))
	personal_bests = _level_keyed_int_dictionary(data.get(PERSONAL_BESTS_KEY, {}))
	flawless_streaks = _level_keyed_int_dictionary(data.get(FLAWLESS_STREAKS_KEY, {}))


func get_high_score() -> int:
	return high_score


func get_player_name() -> String:
	return player_name


func get_unlocked_level() -> int:
	return max(DEFAULT_UNLOCKED_LEVEL, unlocked_level)


func get_flawless_streak(level: int) -> int:
	return flawless_streaks.get(level, 0)


func get_personal_best(level: int) -> int:
	return personal_bests.get(level, 0)


## Records `score` only when it strictly exceeds the stored value, so a tie
## is never reported as a new record (NFR7.3). Returns whether a new record
## was set; nothing is written to disk otherwise.
func save_if_higher(score: int) -> bool:
	if score <= high_score:
		return false
	high_score = score
	_write_save_file()
	return true


## Stores the entered display name (trimmed). Empty entries keep the last
## stored name so an accidental blank save cannot wipe it.
func set_player_name(new_name: String) -> void:
	var trimmed := new_name.strip_edges()
	if trimmed.is_empty():
		return
	if trimmed == player_name:
		return
	player_name = trimmed
	_write_save_file()


## Records a completed level's earned score as that level's personal best
## when it strictly beats the old value. Returns true when a new best was
## recorded (FR9.5/FR9.7 support).
func record_personal_best(level: int, score: int) -> bool:
	if level < 1:
		return false
	var best := maxi(0, score)
	if best <= get_personal_best(level):
		return false
	personal_bests[level] = best
	_write_save_file()
	return true


## Called when a level is cleared without losing a life: bumps the level's
## flawless streak and, on reaching MASTERY_REQUIRED_CLEARS, unlocks the
## NEXT level sequentially (FR9.3/FR9.4). `unlock_cap` bounds unlocking by
## the number of defined levels (-1 = uncapped). Returns true only on the
## call that performs a new unlock.
func record_flawless_clear(level: int, unlock_cap: int = -1) -> bool:
	var normalized_level := maxi(1, level)
	var streak := get_flawless_streak(normalized_level) + 1
	flawless_streaks[normalized_level] = streak

	var newly_unlocked := false
	if streak >= MASTERY_REQUIRED_CLEARS:
		var candidate := normalized_level + 1
		# Sequential unlocking (FR9.4): the mastered level must itself be
		# unlocked before its successor can be, so a stray clear on a locked
		# level can never skip ahead of the frontier.
		if normalized_level <= get_unlocked_level() \
				and candidate > get_unlocked_level() \
				and (unlock_cap < 0 or candidate <= unlock_cap):
			unlocked_level = candidate
			newly_unlocked = true
	_write_save_file()
	return newly_unlocked


## Any lost life during a level invalidates its flawless run and breaks
## the "in a row" chain (FR9.3).
func reset_flawless_streak(level: int) -> void:
	var normalized_level := maxi(1, level)
	if not flawless_streaks.has(normalized_level):
		return
	flawless_streaks.erase(normalized_level)
	_write_save_file()


## Sum of personal bests for every level BEFORE `start_level` - the
## "assumed full score" injected at session start when skipping ahead
## (FR9.7/FR9.8).
func get_assumed_score_for_level(start_level: int) -> int:
	var assumed := 0
	for level in range(1, maxi(1, start_level)):
		assumed += get_personal_best(level)
	return assumed


func _write_save_file() -> void:
	var payload := {
		HIGH_SCORE_KEY: high_score,
		PLAYER_NAME_KEY: player_name,
		UNLOCKED_LEVEL_KEY: unlocked_level,
		PERSONAL_BESTS_KEY: personal_bests,
		FLAWLESS_STREAKS_KEY: flawless_streaks,
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("HighScoreManager: could not write %s." % save_path)
		return
	file.store_string(JSON.stringify(payload))
	file.close()


func _high_score_from_value(value: Variant) -> void:
	if value is int or value is float:
		high_score = max(0, int(value))


func _player_name_from_value(value: Variant) -> String:
	if value is String:
		return value.strip_edges()
	return ""


func _unlocked_level_from_value(value: Variant) -> int:
	if value is bool or not (value is int or value is float):
		return DEFAULT_UNLOCKED_LEVEL
	var parsed := int(value)
	return maxi(DEFAULT_UNLOCKED_LEVEL, parsed)


## JSON round-trips turn int dictionary keys into strings; normalize both
## shapes back to int -> non-negative-int entries, dropping anything else
## so corrupt/partial data can never leak into gameplay math.
func _level_keyed_int_dictionary(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for key: Variant in value.keys():
		var entry: Variant = value[key]
		if entry is bool or not (entry is int or entry is float):
			continue
		var parsed_value := int(entry)
		if parsed_value < 0:
			continue
		var numeric_key: Variant = key if key is int else int(str(key))
		if typeof(numeric_key) != TYPE_INT or numeric_key < 1:
			continue
		result[numeric_key] = parsed_value
	return result
