## MistakeTracker tests (Phase 9 FR9.15): session mistake log capped at
## the LAST 100 mistakes, oldest dropped first.
extends GutTest

const MistakeTrackerScript = preload("res://scripts/mistake_tracker.gd")

var tracker: RefCounted


func before_each() -> void:
	tracker = MistakeTrackerScript.new()


func test_add_mistake_stores_question_selected_and_correct() -> void:
	tracker.add_mistake({"question_text": "What is 2 + 3?", "correct_answer": 5}, 4, 5)

	var mistakes: Array[Dictionary] = tracker.get_mistakes()
	assert_eq(mistakes.size(), 1)
	assert_eq(mistakes[0].get("question_text"), "What is 2 + 3?")
	assert_eq(mistakes[0].get("selected_answer"), 4)
	assert_eq(mistakes[0].get("correct_answer"), 5)


func test_log_is_capped_at_one_hundred_entries() -> void:
	for i in range(150):
		tracker.add_mistake({"question_text": "Q%d" % i}, i, i + 1)

	assert_eq(tracker.mistake_count(), MistakeTrackerScript.MAX_MISTAKES)
	assert_eq(MistakeTrackerScript.MAX_MISTAKES, 100, "FR9.15 documents the cap")


func test_cap_drops_the_oldest_mistakes_first() -> void:
	for i in range(105):
		tracker.add_mistake({"question_text": "Q%d" % i}, i, i)

	var mistakes: Array[Dictionary] = tracker.get_mistakes()

	assert_eq(str(mistakes[0].get("question_text")), "Q5", "first five were evicted")
	assert_eq(str(mistakes.back().get("question_text")), "Q104")


func test_clear_empties_the_log_for_a_fresh_session() -> void:
	tracker.add_mistake({"question_text": "What is 1 + 1?"}, 3, 2)
	tracker.clear()

	assert_eq(tracker.mistake_count(), 0)


func test_get_mistakes_returns_a_copy_not_the_live_array() -> void:
	tracker.add_mistake({"question_text": "Q"}, 1, 2)
	var copy: Array[Dictionary] = tracker.get_mistakes()
	copy.clear()

	assert_eq(tracker.mistake_count(), 1, "callers cannot mutate the internal log")
