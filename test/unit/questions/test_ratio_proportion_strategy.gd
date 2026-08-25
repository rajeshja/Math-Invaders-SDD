## RatioProportionStrategy tests (Phase 16 FR16.2/FR16.3): internal
## consistency of every form, exact ground truth, unique positive integer
## choices, and tier distribution checks.
extends GutTest

const RatioProportionStrategyScript = preload(
		"res://scripts/questions/strategies/ratio_proportion_strategy.gd")

var strategy = null


func before_each() -> void:
	strategy = RatioProportionStrategyScript.new()


func _parse_question_text(text: String) -> Dictionary:
	# Extract every integer token from the question text.
	var tokens: Array = []
	var current := ""
	for character in text:
		if character >= "0" and character <= "9":
			current += character
		else:
			if not current.is_empty():
				tokens.append(int(current))
				current = ""
	if not current.is_empty():
		tokens.append(int(current))
	return {"tokens": tokens, "text": text}


func test_choices_are_unique_positive_integers_with_one_correct() -> void:
	for tier in range(1, 5):
		for i in range(50):
			var question: Dictionary = strategy.generate(tier, {})
			var choices: Array = question.choices
			assert_eq(choices.size(), 4, "always four choices")
			var seen := {}
			for choice in choices:
				assert_gt(choice, 0, "all choices positive")
				assert_false(seen.has(choice), "no duplicate choices")
				seen[choice] = true
			assert_true(seen.has(question.correct_answer),
					"correct answer is among the choices")


## FR16.3: the marked-correct value solves its own stated problem.
func test_proportion_form_ground_truth() -> void:
	for i in range(60):
		var question: Dictionary = strategy.generate(1, {})
		if not question.question_text.contains("missing"):
			continue
		var tokens: Array = _parse_question_text(question.question_text).tokens
		# "If a : b = c : ? ..." -> tokens[0..2] = a, b, c.
		var a: int = tokens[0]
		var b: int = tokens[1]
		var c: int = tokens[2]
		assert_eq(c % a, 0, "proportion built with an integer scale factor")
		var scale: int = c / a
		assert_eq(question.correct_answer, b * scale,
				"missing term = b x scale factor")


func test_two_part_sharing_consistency() -> void:
	for i in range(60):
		var question: Dictionary = strategy.generate(2, {})
		assert_string_contains(question.question_text, "larger share",
				"question states what to find")
		var body: String = question.question_text.trim_prefix("Share ")
		var total: int = int(body.substr(0, body.find(" ")))
		var ratio_part := body.substr(body.find("ratio ") + 6)
		var first: int = int(ratio_part.split(" : ")[0])
		var second: int = int(ratio_part.split(" : ")[1])
		# FR16.2: totals always exactly divisible by the part sum.
		assert_eq(total % (first + second), 0,
				"total divisible by part sum (%s)" % question.question_text)
		var unit: int = total / (first + second)
		assert_eq(question.correct_answer, maxi(first, second) * unit,
				"correct answer is the larger share")


func test_three_part_sharing_names_largest_or_smallest() -> void:
	for i in range(80):
		var question: Dictionary = strategy.generate(3, {})
		var wants_largest: bool = question.question_text.contains("largest")
		var wants_smallest: bool = question.question_text.contains("smallest")
		assert_true(wants_largest != wants_smallest,
				"exactly one target named (%s)" % question.question_text)
		var body: String = question.question_text.trim_prefix("Share ")
		var total: int = int(body.substr(0, body.find(" ")))
		var ratio_text := body.substr(body.find("ratio ") + 6)
		ratio_text = ratio_text.substr(0, ratio_text.find(". What"))
		var terms: Array = []
		for term in ratio_text.split(" : "):
			terms.append(int(term))
		var unit: int = total / (terms[0] + terms[1] + terms[2])
		var expected: int = (terms.max() if wants_largest else terms.min()) * unit
		assert_eq(question.correct_answer, expected,
				"named share computed correctly")


func test_unit_rate_form_ground_truth() -> void:
	for i in range(60):
		var question: Dictionary = strategy.generate(4, {})
		assert_string_contains(question.question_text, "items cost",
				"unit-rate phrasing present")
		var tokens: Array = _parse_question_text(question.question_text).tokens
		var given_count: int = tokens[0]
		var given_total: int = tokens[1]
		var wanted_count: int = tokens[2]
		assert_eq(given_total % given_count, 0, "clean integer rate by construction")
		var rate: int = given_total / given_count
		assert_eq(question.correct_answer, wanted_count * rate,
				"unit-rate scaling exact")


func test_higher_tiers_reach_bigger_magnitudes_than_tier_one() -> void:
	var tier_one_max := 0
	var high_tier_max := 0
	for i in range(60):
		tier_one_max = maxi(tier_one_max,
				int(strategy.generate(1, {}).correct_answer))
		high_tier_max = maxi(high_tier_max,
				int(strategy.generate(4, {}).correct_answer))
	assert_gt(high_tier_max, tier_one_max,
			"Tier 4+ answers reach larger magnitudes than Tier 1")


func test_max_operand_pins_magnitudes() -> void:
	for i in range(40):
		var question: Dictionary = strategy.generate(10, {"max_operand": 12})
		for choice in question.choices:
			assert_lte(choice, 200,
					"pinned magnitudes keep answers bounded")
