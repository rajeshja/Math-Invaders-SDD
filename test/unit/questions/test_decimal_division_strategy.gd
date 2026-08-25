## DecimalDivisionStrategy tests (Phase 15). Shared cases inherited from
## decimal_strategy_test_base.gd; divisor-first terminating guarantees
## live here.
extends "res://test/unit/questions/decimal_strategy_test_base.gd"

const DecimalDivisionStrategyScript = preload(
		"res://scripts/questions/strategies/decimal_division_strategy.gd")


func _make_strategy():
	return DecimalDivisionStrategyScript.new()


func _symbol_token() -> String:
	return "÷"


## Independent termination reference: reduce dividend/divisor on raw
## scaled ints, then shift one digit at a time until it divides - no
## prime-factor logic shared with the implementation.
func _expected_result(operands: Array) -> DecimalValue:
	var dividend := _value_of(operands[0])
	var divisor := _value_of(operands[1])
	var negative: bool = (dividend.scaled < 0) != (divisor.scaled < 0)
	var numerator: int = absi(dividend.scaled) * DecimalValueScript.pow10(divisor.places)
	var denominator: int = absi(divisor.scaled) * DecimalValueScript.pow10(dividend.places)
	if denominator == 0:
		return null
	var shared := _gcd(numerator, denominator)
	if shared > 0:
		numerator /= shared
		denominator /= shared
	for k in range(13):
		if numerator % denominator == 0:
			var scaled: int = numerator / denominator
			if negative:
				scaled = -scaled
			return DecimalValueScript.from_scaled(scaled, k)
		numerator *= 10
	return null


static func _gcd(a: int, b: int) -> int:
	a = absi(a)
	b = absi(b)
	while b != 0:
		var t := b
		b = a % b
		a = t
	return a


func test_answer_satisfies_divisor_times_answer_equals_dividend() -> void:
	var strategy = _make_strategy()
	for tier in range(1, 5):
		for i in range(40):
			var question: Dictionary = strategy.generate(tier, {})
			var operands := _parse_question(question)
			var dividend := _value_of(operands[0])
			var divisor := _value_of(operands[1])
			var answer := _value_of(_parse_decimal(question.correct_answer))
			assert_ne(divisor.scaled, 0, "divisor never zero")
			assert_true(divisor.mul(answer).value_equals(dividend),
					"divisor x '%s' == dividend for '%s'"
							% [question.correct_answer, question.question_text])


func test_divisor_never_zero_and_division_always_terminates() -> void:
	var strategy = _make_strategy()
	for tier in range(1, 5):
		for i in range(30):
			var question: Dictionary = strategy.generate(tier, {})
			var divisor: Array = _parse_question(question)[1]
			assert_ne(divisor[0], 0, "divisor never zero")
			# Exactness at the common scale proves the decimal terminates.
			assert_true(_expected_result(_parse_question(question)) != null,
					"'%s' divides exactly" % question.question_text)


func test_dividend_is_exact_multiple_of_divisor_scaled() -> void:
	var strategy = _make_strategy()
	for tier in range(1, 5):
		for i in range(20):
			var question: Dictionary = strategy.generate(tier, {})
			var quotient: Variant = _expected_result(_parse_question(question))
			assert_true(quotient is DecimalValue)
			# Divisor-first construction: dividend == divisor x quotient.
			var operands := _parse_question(question)
			var rebuilt: DecimalValue = _value_of(operands[1]).mul(quotient)
			assert_true(rebuilt.value_equals(_value_of(operands[0])),
					"dividend derives from divisor x quotient")


func test_uses_divide_symbol() -> void:
	var strategy = _make_strategy()
	for i in range(10):
		var question: Dictionary = strategy.generate(randi_range(1, 4), {})
		assert_string_contains(question.question_text, "÷",
				"division questions use the ÷ symbol")
