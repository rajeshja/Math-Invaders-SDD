## Subtraction category strategy.
##
## Mirrors AdditionStrategy's structure (Phase 2 §2.3). Guards against
## negative results for the target age group by always picking a >= b.
class_name SubtractionStrategy
extends QuestionStrategy


func generate(difficulty: int) -> Dictionary:
	var clamped_difficulty: int = max(1, difficulty)
	var max_operand: int = _max_operand_for_difficulty(clamped_difficulty)

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
