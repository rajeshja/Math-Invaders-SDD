## FractionSubtractionStrategy tests (Phase 13). Shared cases are inherited
## from fraction_add_sub_strategy_test_base.gd; subtraction-specific
## expectations live here.
extends "res://test/unit/questions/fraction_add_sub_strategy_test_base.gd"

const FractionSubtractionStrategyScript = preload(
		"res://scripts/questions/strategies/fraction_subtraction_strategy.gd")


func _make_strategy():
	return FractionSubtractionStrategyScript.new()


func _symbol_token() -> String:
	return "-"


func _is_add() -> bool:
	return false


func test_dispatch_symbol_is_minus_in_question_text() -> void:
	var strategy = _make_strategy()
	for i in range(10):
		var question: Dictionary = strategy.generate(1, {})
		assert_string_contains(question.question_text, " - ",
				"subtraction questions use the - operator")


## FR13.6: subtraction results are never negative, at any tier or option
## combination.
func test_results_are_never_negative() -> void:
	var strategy = _make_strategy()
	for i in range(120):
		var question: Dictionary = strategy.generate(
				randi_range(1, 4),
				{"allow_unlike_denominators": randf() < 0.5})
		var operands := _parse_question(question)
		# The displayed left operand must be the larger value.
		assert_true(
				operands[0][0] * operands[1][1] >= operands[1][0] * operands[0][1],
				"operands ordered largest-first (%s)" % question.question_text)
		var value := _parse_operand(question.correct_answer)
		assert_gte(value[0], 0, "correct answers never negative")
		for choice in question.choices:
			var parsed := _parse_operand(choice)
			assert_false(str(parsed[0]).begins_with("-") or str(parsed[1]).begins_with("-"),
					"distractors never render negative ('%s')" % choice)
