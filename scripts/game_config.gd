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

const DEFAULT_STARTING_LIVES := 3
const DEFAULT_ENEMIES_PER_WAVE := 10
## Global fallback attempt count; per-level values come from LevelConfig.
const DEFAULT_TRIES_PER_QUESTION := 1


func _ready() -> void:
	_ensure_setting(STARTING_LIVES_SETTING, DEFAULT_STARTING_LIVES, TYPE_INT)
	_ensure_setting(ENEMIES_PER_WAVE_SETTING, DEFAULT_ENEMIES_PER_WAVE, TYPE_INT)
	_ensure_setting(TRIES_PER_QUESTION_SETTING, DEFAULT_TRIES_PER_QUESTION, TYPE_INT)


func get_starting_lives() -> int:
	return _get_positive_int_setting(STARTING_LIVES_SETTING, DEFAULT_STARTING_LIVES)


func get_enemies_per_wave() -> int:
	return _get_positive_int_setting(ENEMIES_PER_WAVE_SETTING, DEFAULT_ENEMIES_PER_WAVE)


func get_tries_per_question() -> int:
	return _get_positive_int_setting(TRIES_PER_QUESTION_SETTING, DEFAULT_TRIES_PER_QUESTION)


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
