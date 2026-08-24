## Tracks attempts used for the currently displayed question.
## This intentionally has no scene-tree dependency so the default and
## multi-attempt rules can be tested without loading Main.tscn.
class_name QuestionAttemptTracker
extends RefCounted

var attempt_limit: int = 1
var attempts_used: int = 0


func configure(limit: int) -> void:
	attempt_limit = max(1, limit)
	reset_question()


func reset_question() -> void:
	attempts_used = 0


func record_wrong_attempt() -> bool:
	attempts_used += 1
	return attempts_used >= attempt_limit
