## Full-screen Game Over overlay (Phase 4 FR4.8). Shown once when
## GameManager emits game_over; displays the final score and a reason line
## ("Out of lives!" in Phase 4 - "Time's up!" joins in Phase 5).
##
## Dumb display component: Main.gd maps GameManager.last_game_over_reason
## to the reason text and calls show_game_over(). Game Over is a terminated
## state until an explicit restart action, so there is no dismiss path here
## (full Play Again wiring is deferred to Phase 7).
class_name GameOverOverlay
extends CanvasLayer

@onready var _score_label: Label = $Backdrop/Center/Rows/ScoreLabel
@onready var _reason_label: Label = $Backdrop/Center/Rows/ReasonLabel


func _ready() -> void:
	visible = false


func show_game_over(final_score: int, reason_text: String) -> void:
	_score_label.text = "Final Score: %d" % final_score
	_reason_label.text = reason_text
	visible = true
