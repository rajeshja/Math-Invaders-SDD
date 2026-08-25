## Full-screen Game Over overlay (Phase 4 FR4.8, extended in Phase 7 and
## Phase 9). Shown once when GameManager emits game_over; displays the
## final score, a reason line ("Out of lives!" / "Time's up!"), and either
## a "New High Score!" callout or the persisted high score with its
## holder's name (FR9.11).
##
## Buttons: Play Again restarts the session at the SAME starting level
## (FR9.18 - Main.restart_session() owns what happens next), Review
## Mistakes opens the scrollable ReviewPanel with this session's wrong
## answers (FR9.16/FR9.17), and Main Menu navigates back to level select
## (FR9.19). Otherwise a dumb display component.
class_name GameOverOverlay
extends CanvasLayer

signal play_again_pressed
signal return_to_menu_pressed

const NEW_RECORD_COLOR := Color(1.0, 0.84, 0.25, 1.0)
const HIGH_SCORE_COLOR := Color(0.82, 0.88, 1.0, 1.0)

var _current_mistakes: Array[Dictionary] = []

@onready var _score_label: Label = $Backdrop/Center/Rows/ScoreLabel
@onready var _reason_label: Label = $Backdrop/Center/Rows/ReasonLabel
@onready var _high_score_label: Label = $Backdrop/Center/Rows/HighScoreLabel
@onready var _play_again_button: Button = $Backdrop/Center/Rows/PlayAgainButton
@onready var _review_mistakes_button: Button = $Backdrop/Center/Rows/ReviewMistakesButton
@onready var _return_to_menu_button: Button = $Backdrop/Center/Rows/ReturnToMenuButton
@onready var _review_panel: ReviewPanel = $ReviewPanel


func _ready() -> void:
	visible = false
	_play_again_button.pressed.connect(_on_play_again_pressed)
	_review_mistakes_button.pressed.connect(_on_review_mistakes_pressed)
	_return_to_menu_button.pressed.connect(func(): return_to_menu_pressed.emit())


## `new_record` is HighScoreManager.save_if_higher()'s return value and
## `high_score`/`holder_name` are read AFTER that call (FR7.5/FR7.6/
## FR9.11). `mistakes` is the session's capped MistakeTracker list.
func show_game_over(final_score: int, reason_text: String, new_record: bool,
		high_score: int, holder_name: String,
		mistakes: Array[Dictionary] = []) -> void:
	_current_mistakes = mistakes.duplicate()
	_score_label.text = "Final Score: %d" % final_score
	_reason_label.text = reason_text
	if new_record:
		_high_score_label.text = "New High Score!"
		_high_score_label.add_theme_color_override("font_color", NEW_RECORD_COLOR)
	elif holder_name.is_empty():
		_high_score_label.text = "High Score: %d" % high_score
		_high_score_label.add_theme_color_override("font_color", HIGH_SCORE_COLOR)
	else:
		_high_score_label.text = "High Score: %d  -  %s" % [high_score, holder_name]
		_high_score_label.add_theme_color_override("font_color", HIGH_SCORE_COLOR)
	_review_panel.visible = false
	visible = true


func hide_overlay() -> void:
	visible = false
	_review_panel.visible = false


func _on_play_again_pressed() -> void:
	play_again_pressed.emit()


func _on_review_mistakes_pressed() -> void:
	_review_panel.show_mistakes(_current_mistakes)
