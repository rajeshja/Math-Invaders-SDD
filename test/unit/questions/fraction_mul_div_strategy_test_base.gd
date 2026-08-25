## Shared test engine for the fraction multiplication/division strategies
## (Phase 14 Testing Plan). Not collected by GUT directly (filename lacks
## the test_ prefix); both concrete test scripts extend this.
extends GutTest

const FractionValueScript = preload("res://scripts/questions/support/fraction_value.gd")


func _make_strategy():
	return null


func _symbol_token() -> String:
	return "?"


func _fv(numerator: int, denominator: int) -> FractionValue:
	return FractionValueScript.from_parts(numerator, denominator)


func _parse_operand(text: String) -> Array:
	var trimmed := text.strip_edges()
	if not trimmed.contains("/"):
		return [int(trimmed), 1]
	if trimmed.contains(" "):
		var pieces := trimmed.split(" ", false)
		var whole := int(pieces[0])
		var frac := pieces[1].split("/")
		var den := int(frac[1])
		return [whole * den + int(frac[0]), den]
	var halves := trimmed.split("/")
	return [int(halves[0]), int(halves[1])]


func _parse_question(question: Dictionary) -> Array:
	var body: String = question.question_text.trim_prefix("What is ").trim_suffix("?")
	var parts := body.split(" %s " % _symbol_token(), false)
	assert_eq(parts.size(), 2, "question_text should hold two operands")
	return [_parse_operand(parts[0]), _parse_operand(parts[1])]


func _expected_result(operands: Array) -> FractionValue:
	return null


func test_correct_answer_equals_true_simplified_result() -> void:
	var strategy = _make_strategy()
	for config_tier in range(1, 5):
		for i in range(40):
			var question: Dictionary = strategy.generate(config_tier, {})
			var operands := _parse_question(question)
			var expected := _expected_result(operands)
			var given := _parse_operand(question.correct_answer)
			assert_true(expected.value_equals(_fv(given[0], given[1])),
					"correct_answer solves its own question (%s)" % question.question_text)
			assert_eq(FractionValueScript.gcd(given[0], given[1]), 1,
					"correct answers fully simplified")


func test_exactly_one_value_correct_choice_among_four_unique() -> void:
	var strategy = _make_strategy()
	for i in range(60):
		var question: Dictionary = strategy.generate(randi_range(1, 4), {})
		var choices: Array = question.choices
		assert_eq(choices.size(), 4, "always four choices")
		var expected := _expected_result(_parse_question(question))
		var correct_count := 0
		for choice in choices:
			var value := _parse_operand(choice)
			if expected.value_equals(_fv(value[0], value[1])):
				correct_count += 1
		assert_eq(correct_count, 1, "exactly one value-correct choice")
		for a in range(choices.size()):
			for b in range(a + 1, choices.size()):
				var va := _parse_operand(choices[a])
				var vb := _parse_operand(choices[b])
				assert_false(_fv(va[0], va[1]).value_equals(_fv(vb[0], vb[1])),
						"choices pairwise value-distinct")


func test_no_negative_values_anywhere() -> void:
	var strategy = _make_strategy()
	for i in range(80):
		var question: Dictionary = strategy.generate(randi_range(1, 4), {})
		for text in [question.correct_answer] + question.choices:
			assert_false(text.begins_with("-") or text.contains("/-"),
					"no negative values ('%s')" % text)


func test_answer_layout_matches_every_displayed_choice() -> void:
	var strategy = _make_strategy()
	for i in range(60):
		var question: Dictionary = strategy.generate(randi_range(2, 4), {})
		var choices: Array = question.choices
		var layouts: Array = question.answer_layout
		assert_eq(layouts.size(), choices.size(), "layout array parallels choices")
		for j in range(choices.size()):
			var value := _parse_operand(choices[j])
			var layout: Variant = layouts[j]
			var simplified := _fv(value[0], value[1]).simplify()
			if simplified.is_whole():
				assert_null(layout, "'%s' renders plain text" % choices[j])
			elif layout is Dictionary and layout.has("whole"):
				var parts: Dictionary = simplified.mixed_parts()
				assert_eq(int(layout.whole), parts.whole)
				assert_eq(int(layout.numerator), parts.numerator)
				assert_eq(int(layout.denominator), parts.denominator)
			else:
				assert_eq(int(layout.numerator), simplified.numerator)
				assert_eq(int(layout.denominator), simplified.denominator)


func test_representation_is_consistent_within_a_question() -> void:
	var strategy = _make_strategy()
	for i in range(80):
		var question: Dictionary = strategy.generate(
				randi_range(2, 4), {"allow_unlike_denominators": false})
		var mixed_count := 0
		var stacked_improper_count := 0
		for choice in question.choices:
			var value := _parse_operand(choice)
			var simplified := _fv(value[0], value[1]).simplify()
			if not simplified.is_improper():
				continue
			if choice.contains(" "):
				mixed_count += 1
			else:
				stacked_improper_count += 1
		assert_false(mixed_count > 0 and stacked_improper_count > 0,
				"improper choices share ONE representation per question")


func test_question_segments_mirror_the_inline_tokens() -> void:
	var strategy = _make_strategy()
	var question: Dictionary = strategy.generate(2, {})
	var segments: Array = question.question_segments
	assert_eq(str(segments[0].text), "What is ")
	assert_true(segments[1].has("fraction"), "first operand stacks")
	assert_true(str(segments[2].text).contains(_symbol_token()), "operator token present")
	assert_true(segments[3].has("fraction"), "second operand stacks")
	assert_eq(str(segments[4].text), "?")


func test_max_operand_size_caps_components_when_pinned() -> void:
	var strategy = _make_strategy()
	for i in range(60):
		var question: Dictionary = strategy.generate(10, {"max_operand": 6})
		var operands := _parse_question(question)
		for operand in operands:
			assert_lte(operand[0], 36, "raw numerators stay within pinned products")
			assert_lte(operand[1], 6, "pinned denominator ceiling")
