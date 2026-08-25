## FractionAdditionStrategy tests (Phase 13). Shared cases are inherited
## from fraction_add_sub_strategy_test_base.gd; addition-specific
## expectations live here.
extends "res://test/unit/questions/fraction_add_sub_strategy_test_base.gd"

const FractionAdditionStrategyScript = preload(
		"res://scripts/questions/strategies/fraction_addition_strategy.gd")


func _make_strategy():
	return FractionAdditionStrategyScript.new()


func _symbol_token() -> String:
	return "+"


func _is_add() -> bool:
	return true


func test_dispatch_symbol_is_plus_in_question_text() -> void:
	var strategy = _make_strategy()
	for i in range(10):
		var question: Dictionary = strategy.generate(1, {})
		assert_string_contains(question.question_text, " + ",
				"addition questions use the + operator")


func test_tier_one_sums_stay_proper_where_possible() -> void:
	var strategy = _make_strategy()
	var improper_seen := 0
	for i in range(60):
		var question: Dictionary = strategy.generate(1, {})
		var value := _parse_operand(question.correct_answer)
		if value[0] >= value[1] and not question.correct_answer.contains("/"):
			continue  # whole results are fine (e.g. 1/2 + 1/2)
		if value[0] > value[1]:
			improper_seen += 1
	assert_lte(improper_seen, 3,
			"Tier 1 addition prefers results that stay proper")
