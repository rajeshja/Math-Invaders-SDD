## LevelManager unit tests (Phase 6 behavior, Phase 7 restart, Phase 8
## prime sequence, Phase 9 config-driven sessions).
##
## WaveManager is replaced by a recording double so no real enemy/wave
## scene tree is needed; GameManager/GameConfig remain the real autoloads,
## with their shared state restored in after_each. HighScoreManager (now
## written to by LevelManager's mastery/personal-best bookkeeping) is
## redirected to a throwaway save file for the duration of each test.
extends GutTest

const LevelManagerScript = preload("res://scripts/level_manager.gd")

const BASE_SEQUENCE: Array[String] = [
	"integer_addition", "integer_subtraction", "integer_multiplication", "integer_division"
]
const TEST_DIR := "user://gut_temp_directory/level_manager_test"
const TEST_PATH := "user://gut_temp_directory/level_manager_test/profile.json"


class RecordingWaveManager extends Node:
	var calls: Array = []

	func set_category_sequence(sequence: Array[String]) -> void:
		calls.append({"method": "set_category_sequence", "args": [sequence.duplicate()]})

	func set_generation_options(options: Dictionary) -> void:
		calls.append({"method": "set_generation_options", "args": [options.duplicate()]})

	func start_first_wave(wave_difficulty: int = -1) -> void:
		calls.append({"method": "start_first_wave", "args": [wave_difficulty]})

	func calls_for(method: String) -> Array:
		return calls.filter(func(entry): return entry.method == method)


var level_manager: Node
var wave_stub: RecordingWaveManager
var _real_save_path: String


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	_delete_test_file()
	_real_save_path = HighScoreManager.save_path
	HighScoreManager.save_path = TEST_PATH
	HighScoreManager.load_high_score()
	GameManager.reset_session()
	GameManager.pending_start_level = 0
	wave_stub = RecordingWaveManager.new()
	level_manager = LevelManagerScript.new()
	level_manager.wave_manager = wave_stub
	add_child_autofree(level_manager)


func after_each() -> void:
	HighScoreManager.save_path = _real_save_path
	HighScoreManager.load_high_score()
	_delete_test_file()
	GameManager.reset_session()
	if is_instance_valid(wave_stub):
		wave_stub.free()


func _delete_test_file() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)


func _advance_to_level(target_level: int) -> void:
	while level_manager.current_level < target_level:
		level_manager.on_all_waves_complete()


func _last_sequence() -> Array:
	return wave_stub.calls_for("set_category_sequence").back().args[0]


## -- Phase 9: configs come from .tres resources ------------------------------

func test_defined_levels_load_from_registered_resources() -> void:
	assert_eq(level_manager.total_defined_levels(), LevelConfig.LEVEL_RESOURCE_PATHS.size())

	for level in range(1, level_manager.total_defined_levels() + 1):
		var config: LevelConfig = level_manager.resolved_config_for(level)
		assert_eq(config.level_number, level, "config %d matches its slot" % level)


func test_start_level_applies_level_one_config() -> void:
	level_manager.start_level()

	assert_eq(_last_sequence(), BASE_SEQUENCE)
	assert_eq(level_manager.difficulty, 1)
	assert_eq(level_manager.effective_tries_per_question, 1)
	assert_eq(GameManager.level_time_limit, 120.0)
	var options: Dictionary = wave_stub.calls_for("set_generation_options").back().args[0]
	assert_eq(options.get("max_operand"), 0, "level 1 defers to strategy curves")
	assert_false(options.get("allow_unlike_denominators"))
	assert_eq(options.get("max_decimal_places"), 0)


func test_level_three_config_pins_operand_ceiling() -> void:
	_advance_to_level(3)

	assert_eq(level_manager.difficulty, 3)
	var options: Dictionary = wave_stub.calls_for("set_generation_options").back().args[0]
	assert_eq(options.get("max_operand"), 50, "FR9.3: inspector-configured complexity")


func test_level_five_config_carries_prime_as_fifth_wave_and_budget() -> void:
	_advance_to_level(5)

	var handed: Array = _last_sequence()
	assert_eq(handed.size(), BASE_SEQUENCE.size() + 1, "prime rides in the .tres sequence")
	assert_eq(handed.back(), "prime")
	assert_eq(GameManager.level_time_limit, 150.0, "five-wave budget from the resource")


func test_levels_beyond_defined_set_reuse_last_config_and_keep_climbing() -> void:
	var last_index: int = level_manager.total_defined_levels()
	var last_config: LevelConfig = level_manager.resolved_config_for(last_index)

	var overflow_config: LevelConfig = level_manager.resolved_config_for(last_index + 2)

	assert_eq(overflow_config.level_number, last_config.level_number,
		"beyond-defined levels reuse the final resource")
	assert_eq(overflow_config.difficulty, last_config.difficulty,
		"the shared resource itself is never mutated")
	assert_eq(level_manager.effective_difficulty_for(last_index + 2, overflow_config),
		last_config.difficulty + 2)


## -- Core Phase 6 behavior (unchanged contract) --------------------------------

func test_start_level_hands_base_sequence_then_starts_integer_addition_wave() -> void:
	level_manager.start_level()

	var sequence_calls := wave_stub.calls_for("set_category_sequence")
	var wave_calls := wave_stub.calls_for("start_first_wave")
	assert_eq(sequence_calls.size(), 1)
	assert_eq(wave_calls.size(), 1)
	assert_eq(wave_calls[0].args[0], 1)
	# The sequence hand-off must precede the wave spawn (Phase 6 step 3).
	assert_lt(
		wave_stub.calls.find(sequence_calls[0]),
		wave_stub.calls.find(wave_calls[0]))


func test_all_waves_complete_advances_exactly_one_level_per_call() -> void:
	watch_signals(level_manager)

	level_manager.on_all_waves_complete()
	assert_eq(level_manager.current_level, 2)
	level_manager.on_all_waves_complete()

	assert_eq(level_manager.current_level, 3)
	assert_eq(level_manager.difficulty, 3)
	assert_signal_emit_count(level_manager, "level_changed", 2)


func test_start_level_resets_lives_to_configured_value() -> void:
	level_manager.start_level()
	GameManager.take_damage(2)
	assert_eq(GameManager.lives, 1)

	level_manager.on_all_waves_complete()

	assert_eq(GameManager.lives, GameConfig.get_starting_lives())


## -- Session start & restart (Phase 9 FR9.6/FR9.7/FR9.18) ----------------------

func test_validate_start_level_clamps_into_defined_range() -> void:
	assert_eq(level_manager.validate_start_level(1), 1)
	assert_eq(level_manager.validate_start_level(-4), 1)
	assert_eq(level_manager.validate_start_level(99), level_manager.total_defined_levels())


func test_start_session_defaults_to_level_one_with_zero_score() -> void:
	HighScoreManager.record_personal_best(1, 25)

	level_manager.start_session(1)

	assert_eq(level_manager.current_level, 1)
	assert_eq(GameManager.score, 0)


func test_start_session_injects_assumed_full_score_for_skipped_levels() -> void:
	HighScoreManager.record_personal_best(1, 30)
	HighScoreManager.record_personal_best(2, 40)

	level_manager.start_session(3)

	assert_eq(GameManager.score, 70, "FR9.7: sum of skipped levels' personal bests")
	assert_eq(level_manager.session_start_level, 3)


func test_reset_and_start_returns_to_session_start_level_not_level_one() -> void:
	level_manager.start_session(2)
	_advance_to_level(4)
	assert_eq(level_manager.current_level, 4)

	level_manager.reset_and_start()

	assert_eq(level_manager.current_level, 2, "FR9.18: Play Again restarts the session start level")
	assert_eq(level_manager.difficulty, 2)
	assert_eq(_last_sequence(), BASE_SEQUENCE)
	assert_eq(wave_stub.calls_for("start_first_wave").back().args[0], 2)


func test_reset_and_start_reenables_level_advancement() -> void:
	level_manager.on_all_waves_complete()
	assert_eq(level_manager.current_level, 2)

	level_manager.reset_and_start()
	level_manager.on_all_waves_complete()

	assert_eq(level_manager.current_level, 2)


func test_reset_and_start_restores_session_start_timer_budget() -> void:
	level_manager.start_session(5)
	_advance_to_level(3)
	level_manager.reset_and_start()

	assert_eq(GameManager.level_time_limit, 150.0)
	assert_eq(GameManager.time_remaining, 150.0)


func test_reset_and_start_restores_assumed_starting_score() -> void:
	HighScoreManager.record_personal_best(1, 30)
	level_manager.start_session(2)
	GameManager.add_score(5)

	# Mirrors Main.restart_session(): GameManager owns the score reset using
	# the session's assumed base, then LevelManager re-enters the level.
	GameManager.reset_session(
		HighScoreManager.get_assumed_score_for_level(level_manager.session_start_level))
	level_manager.reset_and_start()

	assert_eq(GameManager.score, 30,
		"FR9.18: same-level Play Again re-applies that session's assumed base")


func test_reset_and_start_resets_lives_like_a_fresh_session() -> void:
	_advance_to_level(2)
	GameManager.take_damage(2)

	level_manager.reset_and_start()

	assert_eq(GameManager.lives, GameConfig.get_starting_lives())
