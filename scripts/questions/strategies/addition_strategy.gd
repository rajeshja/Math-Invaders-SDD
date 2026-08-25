## Addition category strategy.
##
## Stage A (difficulty 1): 1-2 digit operands.
## Stage B (difficulty >= 2): operand range widens toward 2-3 digits, per
## Spec §5 "Expanded difficulty". The operand ceiling can also be pinned
## explicitly by a LevelConfig resource via options["max_operand"]
## (Phase 9 FR9.3/FR9.4), which takes precedence over the curve.
class_name AdditionStrategy
extends QuestionStrategy


func generate(difficulty: int, options: Dictionary = {}) -> Dictionary:
	var clamped_difficulty: int = max(1, difficulty)
	var max_operand: int = _max_operand(clamped_difficulty, options)

	var a: int = randi_range(1, max_operand)
	var b: int = randi_range(1, max_operand)
	var correct_answer: int = a + b

	var distractors: Array = [
		correct_answer + 1,          # off-by-one
		correct_answer - 1,          # off-by-one
		abs(a - b),                  # wrong-operation (subtracted instead)
		correct_answer + 10,         # digit-slip style mistake
		correct_answer - 10,
	]

	return {
		"question_text": "What is %d + %d?" % [a, b],
		"correct_answer": correct_answer,
		"choices": build_choices(correct_answer, distractors),
	}


func _max_operand_for_difficulty(difficulty: int) -> int:
	# difficulty 1 -> up to 12 (1-2 digit feel), scaling up from there.
	return 12 + (difficulty - 1) * 20


func _max_operand(difficulty: int, options: Dictionary) -> int:
	return _positive_int_option(options, "max_operand", 1,
		_max_operand_for_difficulty(difficulty))
