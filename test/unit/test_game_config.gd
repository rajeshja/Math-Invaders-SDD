extends GutTest


func after_each() -> void:
	ProjectSettings.set_setting(GameConfig.STARTING_LIVES_SETTING, GameConfig.DEFAULT_STARTING_LIVES)
	ProjectSettings.set_setting(GameConfig.ENEMIES_PER_WAVE_SETTING, GameConfig.DEFAULT_ENEMIES_PER_WAVE)
	ProjectSettings.set_setting(GameConfig.TRIES_PER_QUESTION_SETTING, GameConfig.DEFAULT_TRIES_PER_QUESTION)
	ProjectSettings.set_setting(GameConfig.TRIES_PER_QUESTION_BY_LEVEL_SETTING, {})


func test_returns_default_gameplay_values() -> void:
	ProjectSettings.set_setting(GameConfig.STARTING_LIVES_SETTING, GameConfig.DEFAULT_STARTING_LIVES)
	ProjectSettings.set_setting(GameConfig.ENEMIES_PER_WAVE_SETTING, GameConfig.DEFAULT_ENEMIES_PER_WAVE)
	ProjectSettings.set_setting(GameConfig.TRIES_PER_QUESTION_SETTING, GameConfig.DEFAULT_TRIES_PER_QUESTION)
	ProjectSettings.set_setting(GameConfig.TRIES_PER_QUESTION_BY_LEVEL_SETTING, {})

	assert_eq(GameConfig.get_starting_lives(), 3)
	assert_eq(GameConfig.get_enemies_per_wave(), 10)
	assert_eq(GameConfig.get_tries_per_question(1), 1)


func test_missing_settings_fall_back_to_documented_defaults() -> void:
	ProjectSettings.clear(GameConfig.STARTING_LIVES_SETTING)
	ProjectSettings.clear(GameConfig.ENEMIES_PER_WAVE_SETTING)
	ProjectSettings.clear(GameConfig.TRIES_PER_QUESTION_SETTING)

	assert_eq(GameConfig.get_starting_lives(), 3)
	assert_eq(GameConfig.get_enemies_per_wave(), 10)
	assert_eq(GameConfig.get_tries_per_question(1), 1)


func test_invalid_settings_fall_back_to_documented_defaults() -> void:
	ProjectSettings.set_setting(GameConfig.STARTING_LIVES_SETTING, 0)
	ProjectSettings.set_setting(GameConfig.ENEMIES_PER_WAVE_SETTING, -5)
	ProjectSettings.set_setting(GameConfig.TRIES_PER_QUESTION_SETTING, "not-a-number")

	assert_eq(GameConfig.get_starting_lives(), 3)
	assert_eq(GameConfig.get_enemies_per_wave(), 10)
	assert_eq(GameConfig.get_tries_per_question(1), 1)


func test_configured_values_are_returned_unchanged_when_valid() -> void:
	ProjectSettings.set_setting(GameConfig.STARTING_LIVES_SETTING, 5)
	ProjectSettings.set_setting(GameConfig.ENEMIES_PER_WAVE_SETTING, 12)
	ProjectSettings.set_setting(GameConfig.TRIES_PER_QUESTION_SETTING, 2)

	assert_eq(GameConfig.get_starting_lives(), 5)
	assert_eq(GameConfig.get_enemies_per_wave(), 12)
	assert_eq(GameConfig.get_tries_per_question(1), 2)


func test_level_override_replaces_global_attempt_count_when_valid() -> void:
	ProjectSettings.set_setting(GameConfig.TRIES_PER_QUESTION_SETTING, 1)
	ProjectSettings.set_setting(GameConfig.TRIES_PER_QUESTION_BY_LEVEL_SETTING, {
		3: 2,
	})

	assert_eq(GameConfig.get_tries_per_question(3), 2)
	assert_eq(GameConfig.get_tries_per_question(2), 1)


func test_invalid_level_override_falls_back_to_global_attempt_count() -> void:
	ProjectSettings.set_setting(GameConfig.TRIES_PER_QUESTION_SETTING, 4)
	ProjectSettings.set_setting(GameConfig.TRIES_PER_QUESTION_BY_LEVEL_SETTING, {
		3: 0,
	})

	assert_eq(GameConfig.get_tries_per_question(3), 4)
