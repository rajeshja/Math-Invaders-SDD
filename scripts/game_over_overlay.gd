## Full-screen Game Over overlay (Phase 4 FR4.8, extended in Phase 7, Phase
## 9, and Phase 23). Shown once when GameManager emits game_over; displays
## the final score, a reason line ("Out of lives!" / "Time's up!"), and the
## Phase 23 celebration: a large rank medal + announcement when the score
## lands in the device-wide top 5 (FR23.9), a "Personal Best!" congratulation
## when it beats the player's own best session score (FR23.10), or the
## persisted high score with its holder's name as the fallback (FR23.11).
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
const PERSONAL_BEST_COLOR := Color(0.4, 1.0, 0.6, 1.0)

## Phase 23 FR23.9: rank -> medal texture (all 164x196 under assets/images/ui/).
const MEDAL_TEXTURES := {
	1: preload("res://assets/images/ui/medal-gold.png"),
	2: preload("res://assets/images/ui/medal-silver.png"),
	3: preload("res://assets/images/ui/medal-bronze.png"),
	4: preload("res://assets/images/ui/medal-iron.png"),
	5: preload("res://assets/images/ui/medal-wood.png"),
}

var _current_mistakes: Array[Dictionary] = []

@onready var _score_label: Label = $Backdrop/Center/Rows/ScoreLabel
@onready var _reason_label: Label = $Backdrop/Center/Rows/ReasonLabel
@onready var _medal_icon: TextureRect = $Backdrop/Center/Rows/MedalIcon
@onready var _high_score_label: Label = $Backdrop/Center/Rows/HighScoreLabel
@onready var _personal_best_label: Label = $Backdrop/Center/Rows/PersonalBestLabel
@onready var _play_again_button: Button = $Backdrop/Center/Rows/PlayAgainButton
@onready var _review_mistakes_button: Button = $Backdrop/Center/Rows/ReviewMistakesButton
@onready var _return_to_menu_button: Button = $Backdrop/Center/Rows/ReturnToMenuButton
@onready var _review_panel: ReviewPanel = $ReviewPanel


func _ready() -> void:
	visible = false
	_play_again_button.pressed.connect(_on_play_again_pressed)
	_review_mistakes_button.pressed.connect(_on_review_mistakes_pressed)
	_return_to_menu_button.pressed.connect(func(): return_to_menu_pressed.emit())


## `result` is HighScoreManager.submit_score()'s dictionary
## ({ rank, new_record, beat_personal_best, leaderboard }) read AFTER the
## submission (FR7.5/FR7.6/FR9.11/FR23.2). `mistakes` is the session's
## capped MistakeTracker list.
func show_game_over(final_score: int, reason_text: String, result: Dictionary,
		mistakes: Array[Dictionary] = []) -> void:
	_current_mistakes = mistakes.duplicate()
	_score_label.text = "Final Score: %d" % final_score
	_reason_label.text = reason_text

	var rank: int = result.get("rank", 0)
	var beat_personal_best: bool = result.get("beat_personal_best", false)
	if rank >= 1 and rank <= MEDAL_TEXTURES.size():
		_medal_icon.texture = MEDAL_TEXTURES[rank]
		_medal_icon.visible = true
		if rank == 1:
			_high_score_label.text = "New High Score!"
			_high_score_label.add_theme_color_override("font_color", NEW_RECORD_COLOR)
		else:
			_high_score_label.text = "Top 5! Rank #%d!" % rank
			_high_score_label.add_theme_color_override("font_color", NEW_RECORD_COLOR)
	else:
		_medal_icon.visible = false
		var holder: String = HighScoreManager.get_player_name()
		var high_score: int = HighScoreManager.get_high_score()
		if holder.is_empty():
			_high_score_label.text = "High Score: %d" % high_score
		else:
			_high_score_label.text = "High Score: %d  -  %s" % [high_score, holder]
		_high_score_label.add_theme_color_override("font_color", HIGH_SCORE_COLOR)

	if beat_personal_best:
		_personal_best_label.text = "Personal Best!"
		_personal_best_label.add_theme_color_override("font_color", PERSONAL_BEST_COLOR)
		_personal_best_label.visible = true
	else:
		_personal_best_label.visible = false

	_review_panel.visible = false
	visible = true


func hide_overlay() -> void:
	visible = false
	_review_panel.visible = false


func _on_play_again_pressed() -> void:
	play_again_pressed.emit()


func _on_review_mistakes_pressed() -> void:
	_review_panel.show_mistakes(_current_mistakes)
