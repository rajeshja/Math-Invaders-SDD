## Shared test engine for the four decimal strategies (Phase 15 Testing
## Plan). Not collected by GUT directly (filename lacks the test_ prefix);
## the concrete per-operation test scripts extend this. All reference
## computations parse canonical strings into scaled integers - never
## floats.
extends GutTest

const DecimalValueScript = preload("res://scripts/questions/support/decimal_value.gd")


func _make_strategy():
	return null


func _symbol_token() -> String:
	return "?"


func _parse_decimal(text: String) -> Array:
	# "12.34" -> [1234, 2]; "0.05" -> [5, 2]; "7" -> [7, 0].
	var trimmed := text.strip_edges()
	var negative := trimmed.begins_with("-")
	if negative:
		trimmed = trimmed.substr(1)
	var dot: int = trimmed.find(".")
	if dot < 0:
		return [-int(trimmed) if negative else int(trimmed), 0]
	var places: int = trimmed.length() - dot - 1
	var compact: String = trimmed.replace(".", "")
	var magnitude: int = int(compact)
	return [-magnitude if negative else magnitude, places]


func _value_of(parsed: Array) -> DecimalValue:
	return DecimalValueScript.from_scaled(parsed[0], parsed[1])


func _parse_question(question: Dictionary) -> Array:
	var body: String = question.question_text.trim_prefix("What is ").trim_suffix("?")
	var parts := body.split(" %s " % _symbol_token(), false)
	assert_eq(parts.size(), 2, "question_text should hold two operands")
	return [_parse_decimal(parts[0]), _parse_decimal(parts[1])]


func _expected_result(operands: Array) -> DecimalValue:
	return null


func _is_canonical(text: String) -> bool:
	if text.begins_with(".") or text.contains("+") or text.contains(","):
		return false
	if text.contains("-") and not text.begins_with("-"):
		return false
	if not text.contains("."):
		return text.is_valid_int()
	var parts := text.split(".")
	if parts.size() != 2 or parts[0].is_empty() or parts[1].is_empty():
		return false
	if not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return false
	if parts[1].ends_with("0"):
		return false  # trailing zeros are stripped canonically
	return true


func test_correct_answer_equals_exact_reference_result() -> void:
	var strategy = _make_strategy()
	for tier in range(1, 5):
		for i in range(40):
			var question: Dictionary = strategy.generate(tier, {})
			var operands := _parse_question(question)
			var expected := _expected_result(operands)
			assert_true(expected != null, "reference result defined")
			var given := _parse_decimal(question.correct_answer)
			assert_true(expected.value_equals(_value_of(given)),
					"correct_answer solves '%s'" % question.question_text)


func test_all_choices_canonical_unique_with_one_correct() -> void:
	var strategy = _make_strategy()
	for i in range(80):
		var question: Dictionary = strategy.generate(randi_range(1, 4), {})
		var choices: Array = question.choices
		assert_eq(choices.size(), 4, "always four choices")
		var expected := _expected_result(_parse_question(question))
		var correct_count := 0
		var seen: Array = []
		for choice in choices:
			assert_true(_is_canonical(choice), "'%s' must be canonically formatted" % choice)
			var value := _parse_decimal(choice)
			if expected.value_equals(_value_of(value)):
				correct_count += 1
			for previous in seen:
				assert_false(_value_of(value).value_equals(_value_of(previous)),
						"choices pairwise value-distinct")
			seen.append(value)
		assert_eq(correct_count, 1, "exactly one value-correct choice")


func test_operand_places_respect_tier_curve_and_override() -> void:
	var strategy = _make_strategy()
	# Effective caps per tier with no override (curve).
	for tier_and_cap in [[1, 1], [2, 2], [3, 3], [4, 4]]:
		for i in range(30):
			var question: Dictionary = strategy.generate(tier_and_cap[0], {})
			for operand in _parse_question(question):
				assert_lte(operand[1], tier_and_cap[1],
						"tier %d keeps places <= %d" % [tier_and_cap[0], tier_and_cap[1]])
	# The knob clamps every tier.
	for tier in range(1, 5):
		for i in range(20):
			var question: Dictionary = strategy.generate(tier, {"max_decimal_places": 1})
			for operand in _parse_question(question):
				assert_lte(operand[1], 1,
						"max_decimal_places=1 clamps tier %d" % tier)


func test_higher_tiers_reach_more_places_or_larger_magnitudes() -> void:
	var strategy = _make_strategy()
	var tier_one_reach := 0
	var high_tier_reach := 0
	for i in range(60):
		for operand in _parse_question(strategy.generate(1, {})):
			tier_one_reach = maxi(tier_one_reach, operand[1] * 100000 + absi(operand[0]))
		for operand in _parse_question(strategy.generate(4, {})):
			high_tier_reach = maxi(high_tier_reach, operand[1] * 100000 + absi(operand[0]))
	assert_gt(high_tier_reach, tier_one_reach,
			"Tier 4+ reaches deeper places or larger magnitudes than Tier 1")


## FR15.6: place-shift misconceptions appear among distractors somewhere.
func test_distractors_include_place_shift_errors_somewhere() -> void:
	var strategy = _make_strategy()
	var saw_place_shift := false
	for i in range(60):
		if saw_place_shift:
			break
		var question: Dictionary = strategy.generate(randi_range(2, 4), {})
		var operands := _parse_question(question)
		var correct := _expected_result(operands)
		var shifted_up: Variant = correct.shift10(1)
		var shifted_down: Variant = correct.shift10(-1)
		for choice in question.choices:
			var value := _value_of(_parse_decimal(choice))
			if (shifted_up is DecimalValue and value.value_equals(shifted_up)) \
					or (shifted_down is DecimalValue and value.value_equals(shifted_down)):
				saw_place_shift = true
				break
	assert_true(saw_place_shift,
			"at least one x10/div-10 distractor appears across seeds")


func test_question_segments_absent_plain_text_path() -> void:
	var strategy = _make_strategy()
	var question: Dictionary = strategy.generate(2, {})
	assert_false(question.has("answer_layout"),
			"decimals ride the plain-text path (no stacked layout)")
	assert_false(question.has("question_segments"), "no segment data either")
