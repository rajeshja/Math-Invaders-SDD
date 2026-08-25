## DecimalAdditionStrategy tests (Phase 15). Shared cases inherited from
## decimal_strategy_test_base.gd.
extends "res://test/unit/questions/decimal_strategy_test_base.gd"

const DecimalAdditionStrategyScript = preload(
		"res://scripts/questions/strategies/decimal_addition_strategy.gd")


func _make_strategy():
	return DecimalAdditionStrategyScript.new()


func _symbol_token() -> String:
	return "+"


func _expected_result(operands: Array) -> DecimalValue:
	var a := _value_of(operands[0])
	var b := _value_of(operands[1])
	var target: int = maxi(a.places, b.places)
	return DecimalValueScript.from_scaled(
			a.scaled * DecimalValueScript.pow10(target - a.places)
					+ b.scaled * DecimalValueScript.pow10(target - b.places), target)


func test_tier_one_operands_are_tenths_only() -> void:
	var strategy = _make_strategy()
	for i in range(40):
		var question: Dictionary = strategy.generate(1, {})
		for operand in _parse_question(question):
			assert_lte(operand[1], 1, "Tier 1 stays at tenths")


func test_mixed_place_counts_appear_from_tier_two() -> void:
	var strategy = _make_strategy()
	var saw_mixed := false
	for i in range(60):
		var operands := _parse_question(strategy.generate(randi_range(2, 4), {}))
		if operands[0][1] != operands[1][1]:
			saw_mixed = true
	assert_true(saw_mixed,
			"alignment becomes the skill when place counts differ")
