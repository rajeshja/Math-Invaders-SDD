## In-memory log of the player's incorrect answers for the CURRENT session
## (Phase 9 FR9.15): question text, tapped wrong answer, correct answer.
##
## Deliberately scene-tree-free (mirrors QuestionAttemptTracker) so the
## cap behavior is unit-testable without loading Main.tscn. Entries are
## capped at MAX_MISTAKES - the OLDEST mistakes are dropped first so long
## sessions cannot grow memory unbounded; "last 100 mistakes" are what
## survive for review.
class_name MistakeTracker
extends RefCounted

const MAX_MISTAKES := 100

var _mistakes: Array[Dictionary] = []


## Records one wrong answer. `question` is the full question Dictionary
## as generated; only its display fields are kept.
func add_mistake(question: Dictionary, selected_answer: int, correct_answer: int) -> void:
	_mistakes.append({
		"question_text": str(question.get("question_text", "")),
		"selected_answer": selected_answer,
		"correct_answer": correct_answer,
	})
	while _mistakes.size() > MAX_MISTAKES:
		_mistakes.pop_front()


func get_mistakes() -> Array[Dictionary]:
	return _mistakes.duplicate()


func mistake_count() -> int:
	return _mistakes.size()


## A new session ("Play Again") starts with an empty review list (FR9.15:
## tracking covers "the current session").
func clear() -> void:
	_mistakes.clear()
