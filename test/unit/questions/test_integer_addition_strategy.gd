extends GutTest

var strategy: IntegerAdditionStrategy


func before_each() -> void:
	strategy = IntegerAdditionStrategy.new()


func test_question_text_matches_operands_and_correct_answer() -> void:
	var result: Dictionary = strategy.generate(1)
	var text: String = result["question_text"]
	var parts: PackedStringArray = text.trim_prefix("What is ").trim_suffix("?").split(" + ")
	assert_eq(parts.size(), 2, "question_text should contain two operands separated by ' + '")
	var a: int = int(parts[0])
	var b: int = int(parts[1])
	assert_eq(result["correct_answer"], a + b, "correct_answer should equal the actual sum of the operands used")


func test_choices_contains_exactly_one_correct_answer() -> void:
	var result: Dictionary = strategy.generate(1)
	var choices: Array = result["choices"]
	var correct: int = result["correct_answer"]
	var correct_count: int = 0
	for c in choices:
		if c == correct:
			correct_count += 1
	assert_eq(correct_count, 1, "exactly one choice should equal correct_answer")


func test_choices_has_four_unique_entries() -> void:
	var result: Dictionary = strategy.generate(1)
	var choices: Array = result["choices"]
	assert_eq(choices.size(), 4, "choices should have exactly 4 entries")
	var unique := {}
	for c in choices:
		unique[c] = true
	assert_eq(unique.size(), 4, "no duplicate distractors, and no distractor equal to the correct answer")


func test_operand_size_scales_with_difficulty() -> void:
	var low_max: int = 0
	var high_max: int = 0
	for i in range(50):
		low_max = max(low_max, strategy.generate(1)["correct_answer"])
		high_max = max(high_max, strategy.generate(5)["correct_answer"])
	assert_gt(high_max, low_max, "higher difficulty should be able to produce larger sums than low difficulty")
