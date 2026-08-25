## LevelManager unit tests (Phase 6 behavior plus Phase 7's reset_and_start).
##
## WaveManager is replaced by a recording double so no real enemy/wave
## scene tree is needed; GameManager/GameConfig remain the real autoloads,
## with their shared state restored in after_each.
extends GutTest

const LevelManagerScript = preload("res://scripts/level_manager.gd")

const BASE_SEQUENCE: Array[String] = [
	"addition", "subtraction", "multiplication", "division"
]


class RecordingWaveManager extends Node:
	var calls: Array = []

	func set_category_sequence(sequence: Array[String]) -> void:
		calls.append({"method": "set_category_sequence", "args": [sequence.duplicate()]})

	func start_first_wave(wave_difficulty: int = -1) -> void:
		calls.append({"method": "start_first_wave", "args": [wave_difficulty]})

	func calls_for(method: String) -> Array:
		return calls.filter(func(entry): return entry.method == method)


var level_manager: Node
var wave_stub: RecordingWaveManager


func before_each() -> void:
	ProjectSettings.set_setting(GameConfig.SECONDS_PER_WAVE_SETTING, 30.0)
	ProjectSettings.set_setting(GameConfig.LEVEL_TIME_LIMIT_BY_LEVEL_SETTING, {})
	GameManager.reset_session()
	wave_stub = RecordingWaveManager.new()
	level_manager = LevelManagerScript.new()
	level_manager.wave_manager = wave_stub
	add_child_autofree(level_manager)


func after_each() -> void:
	ProjectSettings.set_setting(GameConfig.SECONDS_PER_WAVE_SETTING, GameConfig.DEFAULT_SECONDS_PER_WAVE)
	ProjectSettings.set_setting(GameConfig.LEVEL_TIME_LIMIT_BY_LEVEL_SETTING, {})
	GameManager.reset_session()
	if is_instance_valid(wave_stub):
		wave_stub.free()


func _advance_to_level(target_level: int) -> void:
	while level_manager.current_level < target_level:
		level_manager.on_all_waves_complete()


func test_difficulty_formula_matches_max_one_level() -> void:
	assert_eq(level_manager.difficulty_for_level(1), 1)
	assert_eq(level_manager.difficulty_for_level(4), 4)
	assert_eq(level_manager.difficulty_for_level(0), 1)


func test_start_level_hands_base_sequence_then_starts_addition_wave() -> void:
	level_manager.start_level()

	var sequence_calls := wave_stub.calls_for("set_category_sequence")
	var wave_calls := wave_stub.calls_for("start_first_wave")
	assert_eq(sequence_calls.size(), 1)
	assert_eq(wave_calls.size(), 1)
	assert_eq(sequence_calls[0].args[0], BASE_SEQUENCE)
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


func test_start_level_resolves_default_limit_as_waves_times_seconds_per_wave() -> void:
	level_manager.start_level()

	assert_eq(GameManager.level_time_limit, 120.0)
	assert_eq(GameManager.time_remaining, 120.0)


func test_per_level_time_override_applies_only_to_that_level() -> void:
	ProjectSettings.set_setting(GameConfig.LEVEL_TIME_LIMIT_BY_LEVEL_SETTING, {2: 45.0})

	level_manager.start_level()
	assert_eq(GameManager.level_time_limit, 120.0)

	level_manager.on_all_waves_complete()
	assert_eq(level_manager.current_level, 2)
	assert_eq(GameManager.level_time_limit, 45.0)


func test_start_level_resets_lives_to_configured_value() -> void:
	level_manager.start_level()
	GameManager.take_damage(2)
	assert_eq(GameManager.lives, 1)

	level_manager.on_all_waves_complete()

	assert_eq(GameManager.lives, GameConfig.get_starting_lives())


## -- Phase 7: restart path -------------------------------------------------

func test_reset_and_start_returns_to_level_1_difficulty_and_base_sequence() -> void:
	_advance_to_level(4)
	assert_eq(level_manager.current_level, 4)
	assert_eq(level_manager.difficulty, 4)

	level_manager.reset_and_start()

	assert_eq(level_manager.current_level, 1)
	assert_eq(level_manager.difficulty, 1)
	assert_eq(level_manager.effective_tries_per_question, GameConfig.get_tries_per_question(1))
	var sequence_calls := wave_stub.calls_for("set_category_sequence")
	assert_eq(sequence_calls.back().args[0], BASE_SEQUENCE)
	assert_eq(wave_stub.calls_for("start_first_wave").back().args[0], 1)


func test_reset_and_start_reenables_level_advancement() -> void:
	level_manager.on_all_waves_complete()
	assert_eq(level_manager.current_level, 2)

	level_manager.reset_and_start()
	level_manager.on_all_waves_complete()

	assert_eq(level_manager.current_level, 2)


func test_reset_and_start_restores_level_1_timer_budget() -> void:
	ProjectSettings.set_setting(GameConfig.LEVEL_TIME_LIMIT_BY_LEVEL_SETTING, {3: 33.0})
	_advance_to_level(3)
	assert_eq(GameManager.level_time_limit, 33.0)

	level_manager.reset_and_start()

	assert_eq(GameManager.level_time_limit, 120.0)
	assert_eq(GameManager.time_remaining, 120.0)


func test_reset_and_start_resets_lives_like_a_fresh_session() -> void:
	_advance_to_level(2)
	GameManager.take_damage(2)

	level_manager.reset_and_start()

	assert_eq(GameManager.lives, GameConfig.get_starting_lives())
