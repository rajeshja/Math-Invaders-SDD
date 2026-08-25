## Full-screen Game Over overlay (Phase 4 FR4.8, extended in Phase 7).
## Shown once when GameManager emits game_over; displays the final score, a
## reason line ("Out of lives!" / "Time's up!"), and either a "New High
## Score!" callout or the current persisted high score (FR7.6). The Play
## Again button emits play_again_pressed; Main.restart_session() owns what
## happens next - this overlay is a dumb display component.
class_name GameOverOverlay
extends CanvasLayer

signal play_again_pressed

const NEW_RECORD_COLOR := Color(1.0, 0.84, 0.25, 1.0)
const HIGH_SCORE_COLOR := Color(0.82, 0.88, 1.0, 1.0)

@onready var _score_label: Label = $Backdrop/Center/Rows/ScoreLabel
@onready var _reason_label: Label = $Backdrop/Center/Rows/ReasonLabel
@onready var _high_score_label: Label = $Backdrop/Center/Rows/HighScoreLabel
@onready var _play_again_button: Button = $Backdrop/Center/Rows/PlayAgainButton


func _ready() -> void:
	visible = false
	_play_again_button.pressed.connect(_on_play_again_pressed)


## `new_record` is HighScoreManager.save_if_higher()'s return value and
## `high_score` the persisted value read AFTER that call (FR7.5/FR7.6).
func show_game_over(final_score: int, reason_text: String, new_record: bool, high_score: int) -> void:
	_score_label.text = "Final Score: %d" % final_score
	_reason_label.text = reason_text
	if new_record:
		_high_score_label.text = "New High Score!"
		_high_score_label.add_theme_color_override("font_color", NEW_RECORD_COLOR)
	else:
		_high_score_label.text = "High Score: %d" % high_score
		_high_score_label.add_theme_color_override("font_color", HIGH_SCORE_COLOR)
	visible = true


func hide_overlay() -> void:
	visible = false


func _on_play_again_pressed() -> void:
	play_again_pressed.emit()
