## Renders the current question text + 4 answer buttons, and emits a
## signal when the player taps one. Does NOT decide correct/incorrect -
## that judgment belongs to whoever owns game state (Main.gd), keeping
## this panel a dumb, reusable display component (Tech Stack §5).
class_name QuestionPanel
extends CanvasLayer

## Emitted whenever any answer button is tapped, with the numeric value
## shown on that button and the exact button tapped. The listener (Main.gd)
## compares it against the active question's correct_answer.
signal answer_selected(value: int, button: Button)

const WRONG_FLASH_SECONDS := 0.18

@onready var _question_label: Label = $Panel/QuestionLabel
@onready var _answer_buttons: Array = [
	$Panel/AnswerButtons/Button1,
	$Panel/AnswerButtons/Button2,
	$Panel/AnswerButtons/Button3,
	$Panel/AnswerButtons/Button4,
]


func _ready() -> void:
	for button in _answer_buttons:
		button.pressed.connect(_on_answer_button_pressed.bind(button))


## Displays a question Dictionary shaped like QuestionStrategy.generate()'s
## return value: { question_text, correct_answer, choices }. `choices` is
## expected to already be shuffled by the strategy/generator.
func set_question(question: Dictionary) -> void:
	_question_label.text = question.get("question_text", "")
	var choices: Array = question.get("choices", [])
	for i in range(_answer_buttons.size()):
		var button: Button = _answer_buttons[i]
		if i < choices.size():
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
	var value: int = int(button.get_meta("value", 0))
	answer_selected.emit(value, button)
