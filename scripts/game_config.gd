## Single access path for project-level gameplay configuration.
## Gameplay code should use this helper instead of reading ProjectSettings
## directly, so defaults and validation stay in one place.
##
## Phase 9 migration (FR9.1): per-level configuration no longer lives in
## the `gameplay/tries_per_question_by_level` and
## `gameplay/level_time_limit_by_level` Project Setting dictionaries (or in
## derived seconds-per-wave math). Those concerns moved into LevelConfig
## custom resources (.tres) loaded by LevelManager; GameConfig now only
## owns session-wide settings that genuinely are project-global.
extends Node

const STARTING_LIVES_SETTING := "gameplay/starting_lives"
const ENEMIES_PER_WAVE_SETTING := "gameplay/enemies_per_wave"
const TRIES_PER_QUESTION_SETTING := "gameplay/tries_per_question"
## Phase 24 FR24.1: how long the level timer freezes after a wave clears
## before the next wave's arrival animation begins.
const WAVE_COMPLETE_PAUSE_SETTING := "gameplay/wave_complete_pause_seconds"
## Phase 25 FR25.1: level-completion scoring adjustments. The early-finish
## bonus awards 1 point per full `bonus_seconds_per_point` remaining; each
## life lost during a level deducts `lives_lost_penalty_points`.
const BONUS_SECONDS_PER_POINT_SETTING := "gameplay/bonus_seconds_per_point"
const LIVES_LOST_PENALTY_SETTING := "gameplay/lives_lost_penalty_points"

const DEFAULT_STARTING_LIVES := 3
const DEFAULT_ENEMIES_PER_WAVE := 10
## Global fallback attempt count; per-level values come from LevelConfig.
const DEFAULT_TRIES_PER_QUESTION := 1
const DEFAULT_WAVE_COMPLETE_PAUSE := 2.0
const DEFAULT_BONUS_SECONDS_PER_POINT := 5.0
const DEFAULT_LIVES_LOST_PENALTY := 1


func _ready() -> void:
	_ensure_setting(STARTING_LIVES_SETTING, DEFAULT_STARTING_LIVES, TYPE_INT)
	_ensure_setting(ENEMIES_PER_WAVE_SETTING, DEFAULT_ENEMIES_PER_WAVE, TYPE_INT)
	_ensure_setting(TRIES_PER_QUESTION_SETTING, DEFAULT_TRIES_PER_QUESTION, TYPE_INT)
	_ensure_setting(WAVE_COMPLETE_PAUSE_SETTING, DEFAULT_WAVE_COMPLETE_PAUSE, TYPE_FLOAT)
	_ensure_setting(BONUS_SECONDS_PER_POINT_SETTING, DEFAULT_BONUS_SECONDS_PER_POINT, TYPE_FLOAT)
	_ensure_setting(LIVES_LOST_PENALTY_SETTING, DEFAULT_LIVES_LOST_PENALTY, TYPE_INT)


func get_starting_lives() -> int:
	return _get_positive_int_setting(STARTING_LIVES_SETTING, DEFAULT_STARTING_LIVES)


func get_enemies_per_wave() -> int:
	return _get_positive_int_setting(ENEMIES_PER_WAVE_SETTING, DEFAULT_ENEMIES_PER_WAVE)


func get_tries_per_question() -> int:
	return _get_positive_int_setting(TRIES_PER_QUESTION_SETTING, DEFAULT_TRIES_PER_QUESTION)


## Phase 24 FR24.1: the wave-complete pause in seconds, clamped to >= 0.
## Missing or invalid (non-numeric / negative) values fall back to the
## documented default rather than clamping (Phase 4 FR4.2 pattern).
func get_wave_complete_pause_seconds() -> float:
	var value: float = float(ProjectSettings.get_setting(WAVE_COMPLETE_PAUSE_SETTING, DEFAULT_WAVE_COMPLETE_PAUSE))
	if value < 0.0:
		return DEFAULT_WAVE_COMPLETE_PAUSE
	return value


## Phase 25 FR25.1: seconds of remaining level time that earn 1 bonus point
## at level completion. Missing or invalid (non-numeric / below the minimum
## of 1.0) values fall back to the documented default.
func get_bonus_seconds_per_point() -> float:
	var value: float = float(ProjectSettings.get_setting(BONUS_SECONDS_PER_POINT_SETTING, DEFAULT_BONUS_SECONDS_PER_POINT))
	if value < 1.0:
		return DEFAULT_BONUS_SECONDS_PER_POINT
	return value


## Phase 25 FR25.1: points deducted per life lost during a level, applied
## at level completion. Missing or invalid (non-numeric / below the
## minimum of 0) values fall back to the documented default.
func get_lives_lost_penalty_points() -> int:
	var value: int = int(ProjectSettings.get_setting(LIVES_LOST_PENALTY_SETTING, DEFAULT_LIVES_LOST_PENALTY))
	if value < 0:
		return DEFAULT_LIVES_LOST_PENALTY
	return value


func _get_positive_int_setting(path: String, default_value: int) -> int:
	# Missing settings resolve to default_value via get_setting's fallback;
	# present-but-invalid values (non-numeric or below the minimum of 1)
	# also fall back to the documented default rather than clamping
	# (Phase 4 FR4.2: "defaulting safely ... if the setting is missing or
	# invalid").
	var value: int = int(ProjectSettings.get_setting(path, default_value))
	if value < 1:
		return default_value
	return value


func _ensure_setting(path: String, default_value: Variant, type: int) -> void:
	if not ProjectSettings.has_setting(path):
		ProjectSettings.set_setting(path, default_value)
	ProjectSettings.set_initial_value(path, default_value)
	ProjectSettings.add_property_info({
		"name": path,
		"type": type,
	})
