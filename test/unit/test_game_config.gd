extends GutTest


func after_each() -> void:
	ProjectSettings.set_setting(GameConfig.STARTING_LIVES_SETTING, GameConfig.DEFAULT_STARTING_LIVES)
	ProjectSettings.set_setting(GameConfig.ENEMIES_PER_WAVE_SETTING, GameConfig.DEFAULT_ENEMIES_PER_WAVE)
	ProjectSettings.set_setting(GameConfig.TRIES_PER_QUESTION_SETTING, GameConfig.DEFAULT_TRIES_PER_QUESTION)
	ProjectSettings.set_setting(GameConfig.WAVE_COMPLETE_PAUSE_SETTING, GameConfig.DEFAULT_WAVE_COMPLETE_PAUSE)
	ProjectSettings.set_setting(GameConfig.BONUS_SECONDS_PER_POINT_SETTING, GameConfig.DEFAULT_BONUS_SECONDS_PER_POINT)
	ProjectSettings.set_setting(GameConfig.LIVES_LOST_PENALTY_SETTING, GameConfig.DEFAULT_LIVES_LOST_PENALTY)


func test_returns_default_gameplay_values() -> void:
	assert_eq(GameConfig.get_starting_lives(), 3)
	assert_eq(GameConfig.get_enemies_per_wave(), 10)
	assert_eq(GameConfig.get_tries_per_question(), 1)
	assert_eq(GameConfig.get_wave_complete_pause_seconds(), 2.0)
	assert_eq(GameConfig.get_bonus_seconds_per_point(), 5.0)
	assert_eq(GameConfig.get_lives_lost_penalty_points(), 1)


func test_missing_settings_fall_back_to_documented_defaults() -> void:
	ProjectSettings.clear(GameConfig.STARTING_LIVES_SETTING)
	ProjectSettings.clear(GameConfig.ENEMIES_PER_WAVE_SETTING)
	ProjectSettings.clear(GameConfig.TRIES_PER_QUESTION_SETTING)
	ProjectSettings.clear(GameConfig.WAVE_COMPLETE_PAUSE_SETTING)
	ProjectSettings.clear(GameConfig.BONUS_SECONDS_PER_POINT_SETTING)
	ProjectSettings.clear(GameConfig.LIVES_LOST_PENALTY_SETTING)

	assert_eq(GameConfig.get_starting_lives(), 3)
	assert_eq(GameConfig.get_enemies_per_wave(), 10)
	assert_eq(GameConfig.get_tries_per_question(), 1)
	assert_eq(GameConfig.get_wave_complete_pause_seconds(), 2.0)
	assert_eq(GameConfig.get_bonus_seconds_per_point(), 5.0)
	assert_eq(GameConfig.get_lives_lost_penalty_points(), 1)


func test_invalid_settings_fall_back_to_documented_defaults() -> void:
	ProjectSettings.set_setting(GameConfig.STARTING_LIVES_SETTING, 0)
	ProjectSettings.set_setting(GameConfig.ENEMIES_PER_WAVE_SETTING, -5)
	ProjectSettings.set_setting(GameConfig.TRIES_PER_QUESTION_SETTING, "not-a-number")
	ProjectSettings.set_setting(GameConfig.WAVE_COMPLETE_PAUSE_SETTING, -3.0)
	ProjectSettings.set_setting(GameConfig.BONUS_SECONDS_PER_POINT_SETTING, 0.5)
	ProjectSettings.set_setting(GameConfig.LIVES_LOST_PENALTY_SETTING, -2)

	assert_eq(GameConfig.get_starting_lives(), 3)
	assert_eq(GameConfig.get_enemies_per_wave(), 10)
	assert_eq(GameConfig.get_tries_per_question(), 1)
	assert_eq(GameConfig.get_wave_complete_pause_seconds(), 2.0)
	assert_eq(GameConfig.get_bonus_seconds_per_point(), 5.0)
	assert_eq(GameConfig.get_lives_lost_penalty_points(), 1)


func test_configured_values_are_returned_unchanged_when_valid() -> void:
	ProjectSettings.set_setting(GameConfig.STARTING_LIVES_SETTING, 5)
	ProjectSettings.set_setting(GameConfig.ENEMIES_PER_WAVE_SETTING, 12)
	ProjectSettings.set_setting(GameConfig.TRIES_PER_QUESTION_SETTING, 2)
	ProjectSettings.set_setting(GameConfig.WAVE_COMPLETE_PAUSE_SETTING, 5.0)
	ProjectSettings.set_setting(GameConfig.BONUS_SECONDS_PER_POINT_SETTING, 3.0)
	ProjectSettings.set_setting(GameConfig.LIVES_LOST_PENALTY_SETTING, 2)

	assert_eq(GameConfig.get_starting_lives(), 5)
	assert_eq(GameConfig.get_enemies_per_wave(), 12)
	assert_eq(GameConfig.get_tries_per_question(), 2)
	assert_eq(GameConfig.get_wave_complete_pause_seconds(), 5.0)
	assert_eq(GameConfig.get_bonus_seconds_per_point(), 3.0)
	assert_eq(GameConfig.get_lives_lost_penalty_points(), 2)


## Phase 9 FR9.1: per-level dictionaries were migrated away - they are no
## longer part of GameConfig's API or the Project Settings surface.
func test_per_level_dictionary_api_is_gone_after_migration() -> void:
	assert_false(GameConfig.has_method("get_level_time_limit"),
		"time limits now come from LevelConfig resources")
	var script: Script = load("res://scripts/game_config.gd")
	assert_false(script.get_script_property_list().any(
		func(prop): return prop.name == "TRIES_PER_QUESTION_BY_LEVEL_SETTING"))
