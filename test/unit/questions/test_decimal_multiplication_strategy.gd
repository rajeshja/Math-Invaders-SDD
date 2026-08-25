## DecimalMultiplicationStrategy tests (Phase 15). Shared cases inherited
## from decimal_strategy_test_base.gd; the product-place-cap guarantee
## lives here.
extends "res://test/unit/questions/decimal_strategy_test_base.gd"

const DecimalMultiplicationStrategyScript = preload(
		"res://scripts/questions/strategies/decimal_multiplication_strategy.gd")


func _make_strategy():
	return DecimalMultiplicationStrategyScript.new()


func _symbol_token() -> String:
	return "x"


func _expected_result(operands: Array) -> DecimalValue:
	var a := _value_of(operands[0])
	var b := _value_of(operands[1])
	return DecimalValueScript.from_scaled(a.scaled * b.scaled, a.places + b.places)


func test_tier_one_uses_whole_number_friendly_structures() -> void:
	var strategy = _make_strategy()
	for i in range(40):
		var question: Dictionary = strategy.generate(1, {})
		for operand in _parse_question(question):
			assert_lte(operand[1], 1,
					"Tier 1 factors are wholes or tenths (%s)" % question.question_text)


## FR15.5: the exact product's place count stays within the active cap -
## checked on the RESULT's minimal representation.
func test_product_places_stay_within_cap() -> void:
	var strategy = _make_strategy()
	for tier_and_cap in [[2, 2], [3, 3], [4, 4]]:
		for i in range(30):
			var question: Dictionary = strategy.generate(tier_and_cap[0], {})
			var result := _parse_decimal(question.correct_answer)
			assert_lte(result[1], tier_and_cap[1],
					"tier %d products keep places <= %d ('%s')"
							% [tier_and_cap[0], tier_and_cap[1], question.correct_answer])
