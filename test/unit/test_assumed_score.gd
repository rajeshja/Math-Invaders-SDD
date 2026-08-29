## Assumed Full Score tests (Phase 9 Testing Plan: starting at a higher
## level initializes GameManager.score with the sum of personal bests of
## skipped levels - and does so BEFORE the first question appears).
extends GutTest

const LevelManagerScript = preload("res://scripts/level_manager.gd")

const TEST_DIR := "user://gut_temp_directory/assumed_score_test"
const TEST_PATH := "user://gut_temp_directory/assumed_score_test/profile.json"


class RecordingWaveManager extends Node:
	var first_wave_score: int = -1

	func set_category_sequence(_sequence: Array[String]) -> void:
		pass

	func set_generation_options(_options: Dictionary) -> void:
		pass

	# Captured at wave-spawn time: the assumed score must already be in
	# place before any question is shown (FR9.8).
	func start_first_wave(_wave_difficulty: int = -1) -> void:
		first_wave_score = GameManager.score


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


func test_reset_session_seeds_the_given_starting_score() -> void:
	var emitted: Array[int] = []
	GameManager.score_changed.connect(func(score: int): emitted.append(score))

	GameManager.reset_session(65)

	assert_eq(GameManager.score, 65)
	assert_eq(emitted, [65], "FR9.8: HUD wiring receives the assumed score")


func test_reset_session_clamps_negative_starting_scores_to_zero() -> void:
	GameManager.reset_session(-10)

	assert_eq(GameManager.score, 0)


func test_fresh_level_one_session_starts_at_zero() -> void:
	level_manager.start_session(1)

	assert_eq(GameManager.score, 0)
	assert_eq(wave_stub.first_wave_score, 0)


func test_starting_at_level_three_injects_sum_of_skipped_personal_bests() -> void:
	HighScoreManager.record_personal_best(1, 30)
	HighScoreManager.record_personal_best(2, 40)

	level_manager.start_session(3)

	assert_eq(GameManager.score, 70, "FR9.7: skipped levels count as fully cleared")
	assert_eq(wave_stub.first_wave_score, 70,
		"FR9.8: score initialized before the first question")


func test_missing_personal_bests_contribute_zero_not_an_error() -> void:
	HighScoreManager.record_personal_best(2, 40)

	level_manager.start_session(3)

	assert_eq(GameManager.score, 40)


func test_lower_replays_do_not_reduce_a_level_personal_best() -> void:
	HighScoreManager.record_personal_best(1, 50)

	HighScoreManager.record_personal_best(1, 20)

	assert_eq(HighScoreManager.get_personal_best(1), 50,
		"assumed scores must reflect the BEST run of each skipped level")


## -- Phase 22: per-player assumed scores (FR22.3) -----------------------------

func test_assumed_score_uses_the_active_players_bests_only() -> void:
	HighScoreManager.set_active_player_name("A")
	HighScoreManager.record_personal_best(1, 30)
	HighScoreManager.record_personal_best(2, 40)

	HighScoreManager.set_active_player_name("B")
	level_manager.start_session(3)
	assert_eq(GameManager.score, 0, "B's session ignores A's bests")

	HighScoreManager.set_active_player_name("A")
	level_manager.start_session(3)
	assert_eq(GameManager.score, 70, "A's session sums A's bests")


func test_player_with_no_bests_starts_at_zero_despite_anothers_bests() -> void:
	HighScoreManager.set_active_player_name("A")
	HighScoreManager.record_personal_best(1, 30)
	HighScoreManager.record_personal_best(2, 40)

	HighScoreManager.set_active_player_name("B")
	level_manager.start_session(3)

	assert_eq(GameManager.score, 0)
	assert_eq(wave_stub.first_wave_score, 0,
		"FR9.8: score initialized before the first question")
