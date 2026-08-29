## HighScoreManager unit tests (Phase 7).
##
## Every test redirects save_path into GUT's temp directory under user://
## so the real user://highscore.json is never read or written (NFR7.1).
extends GutTest

const HighScoreManagerScript = preload("res://scripts/high_score_manager.gd")

const REAL_SAVE_PATH := "user://highscore.json"
const TEST_DIR := "user://gut_temp_directory/high_score_manager_test"
const TEST_PATH := "user://gut_temp_directory/high_score_manager_test/highscore.json"

var manager: Node


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	_delete_test_file()
	manager = HighScoreManagerScript.new()
	manager.save_path = TEST_PATH


func after_each() -> void:
	_delete_test_file()
	if is_instance_valid(manager):
		manager.free()


func _delete_test_file() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)


func _write_raw_save_file(content: String) -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func test_missing_save_file_defaults_high_score_to_zero_without_error() -> void:
	manager.load_high_score()

	assert_eq(manager.get_high_score(), 0)


func test_save_if_higher_updates_and_returns_true_on_strictly_greater_score() -> void:
	assert_true(manager.save_if_higher(10))
	assert_eq(manager.get_high_score(), 10)
	assert_true(FileAccess.file_exists(TEST_PATH))


func test_save_if_higher_rejects_lower_score() -> void:
	manager.save_if_higher(10)

	assert_false(manager.save_if_higher(9))
	assert_eq(manager.get_high_score(), 10)


func test_tie_does_not_count_as_a_new_record() -> void:
	manager.save_if_higher(10)

	# NFR7.3: exactly equal must not update or report a record.
	assert_false(manager.save_if_higher(10))
	assert_eq(manager.get_high_score(), 10)


func test_negative_score_never_beats_the_default_of_zero() -> void:
	assert_false(manager.save_if_higher(-5))
	assert_eq(manager.get_high_score(), 0)


func test_saved_value_round_trips_through_a_fresh_instance() -> void:
	manager.save_if_higher(57)

	var reloaded: Node = HighScoreManagerScript.new()
	reloaded.save_path = TEST_PATH
	reloaded.load_high_score()

	assert_eq(reloaded.get_high_score(), 57)
	reloaded.free()


func test_second_higher_save_overwrites_previous_value() -> void:
	manager.save_if_higher(20)

	assert_true(manager.save_if_higher(35))

	var reloaded: Node = HighScoreManagerScript.new()
	reloaded.save_path = TEST_PATH
	reloaded.load_high_score()

	assert_eq(reloaded.get_high_score(), 35)
	reloaded.free()


func test_malformed_json_content_falls_back_to_zero_gracefully() -> void:
	_write_raw_save_file("this is not json {")

	manager.load_high_score()

	assert_eq(manager.get_high_score(), 0)


func test_non_dictionary_json_content_falls_back_to_zero_gracefully() -> void:
	_write_raw_save_file("[1, 2, 3]")

	manager.load_high_score()

	assert_eq(manager.get_high_score(), 0)


func test_dictionary_missing_key_or_wrong_type_falls_back_to_zero() -> void:
	_write_raw_save_file(JSON.stringify({"other_key": 42}))
	manager.load_high_score()
	assert_eq(manager.get_high_score(), 0)

	_write_raw_save_file(JSON.stringify({HighScoreManagerScript.HIGH_SCORE_KEY: "not a number"}))
	manager.load_high_score()
	assert_eq(manager.get_high_score(), 0)


## FR22.4: the holder name is tagged to the player who set the record and
## is never re-tagged just because a different name is entered.
func test_entering_a_new_name_never_retags_the_high_score() -> void:
	manager.set_player_name("Asha")
	manager.save_if_higher(500)
	assert_eq(manager.get_player_name(), "Asha")

	manager.set_player_name("Balu")
	assert_eq(manager.get_player_name(), "Asha",
		"entering a new name must not re-tag the high score to the new player")
	assert_eq(manager.get_high_score(), 500)

	assert_false(manager.save_if_higher(300))
	assert_eq(manager.get_player_name(), "Asha", "a lower score keeps the holder")

	assert_true(manager.save_if_higher(600))
	assert_eq(manager.get_player_name(), "Balu",
		"beating the record tags the new holder")


## Cross-cutting regression guard (Phase 7 Testing Plan): the suite above
## must leave the real save file exactly as it was found - untouched by any
## test double or fixture, confirming FR7.10 at the test level.
func test_real_save_file_is_untouched_by_this_suite() -> void:
	var existed_before := FileAccess.file_exists(REAL_SAVE_PATH)

	manager.save_if_higher(12345)
	assert_eq(manager.save_path, TEST_PATH)

	assert_eq(FileAccess.file_exists(REAL_SAVE_PATH), existed_before)
