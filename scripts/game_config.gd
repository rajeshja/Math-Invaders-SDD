## Single access path for project-level gameplay configuration.
## Gameplay code should use this helper instead of reading ProjectSettings
## directly, so defaults and validation stay in one place.
extends Node

const STARTING_LIVES_SETTING := "gameplay/starting_lives"
const ENEMIES_PER_WAVE_SETTING := "gameplay/enemies_per_wave"
const TRIES_PER_QUESTION_SETTING := "gameplay/tries_per_question"
const TRIES_PER_QUESTION_BY_LEVEL_SETTING := "gameplay/tries_per_question_by_level"
const SECONDS_PER_WAVE_SETTING := "gameplay/seconds_per_wave"
const LEVEL_TIME_LIMIT_BY_LEVEL_SETTING := "gameplay/level_time_limit_by_level"

const DEFAULT_STARTING_LIVES := 3
const DEFAULT_ENEMIES_PER_WAVE := 10
const DEFAULT_TRIES_PER_QUESTION := 1
const DEFAULT_SECONDS_PER_WAVE := 30.0


func _ready() -> void:
	_ensure_setting(STARTING_LIVES_SETTING, DEFAULT_STARTING_LIVES, TYPE_INT)
	_ensure_setting(ENEMIES_PER_WAVE_SETTING, DEFAULT_ENEMIES_PER_WAVE, TYPE_INT)
	_ensure_setting(TRIES_PER_QUESTION_SETTING, DEFAULT_TRIES_PER_QUESTION, TYPE_INT)
	_ensure_setting(TRIES_PER_QUESTION_BY_LEVEL_SETTING, {}, TYPE_DICTIONARY)
	_ensure_setting(SECONDS_PER_WAVE_SETTING, DEFAULT_SECONDS_PER_WAVE, TYPE_FLOAT)
	_ensure_setting(LEVEL_TIME_LIMIT_BY_LEVEL_SETTING, {}, TYPE_DICTIONARY)


func get_starting_lives() -> int:
	return _get_positive_int_setting(STARTING_LIVES_SETTING, DEFAULT_STARTING_LIVES)


func get_enemies_per_wave() -> int:
	return _get_positive_int_setting(ENEMIES_PER_WAVE_SETTING, DEFAULT_ENEMIES_PER_WAVE)


func get_tries_per_question(level: int) -> int:
	var overrides: Variant = ProjectSettings.get_setting(TRIES_PER_QUESTION_BY_LEVEL_SETTING, {})
	if overrides is Dictionary:
		var override_value: Variant = null
		if overrides.has(level):
			override_value = overrides[level]
		elif overrides.has(str(level)):
			override_value = overrides[str(level)]

		if override_value != null:
			var override_int := int(override_value)
			if override_int >= 1:
				return override_int

	return _get_positive_int_setting(TRIES_PER_QUESTION_SETTING, DEFAULT_TRIES_PER_QUESTION)


func get_seconds_per_wave() -> float:
	return _get_positive_float_setting(SECONDS_PER_WAVE_SETTING, DEFAULT_SECONDS_PER_WAVE)


func get_level_time_limit(level: int, wave_count: int) -> float:
	var computed_limit: float = max(1, wave_count) * get_seconds_per_wave()
	var overrides: Variant = ProjectSettings.get_setting(LEVEL_TIME_LIMIT_BY_LEVEL_SETTING, {})
	if overrides is Dictionary:
		var override_value: Variant = null
		if overrides.has(level):
			override_value = overrides[level]
		elif overrides.has(str(level)):
			override_value = overrides[str(level)]

		if _is_positive_number(override_value):
			return float(override_value)

	return computed_limit


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


func _get_positive_float_setting(path: String, default_value: float) -> float:
	var raw_value: Variant = ProjectSettings.get_setting(path, default_value)
	if not _is_positive_number(raw_value):
		return default_value
	var value := float(raw_value)
	if value < 1.0:
		return default_value
	return value


func _is_positive_number(value: Variant) -> bool:
	if value is bool:
		return false
	if not (value is int or value is float):
		return false
	return float(value) > 0.0


func _ensure_setting(path: String, default_value: Variant, type: int) -> void:
	if not ProjectSettings.has_setting(path):
		ProjectSettings.set_setting(path, default_value)
	ProjectSettings.set_initial_value(path, default_value)
	ProjectSettings.add_property_info({
		"name": path,
		"type": type,
	})
