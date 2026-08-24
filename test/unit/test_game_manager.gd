extends GutTest

const GameManagerScript = preload("res://scripts/game_manager.gd")

var manager: Node


func before_each() -> void:
	ProjectSettings.set_setting(GameConfig.STARTING_LIVES_SETTING, 3)
	manager = GameManagerScript.new()
	add_child_autofree(manager)
	manager.reset_session()


func after_each() -> void:
	ProjectSettings.set_setting(GameConfig.STARTING_LIVES_SETTING, GameConfig.DEFAULT_STARTING_LIVES)


func test_reset_session_loads_configured_starting_lives() -> void:
	ProjectSettings.set_setting(GameConfig.STARTING_LIVES_SETTING, 5)
	manager.reset_session()

	assert_eq(manager.starting_lives, 5)
	assert_eq(manager.lives, 5)
	assert_false(manager.is_game_over())


func test_wrong_answer_damage_consumes_exactly_one_life() -> void:
	manager.lose_life()

	assert_eq(manager.lives, 2)


func test_game_over_fires_once_at_zero_and_lives_never_go_negative() -> void:
	watch_signals(manager)

	manager.lose_life()
	manager.lose_life()
	manager.lose_life()
	manager.lose_life()

	assert_eq(manager.lives, 0)
	assert_true(manager.is_game_over())
	assert_signal_emit_count(manager, "game_over", 1)


func test_correct_answer_score_does_not_change_lives() -> void:
	manager.add_score(1)

	assert_eq(manager.score, 1)
	assert_eq(manager.lives, 3)
