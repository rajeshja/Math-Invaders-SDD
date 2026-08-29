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


## -- Phase 23: device-wide leaderboard ------------------------------------------

func test_submit_score_qualifies_when_board_has_fewer_than_five_entries() -> void:
	manager.set_player_name("Asha")
	var result: Dictionary = manager.submit_score(100)

	assert_eq(result.rank, 1)
	assert_true(result.new_record)
	assert_eq(manager.get_leaderboard(), [{"name": "Asha", "score": 100}])


func test_submit_score_qualifies_when_strictly_greater_than_fifth() -> void:
	manager.set_player_name("Asha")
	for score in [100, 90, 80, 70, 60]:
		manager.submit_score(score)

	var result: Dictionary = manager.submit_score(75)

	assert_eq(result.rank, 4, "75 slots between 80 and 70")
	assert_eq(manager.get_leaderboard().size(), 5)
	assert_eq(manager.get_leaderboard()[3], {"name": "Asha", "score": 75})


func test_tie_at_the_boundary_does_not_displace_an_entry() -> void:
	manager.set_player_name("Asha")
	for score in [100, 90, 80, 70, 60]:
		manager.submit_score(score)

	var result: Dictionary = manager.submit_score(60)

	assert_eq(result.rank, 0, "a tie with the 5th entry does not qualify")
	assert_eq(manager.get_leaderboard().size(), 5)
	assert_eq(manager.get_leaderboard()[4], {"name": "Asha", "score": 60})


func test_submit_score_returns_a_copy_of_the_leaderboard() -> void:
	manager.set_player_name("Asha")
	var result: Dictionary = manager.submit_score(100)

	result.leaderboard.append({"name": "Hacker", "score": 999})

	assert_eq(manager.get_leaderboard(), [{"name": "Asha", "score": 100}],
		"mutating the returned list must not touch the stored board")


func test_leaderboard_is_capped_at_five_entries() -> void:
	manager.set_player_name("Asha")
	for score in [10, 20, 30, 40, 50, 60, 70]:
		manager.submit_score(score)

	assert_eq(manager.get_leaderboard().size(), 5)
	assert_eq(manager.get_leaderboard()[0], {"name": "Asha", "score": 70})
	assert_eq(manager.get_leaderboard()[4], {"name": "Asha", "score": 30})


func test_leaderboard_is_device_wide_and_shared_across_profiles() -> void:
	manager.set_player_name("Asha")
	manager.submit_score(500)
	manager.set_player_name("Balu")
	manager.submit_score(300)

	assert_eq(manager.get_leaderboard(), [
		{"name": "Asha", "score": 500},
		{"name": "Balu", "score": 300},
	], "both players' scores share one device-wide board")


func test_submit_score_records_session_score_into_profile_best_three() -> void:
	manager.set_player_name("Asha")
	manager.submit_score(100)
	manager.submit_score(300)
	manager.submit_score(200)
	manager.submit_score(400)

	assert_eq(manager.get_top_scores(), [400, 300, 200])


func test_submit_score_reports_beat_personal_best() -> void:
	manager.set_player_name("Asha")
	manager.submit_score(100)
	assert_false(manager.submit_score(100).beat_personal_best,
			"a tie with the previous best is not a personal best")
	assert_true(manager.submit_score(150).beat_personal_best,
			"beating the previous best is a personal best")


func test_submit_score_never_submits_non_positive_scores() -> void:
	manager.set_player_name("Asha")
	var result: Dictionary = manager.submit_score(0)

	assert_eq(result.rank, 0)
	assert_false(result.new_record)
	assert_false(result.beat_personal_best)
	assert_true(manager.get_leaderboard().is_empty())
	assert_true(manager.get_top_scores().is_empty())


func test_record_count_increments_only_on_a_new_number_one() -> void:
	manager.set_player_name("Asha")
	manager.submit_score(100)
	assert_eq(manager.get_record_count(), 1)

	manager.submit_score(50)
	assert_eq(manager.get_record_count(), 1, "a lower score never increments")

	manager.submit_score(100)
	assert_eq(manager.get_record_count(), 1, "a tie never increments")

	manager.submit_score(200)
	assert_eq(manager.get_record_count(), 2, "a new #1 increments")


func test_record_count_is_per_player() -> void:
	manager.set_player_name("Asha")
	manager.submit_score(500)
	manager.set_player_name("Balu")
	manager.submit_score(600)

	assert_eq(manager.get_record_count(), 1, "Balu's own record count")
	manager.set_active_player_name("Asha")
	assert_eq(manager.get_record_count(), 1, "Asha's record count is separate")


func test_highest_level_reached_is_monotonic_and_per_player() -> void:
	manager.set_player_name("Asha")
	manager.record_highest_level_reached(3)
	manager.record_highest_level_reached(2)
	assert_eq(manager.get_highest_level_reached(), 3, "keeps the maximum")

	manager.set_player_name("Balu")
	assert_eq(manager.get_highest_level_reached(), 1, "Balu starts at level 1")
	manager.record_highest_level_reached(5)
	assert_eq(manager.get_highest_level_reached(), 5)


func test_legacy_save_reconstructs_leaderboard_from_high_score() -> void:
	_write_raw_save_file(JSON.stringify({
		"high_score": 123,
		"player_name": "Raju",
	}))

	manager.load_high_score()

	assert_eq(manager.get_leaderboard(), [{"name": "Raju", "score": 123}],
		"NFR23.1: the leaderboard is reconstructed from high_score/player_name")
	assert_eq(manager.get_record_count(), 0, "new profile fields default safely")
	assert_eq(manager.get_highest_level_reached(), 1)


func test_leaderboard_round_trips_through_a_fresh_instance() -> void:
	manager.set_player_name("Asha")
	manager.submit_score(500)
	manager.submit_score(300)

	var reloaded: Node = HighScoreManagerScript.new()
	reloaded.save_path = TEST_PATH
	reloaded.load_high_score()

	assert_eq(reloaded.get_leaderboard(), [
		{"name": "Asha", "score": 500},
		{"name": "Asha", "score": 300},
	])
	reloaded.free()


func test_corrupt_leaderboard_entries_are_dropped_not_crashed_on() -> void:
	_write_raw_save_file(JSON.stringify({
		"high_score": 10,
		"leaderboard": [
			{"name": "Good", "score": 50},
			"not a dict",
			{"name": "Bad", "score": "oops"},
			{"name": "Neg", "score": -5},
			{"name": "Zero", "score": 0},
		],
	}))

	manager.load_high_score()

	assert_eq(manager.get_leaderboard(), [{"name": "Good", "score": 50}],
		"corrupt entries are dropped, never crashed on")
