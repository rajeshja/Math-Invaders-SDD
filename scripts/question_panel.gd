## Renders the current question text + 4 answer buttons, and emits a
## signal when the player taps one. Does NOT decide correct/incorrect -
## that judgment belongs to whoever owns game state (Main.gd), keeping
## this panel a dumb, reusable display component (Tech Stack §5).
class_name QuestionPanel
extends CanvasLayer

## Emitted whenever any answer button is tapped, with the numeric value
## shown on that button. The listener (Main.gd) compares it against the
## active question's correct_answer.
signal answer_selected(value: int)

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


func _on_answer_button_pressed(button: Button) -> void:
	var value: int = int(button.get_meta("value", 0))
	answer_selected.emit(value)
