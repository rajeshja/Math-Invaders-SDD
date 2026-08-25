## Integer subtraction category strategy.
##
## Mirrors IntegerAdditionStrategy's structure (Phase 2 §2.3). Guards against
## negative results for the target age group by always picking a >= b.
## Operand ceiling configurable via options["max_operand"] (Phase 9).
class_name IntegerSubtractionStrategy
extends QuestionStrategy


func generate(difficulty: int, options: Dictionary = {}) -> Dictionary:
	var clamped_difficulty: int = max(1, difficulty)
	var max_operand: int = _max_operand(clamped_difficulty, options)

	var a: int = randi_range(1, max_operand)
	var b: int = randi_range(1, max_operand)
	if b > a:
		var tmp := a
		a = b
		b = tmp

	var correct_answer: int = a - b

	var distractors: Array = [
		correct_answer + 1,   # off-by-one
		correct_answer - 1,   # off-by-one
		a + b,                # wrong-operation (added instead)
		correct_answer + 10,
		correct_answer - 10,
	]

	return {
		"question_text": "What is %d - %d?" % [a, b],
		"correct_answer": correct_answer,
		"choices": build_choices(correct_answer, distractors),
	}


func _max_operand_for_difficulty(difficulty: int) -> int:
	return 12 + (difficulty - 1) * 20


func _max_operand(difficulty: int, options: Dictionary) -> int:
	return _positive_int_option(options, "max_operand", 1,
		_max_operand_for_difficulty(difficulty))
