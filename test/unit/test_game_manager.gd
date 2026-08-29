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


func test_new_session_starts_playing_with_no_reason_recorded() -> void:
	assert_eq(manager.game_state, manager.GameState.PLAYING)
	assert_eq(manager.last_game_over_reason, manager.GameOverReason.NONE)


func test_wrong_answer_damage_consumes_exactly_one_life() -> void:
	manager.lose_life()

	assert_eq(manager.lives, 2)


func test_repeated_wrong_answers_consume_one_life_each() -> void:
	manager.lose_life()
	manager.lose_life()

	assert_eq(manager.lives, 1)
	assert_false(manager.is_game_over())


func test_correct_answer_score_does_not_change_lives() -> void:
	manager.add_score(1)

	assert_eq(manager.score, 1)
	assert_eq(manager.lives, 3)


func test_oversized_damage_clamps_at_zero_instead_of_going_negative() -> void:
	watch_signals(manager)

	manager.take_damage(5)

	assert_eq(manager.lives, 0)
	assert_true(manager.is_game_over())
	assert_signal_emit_count(manager, "game_over", 1)


func test_game_over_fires_once_at_zero_and_lives_never_go_negative() -> void:
	watch_signals(manager)

	manager.lose_life()
	manager.lose_life()
	manager.lose_life()
	manager.lose_life()

	assert_eq(manager.lives, 0)
	assert_true(manager.is_game_over())
	assert_signal_emit_count(manager, "game_over", 1)


func test_depletion_records_lives_depleted_reason() -> void:
	manager.lose_life()
	manager.lose_life()
	manager.lose_life()

	assert_eq(
		manager.last_game_over_reason,
		manager.GameOverReason.LIVES_DEPLETED)


func test_events_after_game_over_are_ignored() -> void:
	watch_signals(manager)

	manager.lose_life()
	manager.lose_life()
	manager.lose_life()
	manager.lose_life()
	manager.lose_life()
	manager.add_score(10)

	assert_eq(manager.lives, 0)
	assert_eq(manager.score, 0)
	assert_signal_emit_count(manager, "game_over", 1)
	assert_signal_emit_count(manager, "lives_changed", 3)


func test_reset_session_restores_lives_clears_reason_and_resumes_play() -> void:
	manager.add_score(7)
	manager.lose_life()
	manager.lose_life()
	manager.lose_life()
	assert_true(manager.is_game_over())

	ProjectSettings.set_setting(GameConfig.STARTING_LIVES_SETTING, 5)
	manager.reset_session()

	assert_eq(manager.lives, 5)
	assert_eq(manager.score, 0)
	assert_eq(manager.game_state, manager.GameState.PLAYING)
	assert_eq(manager.last_game_over_reason, manager.GameOverReason.NONE)
	assert_false(manager.is_game_over())


func test_damage_is_only_consumed_while_playing() -> void:
	manager.game_state = manager.GameState.PAUSED
	manager.lose_life()

	assert_eq(manager.lives, 3)
	assert_false(manager.is_game_over())


func test_start_level_timer_sets_limit_and_time_and_emits_signal() -> void:
	watch_signals(manager)

	manager.start_level_timer(120.0)

	assert_eq(manager.level_time_limit, 120.0)
	assert_eq(manager.time_remaining, 120.0)
	assert_signal_emit_count(manager, "time_changed", 1)


func test_tick_reduces_time_only_by_supplied_delta_while_playing() -> void:
	manager.start_level_timer(120.0)

	manager.tick(1.25)

	assert_eq(manager.time_remaining, 118.75)
	assert_eq(manager.game_state, manager.GameState.PLAYING)


func test_timer_expiry_enters_game_over_once_with_time_reason() -> void:
	manager.start_level_timer(2.0)
	watch_signals(manager)

	manager.tick(1.0)
	manager.tick(1.0)
	manager.tick(1.0)

	assert_eq(manager.time_remaining, 0.0)
	assert_true(manager.is_game_over())
	assert_eq(manager.last_game_over_reason, manager.GameOverReason.TIME_EXPIRED)
	assert_signal_emit_count(manager, "game_over", 1)


func test_ticks_after_timer_game_over_do_not_change_time_or_emit_again() -> void:
	manager.start_level_timer(1.0)
	watch_signals(manager)

	manager.tick(1.5)
	manager.tick(5.0)

	assert_eq(manager.time_remaining, 0.0)
	assert_signal_emit_count(manager, "game_over", 1)


func test_tick_while_paused_does_not_reduce_time() -> void:
	manager.start_level_timer(45.0)
	manager.game_state = manager.GameState.PAUSED

	manager.tick(10.0)

	assert_eq(manager.time_remaining, 45.0)
	assert_false(manager.is_game_over())


func test_life_depletion_and_time_expiry_record_mutually_exclusive_reasons() -> void:
	manager.start_level_timer(120.0)
	manager.take_damage(3)

	assert_eq(manager.last_game_over_reason, manager.GameOverReason.LIVES_DEPLETED)
	manager.tick(120.0)
	assert_eq(manager.last_game_over_reason, manager.GameOverReason.LIVES_DEPLETED)

	manager.start_level_timer(2.0)
	manager.reset_session()
	manager.tick(2.0)

	assert_eq(manager.last_game_over_reason, manager.GameOverReason.TIME_EXPIRED)


func test_reset_session_restores_time_to_configured_limit_and_clears_reason() -> void:
	manager.start_level_timer(90.0)
	manager.tick(90.0)
	assert_true(manager.is_game_over())

	manager.reset_session()

	assert_eq(manager.level_time_limit, 90.0)
	assert_eq(manager.time_remaining, 90.0)
	assert_eq(manager.game_state, manager.GameState.PLAYING)
	assert_eq(manager.last_game_over_reason, manager.GameOverReason.NONE)


## -- Phase 7: restart path --------------------------------------------------

func test_reset_session_from_game_over_resets_score_lives_and_state() -> void:
	ProjectSettings.set_setting(GameConfig.STARTING_LIVES_SETTING, 4)
	manager.add_score(12)
	manager.lose_life()
	manager.lose_life()
	manager.lose_life()
	manager.lose_life()
	assert_true(manager.is_game_over())
	assert_eq(manager.score, 12)

	manager.reset_session()

	assert_eq(manager.score, 0)
	assert_eq(manager.lives, 4)
	assert_eq(manager.game_state, manager.GameState.PLAYING)
	assert_false(manager.is_game_over())


func test_reset_session_from_paused_resets_all_session_state() -> void:
	manager.add_score(5)
	manager.lose_life()
	manager.game_state = manager.GameState.PAUSED

	manager.reset_session()

	assert_eq(manager.score, 0)
	assert_eq(manager.lives, GameConfig.get_starting_lives())
	assert_eq(manager.game_state, manager.GameState.PLAYING)


func test_reset_session_emits_each_hud_signal_exactly_once() -> void:
	var fresh: Node = GameManagerScript.new()
	add_child_autofree(fresh)
	watch_signals(fresh)

	fresh.reset_session()

	assert_signal_emit_count(fresh, "score_changed", 1)
	assert_signal_emit_count(fresh, "lives_changed", 1)
	assert_signal_emit_count(fresh, "time_changed", 1)


## -- Phase 24: wave-transition timer freeze -----------------------------------

func test_tick_is_a_noop_while_transitioning() -> void:
	manager.start_level_timer(120.0)
	manager.set_transition_active(true)

	manager.tick(10.0)

	assert_eq(manager.time_remaining, 120.0,
			"FR24.5: the level timer must not tick during a wave transition")
	assert_false(manager.is_game_over())


func test_timer_resumes_after_transition_ends() -> void:
	manager.start_level_timer(120.0)
	manager.set_transition_active(true)
	manager.tick(10.0)
	assert_eq(manager.time_remaining, 120.0)

	manager.set_transition_active(false)
	manager.tick(10.0)

	assert_eq(manager.time_remaining, 110.0,
			"the timer resumes exactly when the transition clears")


func test_time_remaining_unchanged_across_a_simulated_transition() -> void:
	manager.start_level_timer(120.0)
	manager.set_transition_active(true)
	# Simulate the full pause + 4-row arrival.
	manager.tick(2.0)
	manager.tick(2.0)
	manager.set_transition_active(false)

	assert_eq(manager.time_remaining, 120.0,
			"time_remaining is unchanged across the entire transition")


func test_reset_session_clears_the_transition_flag() -> void:
	manager.set_transition_active(true)
	manager.reset_session()

	assert_false(manager.transitioning,
			"a fresh session must not inherit a frozen timer")
