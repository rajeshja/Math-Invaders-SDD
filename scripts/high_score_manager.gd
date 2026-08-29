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
## Phase 22 (FR22.1-FR22.6) keys that progression by player name: the save
## schema gains a `profiles` dictionary (name -> profile) holding each
## player's unlocked_level, personal_bests, flawless_streaks, and
## top_scores (best 3 session scores). The device-wide high_score and its
## holder player_name stay a single leaderboard value (FR22.4): the holder
## is tagged to the active player ONLY when a new record is set, never when
## a name is entered. `last_player_name` remembers the last player who
## started a session so the active profile is restored on launch. Legacy
## flat-schema files migrate in place on load (FR22.5).
##
## Deliberately decoupled from GameManager (Phase 0 architecture note):
## gameplay code calls the record/save methods; this autoload never reads
## game state on its own. `save_path` is a settable property purely so
## tests can redirect I/O away from the real save file (NFR7.1).
extends Node

const DEFAULT_SAVE_PATH := "user://highscore.json"
const HIGH_SCORE_KEY := "high_score"
const PLAYER_NAME_KEY := "player_name"
const LAST_PLAYER_NAME_KEY := "last_player_name"
const PROFILES_KEY := "profiles"
const UNLOCKED_LEVEL_KEY := "unlocked_level"
const PERSONAL_BESTS_KEY := "personal_bests"
const FLAWLESS_STREAKS_KEY := "flawless_streaks"
const TOP_SCORES_KEY := "top_scores"

const DEFAULT_UNLOCKED_LEVEL := 1
## Flawless clears in a row required to master a level (FR9.3) and unlock
## the next one.
const MASTERY_REQUIRED_CLEARS := 3
const DEFAULT_PLAYER_NAME := "Player"
## Best session scores kept per profile (FR22.6).
const TOP_SCORES_COUNT := 3

var save_path: String = DEFAULT_SAVE_PATH
var high_score: int = 0
## Device-wide leaderboard holder (FR22.4): the name of whoever set the
## high score. Updated only when a new record is set; never on name entry.
var player_name: String = ""
## The last player who started a session; restores the active profile on
## launch and prefills the Main Menu name field.
var last_player_name: String = ""
## Name -> profile dictionary (FR22.1). Each profile holds that player's
## unlocked_level, personal_bests, flawless_streaks, and top_scores.
var profiles: Dictionary = {}
## The profile all progression reads/writes target (FR22.2). Set from the
## name entered on the Main Menu; falls back to DEFAULT_PLAYER_NAME.
var active_player_name: String = ""


func _ready() -> void:
	load_high_score()


## Reads the persisted profile. A missing file (first run), a legacy
## Phase 7/9 flat schema, or malformed content all fall back to safe
## defaults rather than raising an error (FR7.3/NFR7.2/NFR9.3 graceful
## migration). Legacy flat files are wrapped under the persisted name
## (FR22.5) and upgraded in place on the next write.
func load_high_score() -> void:
	high_score = 0
	player_name = ""
	last_player_name = ""
	active_player_name = ""
	profiles = {}
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
	# Older schemas had no separate last-player field; the persisted name was
	# the last player, so fall back to it.
	last_player_name = _player_name_from_value(data.get(LAST_PLAYER_NAME_KEY, player_name))
	active_player_name = last_player_name
	profiles = _profiles_from_value(data.get(PROFILES_KEY, {}))
	# FR22.5: a flat-schema file (no `profiles` key) wraps its progression
	# under the persisted name so nothing is lost; the file is upgraded in
	# place on the next write.
	if not data.has(PROFILES_KEY):
		var legacy_name := last_player_name if not last_player_name.is_empty() else DEFAULT_PLAYER_NAME
		profiles[legacy_name] = {
			UNLOCKED_LEVEL_KEY: _unlocked_level_from_value(
					data.get(UNLOCKED_LEVEL_KEY, DEFAULT_UNLOCKED_LEVEL)),
			PERSONAL_BESTS_KEY: _level_keyed_int_dictionary(data.get(PERSONAL_BESTS_KEY, {})),
			FLAWLESS_STREAKS_KEY: _level_keyed_int_dictionary(data.get(FLAWLESS_STREAKS_KEY, {})),
			TOP_SCORES_KEY: [],
		}
		active_player_name = legacy_name


func get_high_score() -> int:
	return high_score


## The device-wide high-score holder's name (FR22.4).
func get_player_name() -> String:
	return player_name


## The last player who started a session (used to prefill the menu and
## restore the active profile on launch).
func get_last_player_name() -> String:
	return last_player_name


func get_unlocked_level() -> int:
	return max(DEFAULT_UNLOCKED_LEVEL,
			_active_profile().get(UNLOCKED_LEVEL_KEY, DEFAULT_UNLOCKED_LEVEL))


func get_flawless_streak(level: int) -> int:
	return _active_profile().get(FLAWLESS_STREAKS_KEY, {}).get(level, 0)


func get_personal_best(level: int) -> int:
	return _active_profile().get(PERSONAL_BESTS_KEY, {}).get(level, 0)


## The active player's best 3 session scores, descending (FR22.6). Returns
## a copy so callers cannot mutate the stored list.
func get_top_scores() -> Array:
	return _active_profile().get(TOP_SCORES_KEY, []).duplicate()


## Records `score` only when it strictly exceeds the stored value, so a tie
## is never reported as a new record (NFR7.3). Returns whether a new record
## was set; nothing is written to disk otherwise. On a new record the
## holder `player_name` is tagged to the active player (FR22.4).
func save_if_higher(score: int) -> bool:
	if score <= high_score:
		return false
	high_score = score
	player_name = _resolved_active_name()
	_write_save_file()
	return true


## Commits the entered display name (trimmed) as the active profile and
## remembers it as the last player (FR22.2). Called when the player starts
## playing; this is where a new profile is created. Empty entries keep the
## last-used profile so an accidental blank save cannot wipe it. Never
## touches the high-score holder `player_name` (FR22.4).
func set_player_name(new_name: String) -> void:
	var trimmed := new_name.strip_edges()
	if trimmed.is_empty():
		return
	active_player_name = trimmed
	_ensure_active_profile()
	if trimmed == last_player_name:
		return
	last_player_name = trimmed
	_write_save_file()


## Selects the active profile without persisting and without creating a
## profile (FR22.2). Used by the Main Menu to preview a typed name's
## unlocked levels before START commits it. Blank entries keep the
## last-used profile.
func set_active_player_name(new_name: String) -> void:
	var trimmed := new_name.strip_edges()
	if trimmed.is_empty():
		return
	active_player_name = trimmed


## Records a completed level's earned score as that level's personal best
## when it strictly beats the old value. Returns true when a new best was
## recorded (FR9.5/FR9.7 support).
func record_personal_best(level: int, score: int) -> bool:
	if level < 1:
		return false
	var best := maxi(0, score)
	if best <= get_personal_best(level):
		return false
	_ensure_active_profile()[PERSONAL_BESTS_KEY][level] = best
	_write_save_file()
	return true


## Called when a level is cleared without losing a life: bumps the level's
## flawless streak and, on reaching MASTERY_REQUIRED_CLEARS, unlocks the
## NEXT level sequentially (FR9.3/FR9.4). `unlock_cap` bounds unlocking by
## the number of defined levels (-1 = uncapped). Returns true only on the
## call that performs a new unlock.
func record_flawless_clear(level: int, unlock_cap: int = -1) -> bool:
	var normalized_level := maxi(1, level)
	var profile := _ensure_active_profile()
	var streaks: Dictionary = profile[FLAWLESS_STREAKS_KEY]
	var streak: int = streaks.get(normalized_level, 0) + 1
	streaks[normalized_level] = streak

	var newly_unlocked := false
	if streak >= MASTERY_REQUIRED_CLEARS:
		var candidate := normalized_level + 1
		# Sequential unlocking (FR9.4): the mastered level must itself be
		# unlocked before its successor can be, so a stray clear on a locked
		# level can never skip ahead of the frontier.
		if normalized_level <= get_unlocked_level() \
				and candidate > get_unlocked_level() \
				and (unlock_cap < 0 or candidate <= unlock_cap):
			profile[UNLOCKED_LEVEL_KEY] = candidate
			newly_unlocked = true
	_write_save_file()
	return newly_unlocked


## Any lost life during a level invalidates its flawless run and breaks
## the "in a row" chain (FR9.3).
func reset_flawless_streak(level: int) -> void:
	var normalized_level := maxi(1, level)
	var streaks: Dictionary = _ensure_active_profile()[FLAWLESS_STREAKS_KEY]
	if not streaks.has(normalized_level):
		return
	streaks.erase(normalized_level)
	_write_save_file()


## Sum of personal bests for every level BEFORE `start_level` - the
## "assumed full score" injected at session start when skipping ahead
## (FR9.7/FR9.8). Computed from the active player's bests only (FR22.3).
func get_assumed_score_for_level(start_level: int) -> int:
	var assumed := 0
	for level in range(1, maxi(1, start_level)):
		assumed += get_personal_best(level)
	return assumed


## Records a finished session's final score into the active profile's best
## 3 (FR22.6). Scores of zero are ignored; the list stays sorted
## descending and capped at TOP_SCORES_COUNT.
func record_session_score(score: int) -> void:
	var best := maxi(0, score)
	if best <= 0:
		return
	var profile := _ensure_active_profile()
	var top: Array = profile.get(TOP_SCORES_KEY, [])
	top.append(best)
	top.sort()
	top.reverse()
	if top.size() > TOP_SCORES_COUNT:
		top.resize(TOP_SCORES_COUNT)
	profile[TOP_SCORES_KEY] = top
	_write_save_file()


## The active player's profile for reads. Returns a fresh (non-stored)
## profile when the name has none yet, so previewing a name never creates
## a profile (FR22.2).
func _active_profile() -> Dictionary:
	var name := _resolved_active_name()
	if profiles.has(name):
		return profiles[name]
	return _fresh_profile()


## The active player's profile for writes, stored into `profiles` on first
## access so a new player's profile is created exactly when play starts.
func _ensure_active_profile() -> Dictionary:
	var name := _resolved_active_name()
	if not profiles.has(name):
		profiles[name] = _fresh_profile()
	return profiles[name]


func _resolved_active_name() -> String:
	return active_player_name if not active_player_name.is_empty() else DEFAULT_PLAYER_NAME


func _fresh_profile() -> Dictionary:
	return {
		UNLOCKED_LEVEL_KEY: DEFAULT_UNLOCKED_LEVEL,
		PERSONAL_BESTS_KEY: {},
		FLAWLESS_STREAKS_KEY: {},
		TOP_SCORES_KEY: [],
	}


func _write_save_file() -> void:
	var payload := {
		HIGH_SCORE_KEY: high_score,
		PLAYER_NAME_KEY: player_name,
		LAST_PLAYER_NAME_KEY: last_player_name,
		PROFILES_KEY: profiles,
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


## Normalizes a profile's `top_scores` array: non-negative ints only,
## sorted descending, capped at TOP_SCORES_COUNT.
func _top_scores_from_value(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry: Variant in value:
		if entry is bool or not (entry is int or entry is float):
			continue
		var parsed := int(entry)
		if parsed < 0:
			continue
		result.append(parsed)
	result.sort()
	result.reverse()
	if result.size() > TOP_SCORES_COUNT:
		result.resize(TOP_SCORES_COUNT)
	return result


## Normalizes the persisted `profiles` dictionary: name -> profile, where
## each profile is a fresh-shaped dictionary with sanitized values. Corrupt
## or malformed entries are dropped, never crashed on (FR22.1).
func _profiles_from_value(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for name: Variant in value.keys():
		if not (name is String):
			continue
		var profile: Variant = value[name]
		if typeof(profile) != TYPE_DICTIONARY:
			continue
		result[name] = {
			UNLOCKED_LEVEL_KEY: _unlocked_level_from_value(
					profile.get(UNLOCKED_LEVEL_KEY, DEFAULT_UNLOCKED_LEVEL)),
			PERSONAL_BESTS_KEY: _level_keyed_int_dictionary(profile.get(PERSONAL_BESTS_KEY, {})),
			FLAWLESS_STREAKS_KEY: _level_keyed_int_dictionary(profile.get(FLAWLESS_STREAKS_KEY, {})),
			TOP_SCORES_KEY: _top_scores_from_value(profile.get(TOP_SCORES_KEY, [])),
		}
	return result
