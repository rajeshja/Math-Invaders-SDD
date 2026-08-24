## Updates the HUD's score and wave-progress displays in response to
## Main.gd/WaveManager signals (Tech Stack §5).
##
## Level display is still placeholder wiring until Phase 6. Lives and
## time are driven by GameManager signals.
class_name Hud
extends CanvasLayer

const LIFE_ICON: Texture2D = preload("res://assets/images/ui/life_icon.png")

@onready var _score_label: Label = $ScoreLabel
@onready var _time_label: Label = $TimeLabel
@onready var _wave_progress_label: Label = $WaveProgressLabel
@onready var _lives_display: HBoxContainer = $LivesDisplay

var _score: int = 0


func _ready() -> void:
	_render_score()


func add_score(amount: int = 1) -> void:
	_score += amount
	_render_score()


func update_score(score: int) -> void:
	_score = score
	_render_score()


func update_lives(lives: int) -> void:
	for child in _lives_display.get_children():
		child.free()
	for i in range(max(0, lives)):
		var icon := TextureRect.new()
		icon.texture = LIFE_ICON
		icon.custom_minimum_size = Vector2(48, 48)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_lives_display.add_child(icon)


func update_time(seconds_remaining: float) -> void:
	var display_seconds := int(ceil(max(0.0, seconds_remaining)))
	_time_label.text = "Time: %d" % display_seconds


func _render_score() -> void:
	_score_label.text = "Score: %d" % _score


## category e.g. "subtraction", remaining/total e.g. 6/10 -> renders
## "Subtraction 6/10 remaining" (Spec §6).
func update_wave_progress(category: String, remaining: int, total: int) -> void:
	var display_category: String = category.capitalize()
	_wave_progress_label.text = "%s %d/%d remaining" % [display_category, remaining, total]
