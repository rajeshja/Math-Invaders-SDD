## Scrollable Mistake Review panel (Phase 9 FR9.17 / NFR9.2).
##
## A dumb display component: GameOverOverlay hands it the session's
## capped mistake list; it renders one row per mistake inside a
## ScrollContainer so arbitrary counts work on small screens.
##
## Phase 10 FR9.8 polish (all presentational): the panel slides up over
## the Game Over screen with a paper-sliding sound, plays the same sound
## (in reverse spirit) on close, and emits soft UI ticks while the list
## scrolls.
class_name ReviewPanel
extends Control

signal closed

const OPEN_SECONDS := 0.3
const CLOSE_SECONDS := 0.22
const SLIDE_DISTANCE := 260.0
const SCROLL_TICK_MIN_INTERVAL_MS := 90

@onready var _summary_label: Label = $Margin/Rows/SummaryLabel
@onready var _mistakes_list: VBoxContainer = $Margin/Rows/Scroll/MistakesList
@onready var _close_button: Button = $Margin/Rows/CloseButton
@onready var _scroll: ScrollContainer = $Margin/Rows/Scroll
@onready var _margin: MarginContainer = $Margin
@onready var _dim: ColorRect = $Dim

var _anim: Tween = null
var _last_scroll_tick_ms: int = 0


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(_on_close_pressed)
	_scroll.get_v_scroll_bar().value_changed.connect(_on_scrolled)
	_apply_safe_area()


## Phase 11 FR10.4: on mobile devices, pad the review panel's margins out
## by the display safe area so the Close button and list rows are never
## under the home-indicator/gesture-bar region or clipped by rounded
## corners. No-op on desktop (zero insets).
func _apply_safe_area() -> void:
	var insets := SafeArea.get_canvas_insets(self)
	if insets.left == 0.0 and insets.top == 0.0 \
			and insets.right == 0.0 and insets.bottom == 0.0:
		return
	_margin.add_theme_constant_override("margin_left",
			_margin.get_theme_constant("margin_left") + int(insets.left))
	_margin.add_theme_constant_override("margin_right",
			_margin.get_theme_constant("margin_right") + int(insets.right))
	_margin.add_theme_constant_override("margin_bottom",
			_margin.get_theme_constant("margin_bottom") + int(insets.bottom))


## Populates and opens the panel. Each entry is a Dictionary shaped like
## MistakeTracker's records:
## { question_text: String, selected_answer: int, correct_answer: int }
func show_mistakes(mistakes: Array[Dictionary]) -> void:
	_clear_rows()
	if mistakes.is_empty():
		_summary_label.text = "No mistakes this session. Great job!"
	else:
		_summary_label.text = "You answered %d question%s wrong:" % [
			mistakes.size(), "" if mistakes.size() == 1 else "s"]
	for i in range(mistakes.size()):
		var entry: Dictionary = mistakes[i]
		var row := Label.new()
		row.text = "%d. %s\n    You picked: %s   |   Correct: %s" % [
			i + 1,
			entry.get("question_text", ""),
			str(entry.get("selected_answer", "")),
			str(entry.get("correct_answer", "")),
		]
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_theme_font_size_override("font_size", 26)
		_mistakes_list.add_child(row)
	_scroll.scroll_vertical = 0
	_animate_open()


func _animate_open() -> void:
	if _anim != null and _anim.is_valid():
		_anim.kill()
	visible = true
	AudioManager.play_sfx("paper")
	var rest_position := _margin.position
	_margin.position = rest_position + Vector2(0, SLIDE_DISTANCE)
	_margin.modulate.a = 0.0
	_dim.modulate.a = 0.0
	_anim = create_tween().set_parallel(true)
	_anim.tween_property(_margin, "position", rest_position, OPEN_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_anim.tween_property(_margin, "modulate:a", 1.0, OPEN_SECONDS)
	_anim.tween_property(_dim, "modulate:a", 1.0, OPEN_SECONDS)


func _animate_close() -> void:
	if _anim != null and _anim.is_valid():
		_anim.kill()
	AudioManager.play_sfx("paper", -4.0)
	_anim = create_tween().set_parallel(true)
	_anim.tween_property(_margin, "position:y", _margin.position.y + SLIDE_DISTANCE,
			CLOSE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_anim.tween_property(_margin, "modulate:a", 0.0, CLOSE_SECONDS)
	_anim.tween_property(_dim, "modulate:a", 0.0, CLOSE_SECONDS)
	_anim.chain().tween_callback(func():
		visible = false
		closed.emit())


func _clear_rows() -> void:
	for child in _mistakes_list.get_children():
		child.free()


func _on_close_pressed() -> void:
	_animate_close()


## FR9.8: soft UI tick while scrolling the mistake list, throttled so fast
## flicks don't machine-gun the cue.
func _on_scrolled(_value: int) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_scroll_tick_ms < SCROLL_TICK_MIN_INTERVAL_MS:
		return
	_last_scroll_tick_ms = now
	AudioManager.play_sfx("scroll_tick")
