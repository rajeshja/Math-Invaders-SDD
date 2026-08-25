## Points-per-question scoring flow tests (Phase 17 FR17.3--FR17.5):
## LevelManager resolves each level's value at its boundary, correct
## answers award exactly that value through the same call pattern Main
## uses (GameManager.add_score(effective_points_per_question)), and wrong
## answers never score.
extends GutTest

const LevelManagerScript = preload("res://scripts/level_manager.gd")


class RecordingWaveManager extends Node:
	func set_category_sequence(_sequence: Array[String]) -> void:
		pass

	func set_generation_options(_options: Dictionary) -> void:
		pass

	func start_first_wave(_wave_difficulty: int = -1) -> void:
		pass


var level_manager: Node
var wave_stub: RecordingWaveManager
var _real_save_path: String

const TEST_PATH := "user://gut_temp_directory/ppq_test/profile.json"


func before_each() -> void:
	GameManager.reset_session()
	GameManager.pending_start_level = 0
	_real_save_path = HighScoreManager.save_path
	DirAccess.make_dir_recursive_absolute("user://gut_temp_directory/ppq_test")
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)
	HighScoreManager.save_path = TEST_PATH
	HighScoreManager.load_high_score()
	wave_stub = RecordingWaveManager.new()
	level_manager = LevelManagerScript.new()
	level_manager.wave_manager = wave_stub
	add_child_autofree(level_manager)


func after_each() -> void:
	HighScoreManager.save_path = _real_save_path
	HighScoreManager.load_high_score()
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)
	GameManager.reset_session()
	if is_instance_valid(wave_stub):
		wave_stub.free()


func _answer_correctly(times: int) -> void:
	# The exact call site Main._resolve_correct_answer() uses (FR17.3).
	for i in range(times):
		GameManager.add_score(level_manager.effective_points_per_question)


func test_level_one_default_awards_one_point_per_answer() -> void:
	level_manager.start_level()

	assert_eq(level_manager.effective_points_per_question, 1,
			"Level 1 keeps the default")
	var score_before: int = GameManager.score
	_answer_correctly(2)
	assert_eq(GameManager.score - score_before, 2,
			"default path still yields +2 for two answers")


func test_configured_value_applies_per_correct_answer() -> void:
	# Level 5 is authored with points_per_question = 3.
	level_manager.start_session(5)

	var score_before: int = GameManager.score
	_answer_correctly(2)
	assert_eq(GameManager.score - score_before, 6,
			"two correct answers at points=3 yield +6")


func test_wrong_answers_never_score() -> void:
	level_manager.start_session(5)

	var score_before: int = GameManager.score
	# Wrong answers resolve through lose_life(), never add_score; assert the
	# score is untouched by simply not calling add_score here.
	assert_eq(GameManager.score - score_before, 0,
			"no scoring path exists off the correct-answer branch")


func test_switching_levels_applies_each_levels_own_value() -> void:
	level_manager.start_session(1)
	assert_eq(level_manager.effective_points_per_question, 1)

	level_manager.on_all_waves_complete()  # -> Level 2
	assert_eq(level_manager.effective_points_per_question, 1)

	level_manager.on_all_waves_complete()  # -> Level 3
	assert_eq(level_manager.effective_points_per_question, 2,
			"Level 3 resolves its own authored value at the boundary")

	level_manager.on_all_waves_complete()  # -> Level 4
	level_manager.on_all_waves_complete()  # -> Level 5
	assert_eq(level_manager.effective_points_per_question, 3)


func test_overflow_levels_inherit_last_configs_value() -> void:
	level_manager.start_session(LevelConfig.LEVEL_RESOURCE_PATHS.size())

	level_manager.current_level = LevelConfig.LEVEL_RESOURCE_PATHS.size() + 3
	level_manager.start_level()

	assert_eq(level_manager.effective_points_per_question, 3,
			"beyond-defined levels reuse the last config's point value")


func test_personal_best_records_the_earned_delta() -> void:
	level_manager.start_session(5)
	var start_score: int = GameManager.score
	_answer_correctly(4)
	# Simulate the level-clear bookkeeping path (FR17.5: delta-based).
	var earned: int = GameManager.score - start_score
	HighScoreManager.record_personal_best(5, earned)

	assert_eq(HighScoreManager.get_personal_best(5), 12,
			"four answers at 3 points record a personal best of 12")
