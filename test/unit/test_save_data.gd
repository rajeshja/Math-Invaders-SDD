## Profile persistence tests (Phase 9 Testing Plan: the new JSON schema
## saves and loads correctly without destroying legacy Phase 7 save data;
## Phase 22: per-player profiles persist independently and legacy flat
## files migrate into the stored name's profile).
##
## Every test redirects save_path into a throwaway directory so the real
## user://highscore.json is never read or written (NFR7.1).
extends GutTest

const HighScoreManagerScript = preload("res://scripts/high_score_manager.gd")

const REAL_SAVE_PATH := "user://highscore.json"
const TEST_DIR := "user://gut_temp_directory/save_data_test"
const TEST_PATH := "user://gut_temp_directory/save_data_test/profile.json"

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


func _read_saved_json() -> Dictionary:
	var file := FileAccess.open(TEST_PATH, FileAccess.READ)
	var json := JSON.new()
	json.parse(file.get_as_text())
	file.close()
	return json.data


func _fresh_reload() -> Node:
	var reloaded: Node = HighScoreManagerScript.new()
	reloaded.save_path = TEST_PATH
	reloaded.load_high_score()
	autofree(reloaded)
	return reloaded


## -- Defaults -----------------------------------------------------------------

func test_missing_profile_falls_back_to_safe_defaults() -> void:
	manager.load_high_score()

	assert_eq(manager.get_high_score(), 0)
	assert_eq(manager.get_player_name(), "")
	assert_eq(manager.get_unlocked_level(), 1)
	assert_eq(manager.get_personal_best(1), 0)
	assert_eq(manager.get_flawless_streak(1), 0)


func test_malformed_json_content_falls_back_to_defaults_gracefully() -> void:
	_write_raw_save_file("this is not json {")

	manager.load_high_score()

	assert_eq(manager.get_high_score(), 0)
	assert_eq(manager.get_unlocked_level(), 1)


func test_non_dictionary_json_content_falls_back_to_defaults_gracefully() -> void:
	_write_raw_save_file("[1, 2, 3]")

	manager.load_high_score()

	assert_eq(manager.get_high_score(), 0)
	assert_eq(manager.get_unlocked_level(), 1)


## -- Legacy migration (Phase 7/9 flat schema) ---------------------------------

func test_legacy_phase7_schema_migrates_without_losing_the_high_score() -> void:
	_write_raw_save_file(JSON.stringify({"high_score": 123}))

	manager.load_high_score()

	assert_eq(manager.get_high_score(), 123, "legacy value survives")
	assert_eq(manager.get_unlocked_level(), 1)
	assert_eq(manager.get_personal_best(1), 0)
	assert_eq(manager.get_flawless_streak(1), 0)


func test_legacy_schema_is_upgraded_in_place_on_next_write() -> void:
	_write_raw_save_file(JSON.stringify({"high_score": 123}))
	manager.load_high_score()
	manager.record_personal_best(2, 40)

	var reloaded := _fresh_reload()

	assert_eq(reloaded.get_high_score(), 123, "old data preserved through migration")
	assert_eq(reloaded.get_personal_best(2), 40)


func test_legacy_flat_schema_migrates_into_the_stored_names_profile() -> void:
	_write_raw_save_file(JSON.stringify({
		"high_score": 123,
		"player_name": "Raju",
		"unlocked_level": 3,
		"personal_bests": {"1": 30, "2": 44},
		"flawless_streaks": {"2": 2},
	}))

	manager.load_high_score()

	assert_eq(manager.get_high_score(), 123, "high score survives migration")
	assert_eq(manager.get_player_name(), "Raju")
	assert_eq(manager.get_unlocked_level(), 3, "progression wrapped under Raju")
	assert_eq(manager.get_personal_best(1), 30)
	assert_eq(manager.get_personal_best(2), 44)
	assert_eq(manager.get_flawless_streak(2), 2)

	manager.set_active_player_name("SomeoneElse")
	assert_eq(manager.get_unlocked_level(), 1,
		"a different name never sees Raju's progression")
	assert_eq(manager.get_personal_best(1), 0)


## -- New schema round-trip -------------------------------------------------------

func test_full_new_schema_round_trips_through_a_fresh_instance() -> void:
	manager.set_player_name("Raju")
	manager.save_if_higher(500)
	manager.record_personal_best(1, 30)
	manager.record_personal_best(2, 44)
	manager.record_flawless_clear(2, 5)
	manager.record_flawless_clear(2, 5)
	manager.record_session_score(120)
	manager.record_session_score(80)
	manager.profiles["Raju"][HighScoreManagerScript.UNLOCKED_LEVEL_KEY] = 3
	manager._write_save_file()

	var reloaded := _fresh_reload()

	assert_eq(reloaded.get_high_score(), 500)
	assert_eq(reloaded.get_player_name(), "Raju")
	assert_eq(reloaded.get_last_player_name(), "Raju")
	assert_eq(reloaded.get_unlocked_level(), 3)
	assert_eq(reloaded.get_personal_best(1), 30)
	assert_eq(reloaded.get_personal_best(2), 44)
	assert_eq(reloaded.get_flawless_streak(2), 2,
		"int dictionary keys survive the JSON string-key round trip")
	assert_eq(reloaded.get_top_scores(), [500, 120, 80],
		"top scores survive the round trip (save_if_higher records via submit_score)")


func test_two_players_profiles_persist_independently() -> void:
	manager.set_player_name("Asha")
	manager.record_personal_best(1, 30)
	for i in range(3):
		manager.record_flawless_clear(1, 5)
	assert_eq(manager.get_unlocked_level(), 2, "Asha masters level 1")

	manager.set_player_name("Balu")
	assert_eq(manager.get_unlocked_level(), 1, "Balu starts fresh")
	assert_eq(manager.get_personal_best(1), 0)
	assert_eq(manager.get_flawless_streak(1), 0)

	var reloaded := _fresh_reload()
	reloaded.set_active_player_name("Asha")
	assert_eq(reloaded.get_unlocked_level(), 2, "Asha's unlock survives reload")
	assert_eq(reloaded.get_personal_best(1), 30)
	assert_eq(reloaded.get_flawless_streak(1), 3)
	reloaded.set_active_player_name("Balu")
	assert_eq(reloaded.get_unlocked_level(), 1, "Balu still fresh after reload")


func test_string_typed_level_keys_are_normalized_on_load() -> void:
	# Simulate hand-edited or older-tooling output using string keys.
	_write_raw_save_file(JSON.stringify({
		"high_score": 10,
		"personal_bests": {"1": 25},
		"flawless_streaks": {"2": 1},
	}))

	manager.load_high_score()

	assert_eq(manager.get_personal_best(1), 25)
	assert_eq(manager.get_flawless_streak(2), 1)


func test_corrupt_dictionary_entries_are_dropped_not_crashed_on() -> void:
	_write_raw_save_file(JSON.stringify({
		"high_score": 10,
		"personal_bests": {"1": "oops", "two": 5, "3": -4},
	}))

	manager.load_high_score()

	assert_eq(manager.get_personal_best(1), 0,
		"non-numeric and invalid entries are dropped")


func test_corrupt_profile_entries_are_dropped_not_crashed_on() -> void:
	_write_raw_save_file(JSON.stringify({
		"high_score": 10,
		"profiles": {
			"Good": {"unlocked_level": 2, "personal_bests": {"1": 25}},
			"Bad": "not a dictionary",
			"Corrupt": {"unlocked_level": "oops", "personal_bests": {"1": "nope", "two": 5, "3": -4}},
		},
	}))

	manager.load_high_score()

	assert_true(manager.profiles.has("Good"))
	assert_false(manager.profiles.has("Bad"), "non-dictionary profile dropped")

	manager.set_active_player_name("Good")
	assert_eq(manager.get_unlocked_level(), 2)
	assert_eq(manager.get_personal_best(1), 25)

	manager.set_active_player_name("Corrupt")
	assert_eq(manager.get_unlocked_level(), 1, "corrupt unlocked_level falls back to 1")
	assert_eq(manager.get_personal_best(1), 0, "corrupt bests dropped")


## -- Player name (FR9.10/FR9.11) --------------------------------------------------

func test_set_player_name_persists_and_trims() -> void:
	manager.set_player_name("  Asha  ")

	assert_eq(manager.get_last_player_name(), "Asha")
	assert_eq(_fresh_reload().get_last_player_name(), "Asha")


func test_blank_name_does_not_wipe_stored_name() -> void:
	manager.set_player_name("Asha")
	manager.set_player_name("   ")

	assert_eq(manager.get_last_player_name(), "Asha")


func test_previewing_names_does_not_create_profiles() -> void:
	manager.set_active_player_name("M")
	manager.get_unlocked_level()
	manager.set_active_player_name("Mo")
	manager.get_unlocked_level()
	manager.set_active_player_name("Moh")
	manager.get_unlocked_level()

	assert_true(manager.profiles.is_empty(),
		"previewing partial names must not create profiles")

	manager.set_player_name("Mohan")
	assert_true(manager.profiles.has("Mohan"),
		"starting play creates the committed profile")
	assert_false(manager.profiles.has("M"))
	assert_false(manager.profiles.has("Mo"))
	assert_false(manager.profiles.has("Moh"))


## -- Best scores per profile (FR22.6) ---------------------------------------------

func test_top_three_scores_are_recorded_and_capped() -> void:
	manager.set_player_name("Asha")
	manager.record_session_score(100)
	manager.record_session_score(300)
	manager.record_session_score(200)
	manager.record_session_score(400)

	assert_eq(manager.get_top_scores(), [400, 300, 200],
		"only the best three, sorted descending")

	var reloaded := _fresh_reload()
	assert_eq(reloaded.get_top_scores(), [400, 300, 200],
		"top scores persist across reload")


func test_top_scores_are_per_player() -> void:
	manager.set_player_name("Asha")
	manager.record_session_score(100)
	manager.set_player_name("Balu")
	manager.record_session_score(50)

	assert_eq(manager.get_top_scores(), [50])
	manager.set_active_player_name("Asha")
	assert_eq(manager.get_top_scores(), [100])


func test_zero_scores_are_not_recorded_as_best_scores() -> void:
	manager.set_player_name("Asha")
	manager.record_session_score(0)
	manager.record_session_score(-5)

	assert_true(manager.get_top_scores().is_empty())


func test_corrupt_top_scores_are_dropped_not_crashed_on() -> void:
	_write_raw_save_file(JSON.stringify({
		"high_score": 10,
		"profiles": {
			"Good": {"top_scores": [50, "oops", -3, 20, 100, 70]},
		},
	}))

	manager.load_high_score()
	manager.set_active_player_name("Good")

	assert_eq(manager.get_top_scores(), [100, 70, 50],
		"non-numeric and negative entries dropped, capped at 3")


## -- Personal bests (FR9.5/FR9.7) --------------------------------------------------

func test_personal_best_only_updates_when_strictly_higher() -> void:
	assert_true(manager.record_personal_best(1, 20))
	assert_false(manager.record_personal_best(1, 20))
	assert_false(manager.record_personal_best(1, 10))
	assert_eq(manager.get_personal_best(1), 20)


func test_negative_or_invalid_levels_and_scores_are_rejected() -> void:
	assert_false(manager.record_personal_best(0, 50))
	assert_false(manager.record_personal_best(1, -3))

	assert_eq(manager.get_personal_best(0), 0)
	assert_eq(manager.get_personal_best(1), 0)


## -- Assumed full score (FR9.7/FR9.8) -----------------------------------------------

func test_assumed_score_sums_personal_bests_below_start_level() -> void:
	manager.record_personal_best(1, 30)
	manager.record_personal_best(2, 40)

	assert_eq(manager.get_assumed_score_for_level(3), 70)
	assert_eq(manager.get_assumed_score_for_level(2), 30)


func test_assumed_score_is_zero_for_level_one_or_missing_bests() -> void:
	manager.record_personal_best(2, 40)

	assert_eq(manager.get_assumed_score_for_level(1), 0)
	assert_eq(manager.get_assumed_score_for_level(2), 0)


## Cross-cutting regression guard: this suite must leave the real save
## file exactly as it was found.
func test_real_save_file_is_untouched_by_this_suite() -> void:
	var existed_before := FileAccess.file_exists(REAL_SAVE_PATH)

	manager.save_if_higher(99999)
	manager.record_personal_best(1, 42)
	assert_eq(manager.save_path, TEST_PATH)

	assert_eq(FileAccess.file_exists(REAL_SAVE_PATH), existed_before)


## -- Phase 23: profile fields & leaderboard persistence --------------------------

func test_record_count_and_highest_level_persist_per_player() -> void:
	manager.set_player_name("Asha")
	manager.submit_score(500)
	manager.record_highest_level_reached(4)
	manager.set_player_name("Balu")
	manager.record_highest_level_reached(2)

	var reloaded := _fresh_reload()
	reloaded.set_active_player_name("Asha")
	assert_eq(reloaded.get_record_count(), 1, "Asha's record count survives reload")
	assert_eq(reloaded.get_highest_level_reached(), 4, "Asha's highest level survives")
	reloaded.set_active_player_name("Balu")
	assert_eq(reloaded.get_record_count(), 0, "Balu's record count is separate")
	assert_eq(reloaded.get_highest_level_reached(), 2)


func test_leaderboard_persists_device_wide_and_shared_across_profiles() -> void:
	manager.set_player_name("Asha")
	manager.submit_score(500)
	manager.set_player_name("Balu")
	manager.submit_score(300)

	var reloaded := _fresh_reload()
	assert_eq(reloaded.get_leaderboard(), [
		{"name": "Asha", "score": 500},
		{"name": "Balu", "score": 300},
	], "the device-wide leaderboard survives reload and is shared")


func test_corrupt_new_profile_fields_fall_back_safely() -> void:
	_write_raw_save_file(JSON.stringify({
		"high_score": 10,
		"profiles": {
			"Good": {"record_count": 3, "highest_level_reached": 5},
			"Bad": {"record_count": "oops", "highest_level_reached": -2},
		},
	}))

	manager.load_high_score()
	manager.set_active_player_name("Good")
	assert_eq(manager.get_record_count(), 3)
	assert_eq(manager.get_highest_level_reached(), 5)

	manager.set_active_player_name("Bad")
	assert_eq(manager.get_record_count(), 0, "non-numeric record_count falls back")
	assert_eq(manager.get_highest_level_reached(), 1, "invalid highest level falls back")
