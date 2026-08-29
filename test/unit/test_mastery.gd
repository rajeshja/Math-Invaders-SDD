## Mastery & sequential unlocking tests (Phase 9 Testing Plan).
##
## Simulates flawless level clears through a real LevelManager + real
## (redirected) HighScoreManager: three flawless clears in a row must
## unlock the next level, and taking damage during a level must reset that
## level's streak counter. WaveManager is a recording double; no real
## enemies are spawned.
extends GutTest

const LevelManagerScript = preload("res://scripts/level_manager.gd")
const HighScoreManagerScript = preload("res://scripts/high_score_manager.gd")

const TEST_DIR := "user://gut_temp_directory/mastery_test"
const TEST_PATH := "user://gut_temp_directory/mastery_test/profile.json"


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


func test_unlocked_level_defaults_to_one() -> void:
	assert_eq(HighScoreManager.get_unlocked_level(), 1)


func test_two_flawless_clears_do_not_unlock_the_next_level() -> void:
	for i in range(2):
		level_manager.start_session(1)
		level_manager.on_all_waves_complete()

	assert_eq(HighScoreManager.get_flawless_streak(1), 2)
	assert_eq(HighScoreManager.get_unlocked_level(), 1, "mastery needs 3 in a row")


func test_third_flawless_clear_masters_level_and_unlocks_next_sequentially() -> void:
	for i in range(3):
		level_manager.start_session(1)
		level_manager.on_all_waves_complete()

	assert_eq(HighScoreManager.get_unlocked_level(), 2)
	assert_true(FileAccess.file_exists(TEST_PATH), "unlock is persisted")

	var reloaded: Node = HighScoreManagerScript.new()
	reloaded.save_path = TEST_PATH
	reloaded.load_high_score()
	autofree(reloaded)
	assert_eq(reloaded.get_unlocked_level(), 2)


func test_damage_during_a_level_breaks_the_streak_chain() -> void:
	level_manager.start_session(1)
	GameManager.take_damage(1)
	assert_eq(HighScoreManager.get_flawless_streak(1), 0,
		"FR9.3: taking damage resets the streak counter immediately")
	level_manager.on_all_waves_complete()

	assert_eq(HighScoreManager.get_flawless_streak(1), 0,
		"a damaged clear is not flawless")

	level_manager.start_session(1)
	level_manager.on_all_waves_complete()
	assert_eq(HighScoreManager.get_flawless_streak(1), 1,
		"streak restarts from zero after the damaged clear")
	assert_eq(HighScoreManager.get_unlocked_level(), 1)


func test_streaks_are_tracked_per_level_independently() -> void:
	HighScoreManager.unlocked_level = 5
	level_manager.start_session(4)
	GameManager.take_damage(1)
	level_manager.on_all_waves_complete()

	level_manager.start_session(5)
	level_manager.on_all_waves_complete()
	level_manager.start_session(5)
	level_manager.on_all_waves_complete()

	assert_eq(HighScoreManager.get_flawless_streak(4), 0)
	assert_eq(HighScoreManager.get_flawless_streak(5), 2)


func test_unlocking_is_capped_by_the_defined_level_pool() -> void:
	var last_level: int = LevelConfig.total_level_count()
	HighScoreManager.unlocked_level = last_level
	level_manager.session_start_level = last_level

	for i in range(3):
		level_manager.current_level = last_level
		level_manager._record_level_result()

	assert_eq(HighScoreManager.get_unlocked_level(), last_level,
		"no unlock beyond the defined levels")


func test_record_flawless_clear_reports_only_the_unlocking_call() -> void:
	assert_false(HighScoreManager.record_flawless_clear(1, 5))
	assert_false(HighScoreManager.record_flawless_clear(1, 5))
	assert_true(HighScoreManager.record_flawless_clear(1, 5),
		"the third consecutive clear performs the unlock")


func test_mastering_a_locked_level_does_not_skip_ahead() -> void:
	# unlocked_level defaults to 1; a stray flawless clear on level 2 must
	# not unlock level 3 while level 2 itself is still locked (FR9.4).
	for i in range(3):
		HighScoreManager.record_flawless_clear(2, 5)

	assert_eq(HighScoreManager.get_flawless_streak(2), 3)
	assert_eq(HighScoreManager.get_unlocked_level(), 1,
		"level 2 must be unlocked before level 3 can be")


func test_unlocking_proceeds_one_level_at_a_time() -> void:
	# Master level 1 -> unlock 2; master level 2 -> unlock 3. The frontier
	# advances exactly one level per mastered level (FR9.4).
	for i in range(3):
		HighScoreManager.record_flawless_clear(1, 5)
	assert_eq(HighScoreManager.get_unlocked_level(), 2)

	for i in range(3):
		HighScoreManager.record_flawless_clear(2, 5)
	assert_eq(HighScoreManager.get_unlocked_level(), 3)


func test_personal_best_is_recorded_from_earned_level_score_on_clear() -> void:
	level_manager.start_session(1)
	GameManager.add_score(7)

	level_manager.on_all_waves_complete()

	assert_eq(HighScoreManager.get_personal_best(1), 7)
