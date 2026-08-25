## Updates the HUD's score and wave-progress displays in response to
## Main.gd/WaveManager signals (Tech Stack §5).
##
## Lives and time are driven by GameManager signals.
class_name Hud
extends CanvasLayer

const LIFE_ICON: Texture2D = preload("res://assets/images/ui/life_icon.png")

## Phase 10 FR9.7: when time_remaining drops to this many seconds or less,
## TimeLabel pulses red with a per-second tick. A code constant (NOT a
## Project Setting) per spec; purely presentational - it must never alter
## timer behavior or gameplay state.
const LOW_TIME_WARNING_SECONDS := 10.0
const WARNING_COLOR := Color(1.0, 0.22, 0.2, 1.0)
const NORMAL_COLOR := Color(1, 1, 1, 1)
const PULSE_SPEED := 0.012

@onready var _score_label: Label = $ScoreLabel
@onready var _level_label: Label = $LevelLabel
@onready var _time_label: Label = $TimeLabel
@onready var _wave_progress_label: Label = $WaveProgressLabel
@onready var _lives_display: HBoxContainer = $LivesDisplay

var _score: int = 0
var _warning_active: bool = false
var _last_tick_second: int = -1


func _ready() -> void:
	_render_score()
	_apply_safe_area()
	GameManager.game_over.connect(_stop_low_time_warning)


## Phase 11 FR10.4: on mobile devices, shift the top HUD out of notch /
## rounded-corner / camera-cut regions so it is never obscured. No-op on
## desktop (SafeArea returns zero insets there), keeping editor behavior
## unchanged.
func _apply_safe_area() -> void:
	var insets := SafeArea.get_canvas_insets(self)
	if insets.left == 0.0 and insets.top == 0.0 \
			and insets.right == 0.0 and insets.bottom == 0.0:
		return
	for child in get_children():
		if child is Control:
			child.offset_top += insets.top
			child.offset_bottom += insets.top
	_score_label.offset_left += insets.left
	_score_label.offset_right += insets.left
	_wave_progress_label.offset_left += insets.left
	_wave_progress_label.offset_right -= insets.right
	_level_label.offset_left -= insets.right
	_level_label.offset_right -= insets.right
	_lives_display.offset_left -= insets.right
	_lives_display.offset_right -= insets.right


func _process(_delta: float) -> void:
	if not _warning_active:
		return
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * PULSE_SPEED)
	_time_label.modulate = NORMAL_COLOR.lerp(WARNING_COLOR, 0.35 + 0.65 * pulse)
	_time_label.pivot_offset = _time_label.size / 2.0
	var s := 1.0 + 0.08 * pulse
	_time_label.scale = Vector2(s, s)


func add_score(amount: int = 1) -> void:
	_score += amount
	_render_score()


func update_score(score: int) -> void:
	_score = score
	_render_score()


func update_level(level: int) -> void:
	_level_label.text = "Level: %d" % level


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
	_update_low_time_warning(seconds_remaining, display_seconds)


## FR9.7: purely presentational low-time warning. Starts pulsing + ticking
## at the 10-second mark, stops at zero (game over fires), when a new
## level's timer resets the value upward, or when Game Over arrives via
## any cause. Never touches GameManager.
func _update_low_time_warning(seconds_remaining: float, display_seconds: int) -> void:
	var in_window: bool = GameManager.is_playing() \
			and seconds_remaining > 0.0 \
			and seconds_remaining <= LOW_TIME_WARNING_SECONDS
	if not in_window:
		if _warning_active:
			_stop_low_time_warning()
		return
	if not _warning_active:
		_warning_active = true
		_last_tick_second = display_seconds
	if display_seconds < _last_tick_second:
		_last_tick_second = display_seconds
		if display_seconds >= 1:
			AudioManager.play_sfx("tick")


func _stop_low_time_warning() -> void:
	_warning_active = false
	_last_tick_second = -1
	_time_label.modulate = NORMAL_COLOR
	_time_label.scale = Vector2.ONE


func _render_score() -> void:
	_score_label.text = "Score: %d" % _score


## category e.g. "integer_subtraction", remaining/total e.g. 6/10 ->
## renders "Subtraction 6/10 remaining" (Spec §6). Labels resolve through
## QuestionGenerator's display-name registry (Phase 12 FR12.4).
func update_wave_progress(category: String, remaining: int, total: int) -> void:
	var display_category: String = QuestionGenerator.get_display_name(category)
	_wave_progress_label.text = "%s %d/%d remaining" % [display_category, remaining, total]
