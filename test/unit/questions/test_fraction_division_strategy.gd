## FractionDivisionStrategy tests (Phase 14). Shared cases inherited from
## fraction_mul_div_strategy_test_base.gd; division-specific ladder
## expectations live here.
extends "res://test/unit/questions/fraction_mul_div_strategy_test_base.gd"

const FractionDivisionStrategyScript = preload(
		"res://scripts/questions/strategies/fraction_division_strategy.gd")


func _make_strategy():
	return FractionDivisionStrategyScript.new()


func _symbol_token() -> String:
	return "÷"


func _expected_result(operands: Array) -> FractionValue:
	var dividend: Array = operands[0]
	var divisor: Array = operands[1]
	# dividend x reciprocal(divisor), simplified.
	return _fv(dividend[0] * divisor[1], dividend[1] * divisor[0]).simplify()


func test_divisor_is_never_zero() -> void:
	var strategy = _make_strategy()
	for tier in range(1, 5):
		for i in range(30):
			var question: Dictionary = strategy.generate(tier, {})
			var divisor: Array = _parse_question(question)[1]
			assert_ne(divisor[0], 0, "divisor numerator never zero")
			assert_gt(divisor[1], 0, "divisor denominator never zero")


func test_uses_divide_symbol_without_complex_fraction_notation() -> void:
	var strategy = _make_strategy()
	for i in range(20):
		var question: Dictionary = strategy.generate(randi_range(1, 4), {})
		assert_string_contains(question.question_text, "÷",
				"division questions use the ÷ symbol")


func test_tier_one_restricted_to_whole_and_unit_structures() -> void:
	var strategy = _make_strategy()
	for i in range(60):
		var question: Dictionary = strategy.generate(1, {})
		var operands := _parse_question(question)
		for operand in operands:
			var is_whole: bool = operand[1] == 1
			var is_unit: bool = operand[0] == 1 and operand[1] > 1
			assert_true(is_whole or is_unit,
					"Tier 1 operands are whole numbers or unit fractions (%s)"
							% question.question_text)


## FR14.4: higher tiers include mixed-number operands.
func test_higher_tiers_include_mixed_or_improper_operands() -> void:
	var strategy = _make_strategy()
	var saw_over_one := false
	for i in range(100):
		var question: Dictionary = strategy.generate(4, {})
		for operand in _parse_question(question):
			if operand[0] > operand[1]:
				saw_over_one = true
	assert_true(saw_over_one, "Tier 4 deals operands greater than one")


## FR14.4 Tier 2: unit ÷ unit items occur and simplify cleanly.
func test_tier_two_includes_unit_divided_by_unit() -> void:
	var strategy = _make_strategy()
	var saw_unit_unit := false
	for i in range(40):
		var question: Dictionary = strategy.generate(2, {})
		var operands := _parse_question(question)
		if operands[0][0] == 1 and operands[1][0] == 1 \
				and operands[0][1] > 1 and operands[1][1] > 1:
			saw_unit_unit = true
	assert_true(saw_unit_unit, "unit ÷ unit items appear at Tier 2")
