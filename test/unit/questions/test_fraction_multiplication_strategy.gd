## FractionMultiplicationStrategy tests (Phase 14). Shared cases inherited
## from fraction_mul_div_strategy_test_base.gd; multiplication-specific
## ladder expectations live here.
extends "res://test/unit/questions/fraction_mul_div_strategy_test_base.gd"

const FractionMultiplicationStrategyScript = preload(
		"res://scripts/questions/strategies/fraction_multiplication_strategy.gd")


func _make_strategy():
	return FractionMultiplicationStrategyScript.new()


func _symbol_token() -> String:
	return "x"


func _expected_result(operands: Array) -> FractionValue:
	var a: Array = operands[0]
	var b: Array = operands[1]
	return _fv(a[0] * b[0], a[1] * b[1]).simplify()


func test_tier_one_has_whole_or_unit_operand_with_clean_structure() -> void:
	var strategy = _make_strategy()
	for i in range(60):
		var question: Dictionary = strategy.generate(1, {})
		var operands := _parse_question(question)
		var has_whole_or_unit := false
		for operand in operands:
			if operand[1] == 1 or (operand[0] == 1 and operand[1] > 1):
				has_whole_or_unit = true
		assert_true(has_whole_or_unit,
				"Tier 1 keeps a whole or unit-fraction operand (%s)" % question.question_text)
		# Canceling structure: the product simplifies to something small.
		var expected := _expected_result(operands)
		assert_lt(maxi(expected.numerator, expected.denominator), 40,
				"Tier 1 products stay small after cancellation")


## FR14.3: from Tier 3 on, mixed-number (or improper) operands appear.
func test_higher_tiers_include_mixed_or_improper_operands() -> void:
	var strategy = _make_strategy()
	var saw_over_one := false
	for i in range(80):
		var question: Dictionary = strategy.generate(randi_range(3, 4), {})
		for operand in _parse_question(question):
			if operand[0] > operand[1]:
				saw_over_one = true
	assert_true(saw_over_one, "Tier 3+ deals operands greater than one")


func test_tier_two_stays_proper_times_proper() -> void:
	var strategy = _make_strategy()
	for i in range(40):
		var question: Dictionary = strategy.generate(2, {})
		for operand in _parse_question(question):
			assert_lt(operand[0], operand[1], "Tier 2 operands stay proper")
