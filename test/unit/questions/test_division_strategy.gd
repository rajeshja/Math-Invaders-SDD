extends GutTest

var strategy: DivisionStrategy


func before_each() -> void:
	strategy = DivisionStrategy.new()


func test_correct_answer_is_always_a_whole_number() -> void:
	for i in range(50):
		var result: Dictionary = strategy.generate(1)
		var text: String = result["question_text"]
		var parts: PackedStringArray = text.trim_prefix("What is ").trim_suffix("?").split(" / ")
		var dividend: int = int(parts[0])
		var divisor: int = int(parts[1])
		assert_eq(dividend % divisor, 0, "dividend must always be evenly divisible by divisor (divisor/quotient-first construction)")
		assert_eq(result["correct_answer"], dividend / divisor, "correct_answer should equal the actual quotient")


func test_choices_contains_exactly_one_correct_answer_among_four_unique() -> void:
	var result: Dictionary = strategy.generate(1)
	var choices: Array = result["choices"]
	var correct: int = result["correct_answer"]
	assert_eq(choices.size(), 4, "choices should have exactly 4 entries")
	var correct_count: int = 0
	var unique := {}
	for c in choices:
		unique[c] = true
		if c == correct:
			correct_count += 1
	assert_eq(correct_count, 1, "exactly one choice should equal correct_answer")
	assert_eq(unique.size(), 4, "no duplicate distractors")


func test_difficulty_scaling_sanity() -> void:
	var low_max: int = 0
	var high_max: int = 0
	for i in range(50):
		low_max = max(low_max, strategy.generate(1)["correct_answer"])
		high_max = max(high_max, strategy.generate(5)["correct_answer"])
	assert_gt(high_max, low_max, "higher difficulty should be able to produce larger quotients than low difficulty")
