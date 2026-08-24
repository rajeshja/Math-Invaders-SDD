extends GutTest

const QuestionAttemptTrackerScript = preload("res://scripts/question_attempt_tracker.gd")


func test_default_one_attempt_retires_question_after_first_wrong_answer() -> void:
	var tracker = QuestionAttemptTrackerScript.new()
	tracker.configure(1)

	assert_true(tracker.record_wrong_attempt())
	assert_eq(tracker.attempts_used, 1)


func test_multi_attempt_keeps_question_until_limit_is_reached() -> void:
	var tracker = QuestionAttemptTrackerScript.new()
	tracker.configure(2)

	assert_false(tracker.record_wrong_attempt(), "first wrong answer should keep a two-attempt question active")
	assert_true(tracker.record_wrong_attempt(), "second wrong answer should exhaust a two-attempt question")
	assert_eq(tracker.attempts_used, 2)


func test_reset_question_clears_attempt_counter() -> void:
	var tracker = QuestionAttemptTrackerScript.new()
	tracker.configure(3)
	tracker.record_wrong_attempt()

	tracker.reset_question()

	assert_eq(tracker.attempts_used, 0)


func test_configure_clamps_attempt_limit_to_minimum_one() -> void:
	var tracker = QuestionAttemptTrackerScript.new()
	tracker.configure(0)

	assert_eq(tracker.attempt_limit, 1)
	assert_true(tracker.record_wrong_attempt())
