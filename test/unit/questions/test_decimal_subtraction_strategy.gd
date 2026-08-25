## DecimalSubtractionStrategy tests (Phase 15). Shared cases inherited
## from decimal_strategy_test_base.gd; the never-negative guarantee lives
## here.
extends "res://test/unit/questions/decimal_strategy_test_base.gd"

const DecimalSubtractionStrategyScript = preload(
		"res://scripts/questions/strategies/decimal_subtraction_strategy.gd")


func _make_strategy():
	return DecimalSubtractionStrategyScript.new()


func _symbol_token() -> String:
	return "-"


func _expected_result(operands: Array) -> DecimalValue:
	var a := _value_of(operands[0])
	var b := _value_of(operands[1])
	var target: int = maxi(a.places, b.places)
	return DecimalValueScript.from_scaled(
			a.scaled * DecimalValueScript.pow10(target - a.places)
					- b.scaled * DecimalValueScript.pow10(target - b.places), target)


## FR15.5: subtraction results are never negative.
func test_results_are_never_negative_and_operands_ordered() -> void:
	var strategy = _make_strategy()
	for i in range(80):
		var question: Dictionary = strategy.generate(randi_range(1, 4), {})
		var operands := _parse_question(question)
		var left: Array = operands[0]
		var right: Array = operands[1]
		var target: int = maxi(left[1], right[1])
		var left_scaled: int = left[0] * DecimalValueScript.pow10(target - left[1])
		var right_scaled: int = right[0] * DecimalValueScript.pow10(target - right[1])
		assert_gte(left_scaled, right_scaled,
				"largest operand shown first (%s)" % question.question_text)
		var result: Array = _parse_decimal(question.correct_answer)
		assert_gte(result[0], 0, "correct answers never negative")
