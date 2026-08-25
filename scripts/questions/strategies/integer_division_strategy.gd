## Integer division category strategy.
##
## Per Tech Stack §3 and Phase 3 NFR3.1: picks the DIVISOR and QUOTIENT
## first, then derives the dividend = divisor * quotient. This guarantees
## the question always resolves to a whole number - it never produces a
## fractional expected answer. Value ceiling configurable via
## options["max_operand"] (Phase 9).
class_name IntegerDivisionStrategy
extends QuestionStrategy


func generate(difficulty: int, options: Dictionary = {}) -> Dictionary:
	var clamped_difficulty: int = max(1, difficulty)
	var max_value: int = _max_value(clamped_difficulty, options)

	var divisor: int = randi_range(2, max_value)
	var quotient: int = randi_range(1, max_value)
	var dividend: int = divisor * quotient  # always evenly divisible by construction

	var correct_answer: int = quotient

	var distractors: Array = [
		quotient + 1,                     # off-by-one
		max(quotient - 1, 0),
		dividend - divisor,                # wrong-operation (subtracted instead)
		quotient + divisor,
		max(quotient - divisor, 0),
	]

	return {
		"question_text": "What is %d / %d?" % [dividend, divisor],
		"correct_answer": correct_answer,
		"choices": build_choices(correct_answer, distractors),
	}


func _max_value_for_difficulty(difficulty: int) -> int:
	return 10 + (difficulty - 1) * 5


func _max_value(difficulty: int, options: Dictionary) -> int:
	return _positive_int_option(options, "max_operand", 2,
		_max_value_for_difficulty(difficulty))
