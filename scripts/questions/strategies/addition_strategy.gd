## Addition category strategy.
##
## Stage A (difficulty 1): 1-2 digit operands.
## Stage B (difficulty >= 2): operand range widens toward 2-3 digits, per
## Spec §5 "Expanded difficulty". Difficulty scaling is a simple, tunable
## curve for now - LevelManager (Phase 5) is what actually drives
## difficulty upward over time.
class_name AdditionStrategy
extends QuestionStrategy


func generate(difficulty: int) -> Dictionary:
	var clamped_difficulty: int = max(1, difficulty)
	var max_operand: int = _max_operand_for_difficulty(clamped_difficulty)

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
