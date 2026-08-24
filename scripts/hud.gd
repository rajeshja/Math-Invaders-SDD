## Updates the HUD's score and wave-progress displays in response to
## Main.gd/WaveManager signals (Tech Stack §5).
##
## Level/Health/Lives displays are placeholder nodes for now (their real
## wiring lands in Phase 4/5) so the scene structure already matches
## Tech Stack §2 without those systems needing to restructure the HUD
## scene when they arrive.
class_name Hud
extends CanvasLayer

@onready var _score_label: Label = $ScoreLabel
@onready var _wave_progress_label: Label = $WaveProgressLabel

var _score: int = 0


func _ready() -> void:
	_render_score()


func add_score(amount: int = 1) -> void:
	_score += amount
	_render_score()


func _render_score() -> void:
	_score_label.text = "Score: %d" % _score


## category e.g. "subtraction", remaining/total e.g. 6/10 -> renders
## "Subtraction 6/10 remaining" (Spec §6).
func update_wave_progress(category: String, remaining: int, total: int) -> void:
	var display_category: String = category.capitalize()
	_wave_progress_label.text = "%s %d/%d remaining" % [display_category, remaining, total]
