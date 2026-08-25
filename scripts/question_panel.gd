## Renders the current question text + 4 answer buttons, and emits a
## signal when the player taps one. Does NOT decide correct/incorrect -
## that judgment belongs to whoever owns game state (Main.gd), keeping
## this panel a dumb, reusable display component (Tech Stack §5).
##
## Phase 13 (FR13.3--FR13.5): when a question carries optional stacking
## data, fractions render STACKED - numerator above a bar above
## denominator - in both the question area and every answer button:
##   question_segments: Array of either {"text": String} or
##     {"fraction": {whole?, numerator, denominator}} entries read left
##     to right; absent -> plain-text Label path (integer categories).
##   answer_layout: Array parallel to `choices`; an entry is either null
##     /int (plain text button) or the same fraction Dictionary shape.
## All widget children use mouse_filter = IGNORE so taps, theme styleboxes,
## and the wrong-answer flash keep working exactly as before.
class_name QuestionPanel
extends CanvasLayer

## Emitted whenever any answer button is tapped, with the value shown on
## that button (an int for integer categories, or the canonical String
## form for fraction categories - Phase 13 FR13.1) and the exact button
## tapped. The listener (Main.gd) compares it against the active
## question's correct_answer.
signal answer_selected(value, button)

const WRONG_FLASH_SECONDS := 0.18

## Phase 11 FR10.4: base design height of the panel (matches the
## offset_top = -360 anchor layout in question_panel.tscn).
const PANEL_HEIGHT := 360.0

## Stacked-fraction sizing (FR13.5): must fit inside the existing 320x110
## button footprint and the 60px question row at 720x1280.
const BAR_COLOR := Color(0.875, 0.875, 0.875, 1.0)
const STACK_FONT_LARGE := 34
const STACK_FONT_SMALL := 26
const QUESTION_STACK_FONT := 20
const QUESTION_WHOLE_FONT := 18

@onready var _question_label: Label = $Panel/QuestionLabel
@onready var _panel: Control = $Panel
@onready var _answer_buttons: Array = [
	$Panel/AnswerButtons/Button1,
	$Panel/AnswerButtons/Button2,
	$Panel/AnswerButtons/Button3,
	$Panel/AnswerButtons/Button4,
]

## Code-built host for stacked question rendering; shares the
## QuestionLabel's rect and only shows for fraction questions.
var _question_stack_host: HBoxContainer = null


func _ready() -> void:
	for button in _answer_buttons:
		button.pressed.connect(_on_answer_button_pressed.bind(button))
	_build_question_stack_host()
	_apply_safe_area()


## Phase 11 FR10.4: on mobile devices, lift the whole panel above the
## home-indicator/gesture-bar region and inset it away from rounded
## screen corners, keeping every answer button fully visible and tappable.
## No-op on desktop (zero insets), so editor behavior is unchanged.
func _apply_safe_area() -> void:
	var insets := SafeArea.get_canvas_insets(self)
	if insets.left == 0.0 and insets.top == 0.0 \
			and insets.right == 0.0 and insets.bottom == 0.0:
		return
	_panel.offset_top = -PANEL_HEIGHT - insets.bottom
	_panel.offset_bottom = -insets.bottom
	_panel.offset_left = insets.left
	_panel.offset_right = -insets.right


## Displays a question Dictionary shaped like QuestionStrategy.generate()'s
## return value: { question_text, correct_answer, choices }. `choices` is
## expected to already be shuffled by the strategy/generator. Optional
## `question_segments` / `answer_layout` switch the panel into stacked-
## fraction rendering (Phase 13 FR13.3); absent keys leave the plain-text
## path used by integer categories untouched.
func set_question(question: Dictionary) -> void:
	var segments: Array = question.get("question_segments", [])
	if segments.is_empty():
		_question_label.visible = true
		if _question_stack_host != null:
			_question_stack_host.visible = false
		_question_label.text = question.get("question_text", "")
	else:
		_question_label.visible = false
		_question_stack_host.visible = true
		_render_question_segments(segments)

	var choices: Array = question.get("choices", [])
	var layouts: Array = question.get("answer_layout", [])
	for i in range(_answer_buttons.size()):
		var button: Button = _answer_buttons[i]
		_clear_button_stack(button)
		if i < choices.size():
			var layout: Variant = layouts[i] if i < layouts.size() else null
			if layout is Dictionary:
				button.text = ""
				button.add_child(_build_button_stack(layout))
			else:
				button.text = str(choices[i])
			button.set_meta("value", choices[i])
			button.disabled = false
		else:
			button.text = ""
			button.disabled = true


func set_answer_buttons_enabled(enabled: bool) -> void:
	for button in _answer_buttons:
		button.disabled = not enabled or not button.has_meta("value")


## Starts the wrong-answer red flash on the tapped button and returns
## immediately - callers must NOT await this function. The styleboxes
## restore themselves after WRONG_FLASH_SECONDS. Gameplay code awaits
## wait_wrong_feedback() instead, so answer resolution stays decoupled
## from (and parallel to) every bullet animation.
func flash_wrong_answer(button: Button) -> void:
	if button == null:
		return

	var original_styles := {
		"normal": button.get_theme_stylebox("normal"),
		"hover": button.get_theme_stylebox("hover"),
		"pressed": button.get_theme_stylebox("pressed"),
		"focus": button.get_theme_stylebox("focus"),
	}
	var flash_style := StyleBoxFlat.new()
	flash_style.bg_color = Color(0.9, 0.1, 0.1, 1.0)
	flash_style.border_color = Color(1.0, 0.75, 0.75, 1.0)
	flash_style.set_border_width_all(4)
	flash_style.corner_radius_top_left = 10
	flash_style.corner_radius_top_right = 10
	flash_style.corner_radius_bottom_left = 10
	flash_style.corner_radius_bottom_right = 10

	set_answer_buttons_enabled(false)
	for style_name in original_styles.keys():
		button.add_theme_stylebox_override(style_name, flash_style)

	get_tree().create_timer(WRONG_FLASH_SECONDS).timeout.connect(
		_restore_flash_styles.bind(button, original_styles), CONNECT_ONE_SHOT)


## Awaitable that resolves once the wrong-answer feedback interval has
## elapsed - the only thing question advancement may ever wait on. It is
## deliberately NOT tied to any bullet's flight time.
func wait_wrong_feedback() -> void:
	await get_tree().create_timer(WRONG_FLASH_SECONDS).timeout


func _restore_flash_styles(button: Button, original_styles: Dictionary) -> void:
	if not is_instance_valid(button):
		return
	for style_name in original_styles.keys():
		button.add_theme_stylebox_override(style_name, original_styles[style_name])


func _on_answer_button_pressed(button: Button) -> void:
	# Raw meta value: int for integer categories, canonical String for
	# fraction categories (Phase 13 FR13.1). No casting.
	var value = button.get_meta("value", 0)
	answer_selected.emit(value, button)


## -- Stacked fraction rendering (Phase 13 FR13.3-FR13.5) -------------------

func _build_question_stack_host() -> void:
	_question_stack_host = HBoxContainer.new()
	_question_stack_host.alignment = BoxContainer.ALIGNMENT_CENTER
	_question_stack_host.add_theme_constant_override("separation", 8)
	_question_stack_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_question_stack_host.visible = false
	_panel.add_child(_question_stack_host)
	# Mirror the QuestionLabel's rect (anchors_preset top-wide, y 16..76).
	_question_stack_host.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_question_stack_host.offset_top = 16.0
	_question_stack_host.offset_bottom = 76.0
	_question_stack_host.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _render_question_segments(segments: Array) -> void:
	for child in _question_stack_host.get_children():
		child.free()
	for segment in segments:
		if segment is Dictionary and segment.has("fraction"):
			_question_stack_host.add_child(
				_build_fraction_control(segment.fraction, QUESTION_STACK_FONT))
		else:
			var label := Label.new()
			label.text = str(segment.get("text", "")) if segment is Dictionary else str(segment)
			label.add_theme_font_size_override("font_size", QUESTION_STACK_FONT + 12)
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_question_stack_host.add_child(label)


## Builds the centered stacked-fraction control hosted inside an answer
## button: [whole] [numerator / bar / denominator], all mouse-transparent
## so the parent Button keeps every tap (FR13.4).
func _build_button_stack(layout: Dictionary) -> Control:
	return _build_fraction_control(layout, STACK_FONT_LARGE)


func _build_fraction_control(layout: Dictionary, base_font_size: int) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var font_size := base_font_size
	var whole_font := base_font_size - 4
	if base_font_size >= STACK_FONT_LARGE:
		var longest: int = maxi(
			str(int(layout.get("numerator", 0))).length(),
			str(int(layout.get("denominator", 1))).length())
		if layout.has("whole"):
			longest = maxi(longest, str(int(layout.get("whole", 0))).length())
		if longest > 2:
			font_size = STACK_FONT_SMALL
			whole_font = STACK_FONT_SMALL - 4

	if layout.has("whole"):
		var whole_label := Label.new()
		whole_label.text = str(int(layout.get("whole", 0)))
		whole_label.add_theme_font_size_override("font_size", whole_font)
		whole_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		whole_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(whole_label)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var numerator := Label.new()
	numerator.text = str(int(layout.get("numerator", 0)))
	numerator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	numerator.add_theme_font_size_override("font_size", font_size)
	numerator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(numerator)

	var bar := ColorRect.new()
	bar.color = BAR_COLOR
	bar.custom_minimum_size = Vector2(0, 3 if base_font_size >= STACK_FONT_LARGE else 2)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(bar)

	var denominator := Label.new()
	denominator.text = str(int(layout.get("denominator", 1)))
	denominator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	denominator.add_theme_font_size_override("font_size", font_size)
	denominator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(denominator)

	row.add_child(stack)
	return row


## Removes any previously attached stacked content so plain-text questions
## render exactly as they did before Phase 13.
func _clear_button_stack(button: Button) -> void:
	for child in button.get_children():
		child.free()
