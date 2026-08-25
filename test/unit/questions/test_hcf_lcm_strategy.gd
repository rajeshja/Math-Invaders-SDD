## HcfLcmStrategy tests (Phase 16 FR16.5/FR16.6): ground truth checked
## against an INDEPENDENT HCF/LCM implementation written here (not the
## strategy's own helpers), tier bounds, and distractor sanity.
extends GutTest

const HcfLcmStrategyScript = preload(
		"res://scripts/questions/strategies/hcf_lcm_strategy.gd")

var strategy = null


func before_each() -> void:
	strategy = HcfLcmStrategyScript.new()


## Independent reference implementation (Euclid), written from scratch.
func _ref_gcd(a: int, b: int) -> int:
	while b != 0:
		var t := b
		b = a % b
		a = t
	return a


func _ref_lcm(a: int, b: int) -> int:
	return a * b / _ref_gcd(a, b)


func _extract_numbers(text: String) -> Array:
	# Pull the operands out of "…(HCF) of 12 and 18?" / "…of 4, 6 and 8?".
	var marker := "(HCF) of " if text.contains("(HCF)") else "(LCM) of "
	var tail := text.substr(text.find(marker) + marker.length())
	tail = tail.trim_suffix("?")
	var parts := tail.replace(" and ", ", ").split(", ")
	var numbers: Array = []
	for part in parts:
		numbers.append(int(part))
	return numbers


func test_every_question_names_hcf_or_lcm_explicitly() -> void:
	for i in range(60):
		var question: Dictionary = strategy.generate(randi_range(1, 4), {})
		var asks_hcf: bool = question.question_text.contains("(HCF)")
		var asks_lcm: bool = question.question_text.contains("(LCM)")
		assert_true(asks_hcf != asks_lcm,
				"exactly one target named (%s)" % question.question_text)


func test_correct_answer_matches_independent_reference() -> void:
	for tier in range(1, 5):
		for i in range(50):
			var question: Dictionary = strategy.generate(tier, {})
			var numbers: Array = _extract_numbers(question.question_text)
			if question.question_text.contains("(HCF)"):
				var hcf: int = numbers[0]
				for j in range(1, numbers.size()):
					hcf = _ref_gcd(hcf, numbers[j])
				assert_eq(question.correct_answer, hcf,
						"HCF ground truth (%s)" % question.question_text)
			else:
				var lcm_value: int = numbers[0]
				for j in range(1, numbers.size()):
					lcm_value = _ref_lcm(lcm_value, numbers[j])
				assert_eq(question.correct_answer, lcm_value,
						"LCM ground truth (%s)" % question.question_text)


func test_choices_unique_positive_and_none_equal_outside_the_answer() -> void:
	for i in range(80):
		var question: Dictionary = strategy.generate(randi_range(1, 4), {})
		var choices: Array = question.choices
		assert_eq(choices.size(), 4)
		var seen := {}
		for choice in choices:
			assert_gt(choice, 0, "all distractors positive")
			assert_lte(choice, 2000, "distractors stay within a sane band")
			assert_false(seen.has(choice), "no duplicates")
			seen[choice] = true
		assert_true(seen.has(question.correct_answer))


## FR16.5: Tier 1 LCM pairs never have LCM == product (no multiplication
## shortcut), and stay within the small bounds.
func test_tier_one_bounds_respected() -> void:
	var saw_lcm_item := false
	var saw_hcf_item := false
	for i in range(100):
		var question: Dictionary = strategy.generate(1, {})
		var numbers: Array = _extract_numbers(question.question_text)
		for number in numbers:
			assert_lte(number, 20, "Tier 1 numbers cap at 20")
		if question.question_text.contains("(HCF)"):
			saw_hcf_item = true
			assert_gt(_ref_gcd(numbers[0], numbers[1]), 1,
					"HCF items share a factor > 1")
		else:
			saw_lcm_item = true
			var lcm_value := _ref_lcm(numbers[0], numbers[1])
			assert_lte(lcm_value, 60, "Tier 1 LCM stays small")
			assert_ne(lcm_value, numbers[0] * numbers[1],
					"product-equal cases excluded at Tier 1")
	assert_true(saw_lcm_item and saw_hcf_item, "both forms occur across seeds")


## FR16.5: three-number HCF items appear from Tier 3; three-number LCM
## items from Tier 4+.
func test_three_number_items_arrive_at_higher_tiers() -> void:
	var saw_three_number_hcf := false
	var saw_three_number_lcm := false
	for i in range(150):
		if not saw_three_number_hcf:
			var question: Dictionary = strategy.generate(3, {})
			if question.question_text.contains("(HCF)"):
				var numbers: Array = _extract_numbers(question.question_text)
				if numbers.size() == 3:
					saw_three_number_hcf = true
		if not saw_three_number_lcm:
			var q4: Dictionary = strategy.generate(4, {})
			if q4.question_text.contains("(LCM)"):
				var nums4: Array = _extract_numbers(q4.question_text)
				if nums4.size() == 3:
					saw_three_number_lcm = true
		if saw_three_number_hcf and saw_three_number_lcm:
			break
	assert_true(saw_three_number_hcf, "Tier 3 introduces three-number HCF")
	assert_true(saw_three_number_lcm, "Tier 4+ introduces three-number LCM")


func test_low_tiers_never_ask_three_number_questions() -> void:
	for i in range(80):
		var question: Dictionary = strategy.generate(randi_range(1, 2), {})
		var numbers: Array = _extract_numbers(question.question_text)
		assert_eq(numbers.size(), 2, "Tiers 1-2 use exactly two numbers")


func test_max_operand_pins_operand_magnitudes() -> void:
	for i in range(40):
		var question: Dictionary = strategy.generate(10, {"max_operand": 15})
		for number in _extract_numbers(question.question_text):
			assert_lte(number, 15, "pinned operand ceiling respected")
