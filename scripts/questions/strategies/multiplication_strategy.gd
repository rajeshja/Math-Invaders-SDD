## Multiplication category strategy.
##
## Stage A: small factors (per Build Plan Phase 3 / Tech Stack §3).
## Registered in question_generator.gd alongside addition/subtraction with
## no changes required to either of those files (Phase 3 FR3.5).
## Factor ceiling configurable via options["max_operand"] (Phase 9).
class_name MultiplicationStrategy
extends QuestionStrategy


func generate(difficulty: int, options: Dictionary = {}) -> Dictionary:
	var clamped_difficulty: int = max(1, difficulty)
	var max_factor: int = _max_factor(clamped_difficulty, options)

	var a: int = randi_range(1, max_factor)
	var b: int = randi_range(1, max_factor)
	var correct_answer: int = a * b

	var distractors: Array = [
		a * (b + 1),          # off-by-one-factor
		a * max(b - 1, 0),
		(a + 1) * b,
		a + b,                 # addition-instead-of-multiplication mistake
		correct_answer + a,
	]

	return {
		"question_text": "What is %d x %d?" % [a, b],
		"correct_answer": correct_answer,
		"choices": build_choices(correct_answer, distractors),
	}


func _max_factor_for_difficulty(difficulty: int) -> int:
	# difficulty 1 -> factors up to 10 (small-factor Stage A feel).
	return 10 + (difficulty - 1) * 5


func _max_factor(difficulty: int, options: Dictionary) -> int:
	return _positive_int_option(options, "max_operand", 1,
		_max_factor_for_difficulty(difficulty))
