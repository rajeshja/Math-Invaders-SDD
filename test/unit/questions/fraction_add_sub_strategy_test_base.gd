## Shared test engine for the fraction addition/subtraction strategies
## (Phase 13 Testing Plan). Not collected by GUT directly (filename lacks
## the test_ prefix); both concrete test scripts extend this and inherit
## every case, parameterized by _make_strategy()/_symbol_token()/_is_add().
extends GutTest

const FractionValueScript = preload("res://scripts/questions/support/fraction_value.gd")


func _make_strategy():
	return null


func _symbol_token() -> String:
	return "?"


func _is_add() -> bool:
	return false


func _fv(numerator: int, denominator: int) -> FractionValue:
	return FractionValueScript.from_parts(numerator, denominator)


## Parses "3/8", "1 1/2", or "2" into [numerator, denominator].
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
	var a: Array = operands[0]
	var b: Array = operands[1]
	var lcd: int = FractionValueScript.lcm(a[1], b[1])
	var scaled_a: int = a[0] * lcd / a[1]
	var scaled_b: int = b[0] * lcd / b[1]
	var raw: int = scaled_a + scaled_b if _is_add() else scaled_a - scaled_b
	return _fv(raw, lcd).simplify()


func _assert_canonical_string(answer_text: String) -> void:
	# Re-render canonically and require an exact match.
	var parsed := _parse_operand(answer_text)
	var value := _fv(parsed[0], parsed[1]).simplify()
	if value.is_whole():
		assert_eq(answer_text, str(value.numerator), "whole answers render bare")
	elif answer_text.contains(" "):
		assert_eq(answer_text, value.to_display_string(true),
				"mixed answers use exactly one space: 'w n/d'")
	else:
		assert_eq(answer_text, value.to_display_string(false),
				"fraction answers render simplified 'n/d'")


## FR13.6/FR13.9: the marked-correct choice equals the true simplified
## result of the displayed operands, across tiers and option settings.
func test_correct_answer_equals_true_simplified_result() -> void:
	var strategy = _make_strategy()
	for config in [
		{"difficulty": 1, "options": {}},
		{"difficulty": 2, "options": {}},
		{"difficulty": 3, "options": {"allow_unlike_denominators": true}},
		{"difficulty": 4, "options": {"allow_unlike_denominators": true}},
	]:
		for i in range(40):
			var question: Dictionary = strategy.generate(config.difficulty, config.options)
			var operands := _parse_question(question)
			var expected := _expected_result(operands)
			var given := _parse_operand(question.correct_answer)
			assert_true(expected.value_equals(_fv(given[0], given[1])),
					"correct_answer solves its own question (%s vs expected %s)" % [
						question.correct_answer, expected.to_display_string(true)])
			_assert_canonical_string(question.correct_answer)


func test_exactly_one_value_correct_choice_among_four_unique() -> void:
	var strategy = _make_strategy()
	for i in range(60):
		var question: Dictionary = strategy.generate(
				randi_range(1, 4), {"allow_unlike_denominators": randf() < 0.5})
		var choices: Array = question.choices
		assert_eq(choices.size(), 4, "always four choices")
		var correct_count := 0
		var expected := _expected_result(_parse_question(question))
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
						"choices are pairwise value-distinct (no unsimplified twin)")


func test_answers_are_always_fully_simplified() -> void:
	var strategy = _make_strategy()
	for i in range(100):
		var question: Dictionary = strategy.generate(
				randi_range(2, 4), {"allow_unlike_denominators": true})
		var value := _parse_operand(question.correct_answer)
		assert_eq(FractionValueScript.gcd(value[0], value[1]), 1,
				"GCD(numerator, denominator) == 1 for '%s'" % question.correct_answer)


## FR13.7: Tier 1 stays like-denominator with small proper operands.
func test_tier_one_uses_like_denominators_and_stays_small() -> void:
	var strategy = _make_strategy()
	var max_den_seen := 0
	var max_num_seen := 0
	for i in range(60):
		var question: Dictionary = strategy.generate(1, {})
		var operands := _parse_question(question)
		assert_eq(operands[0][1], operands[1][1],
				"Tier 1 denominators are like (%s)" % question.question_text)
		max_den_seen = maxi(max_den_seen, operands[0][1])
		max_num_seen = maxi(max_num_seen, maxi(operands[0][0], operands[1][0]))
	assert_lte(max_den_seen, 10, "Tier 1 denominators cap at 10")
	assert_lte(max_num_seen, 9, "Tier 1 numerators cap at 9")


## FR13.7: unlike denominators appear only from Tier 3 WITH the knob on -
## and are GUARANTEED there (multiple-related pairs never repeat a value,
## coprime pairs differ by construction).
func test_tier_three_plus_yields_unlike_denominators_when_enabled() -> void:
	var strategy = _make_strategy()
	for i in range(80):
		var question: Dictionary = strategy.generate(
				randi_range(3, 4), {"allow_unlike_denominators": true})
		var operands := _parse_question(question)
		assert_ne(operands[0][1], operands[1][1],
				"Tier 3+ with the knob on always deals unlike denominators")


func test_tier_below_three_never_yields_unlike_denominators() -> void:
	var strategy = _make_strategy()
	for i in range(60):
		var question: Dictionary = strategy.generate(randi_range(1, 2), {})
		var operands := _parse_question(question)
		assert_eq(operands[0][1], operands[1][1],
				"Tiers 1-2 are like-denominator only")

	# The knob alone cannot introduce unlike denominators below Tier 3.
	var forced: Dictionary = strategy.generate(2, {"allow_unlike_denominators": true})
	var forced_operands := _parse_question(forced)
	assert_eq(forced_operands[0][1], forced_operands[1][1],
			"unlike gating requires Tier 3+")


## FR13.7: higher tiers reach larger values than Tier 1.
func test_higher_tiers_reach_larger_numerators_and_denominators() -> void:
	var strategy = _make_strategy()
	var tier_one_max := 0
	var high_tier_max := 0
	for i in range(80):
		tier_one_max = maxi(tier_one_max, _max_component(strategy.generate(1, {})))
		high_tier_max = maxi(high_tier_max,
				_max_component(strategy.generate(4, {"allow_unlike_denominators": true})))
	assert_gt(high_tier_max, tier_one_max,
			"Tier 4+ reaches larger components than Tier 1")


func _max_component(question: Dictionary) -> int:
	var biggest := 0
	for choice in question.choices:
		var parts := _parse_operand(choice)
		biggest = maxi(biggest, maxi(parts[0], parts[1]))
	return biggest


## FR13.8: improper results appear in BOTH representations across seeds -
## stacked-improper AND mixed - never leaking the correct answer by format.
func test_representation_mix_for_improper_results() -> void:
	var strategy = _make_strategy()
	var saw_improper_stacked := false
	var saw_mixed := false
	for i in range(120):
		var question: Dictionary = strategy.generate(
				_improper_tier(), {"allow_unlike_denominators": true})
		var value := _parse_operand(question.correct_answer)
		if value[0] <= value[1]:
			continue  # proper/whole results carry no representation choice
		if question.correct_answer.contains(" "):
			saw_mixed = true
		else:
			saw_improper_stacked = true
	assert_true(saw_mixed, "some improper results rendered mixed ('w n/d')")
	assert_true(saw_improper_stacked, "some improper results rendered stacked ('n/d')")


func _improper_tier() -> int:
	return 4


## FR13.3/FR13.8: answer_layout travels parallel to choices and matches
## each displayed string exactly.
func test_answer_layout_matches_every_displayed_choice() -> void:
	var strategy = _make_strategy()
	for i in range(60):
		var question: Dictionary = strategy.generate(
				randi_range(2, 4), {"allow_unlike_denominators": true})
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


func test_question_segments_mirror_the_inline_tokens() -> void:
	var strategy = _make_strategy()
	var question: Dictionary = strategy.generate(2, {})
	var segments: Array = question.question_segments
	assert_eq(str(segments[0].text), "What is ")
	assert_true(segments[1].has("fraction"), "first operand stacks")
	assert_true(segments[2].text.contains(_symbol_token()), "operator token present")
	assert_true(segments[3].has("fraction"), "second operand stacks")
	assert_eq(str(segments[4].text), "?")


## FR13.7: max_operand_size pins numerators AND denominators.
func test_max_operand_size_caps_components_when_pinned() -> void:
	var strategy = _make_strategy()
	for i in range(80):
		var question: Dictionary = strategy.generate(10, {"max_operand": 5})
		var operands := _parse_question(question)
		for operand in operands:
			assert_lte(operand[0], 5, "pinned numerator ceiling")
			assert_lte(operand[1], 5, "pinned denominator ceiling")
