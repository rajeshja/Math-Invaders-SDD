## Scrollable Mistake Review panel (Phase 9 FR9.17 / NFR9.2).
##
## A dumb display component: GameOverOverlay hands it the session's
## capped mistake list; it renders one row per mistake inside a
## ScrollContainer so arbitrary counts work on small screens.
class_name ReviewPanel
extends Control

signal closed

@onready var _summary_label: Label = $Margin/Rows/SummaryLabel
@onready var _mistakes_list: VBoxContainer = $Margin/Rows/Scroll/MistakesList
@onready var _close_button: Button = $Margin/Rows/CloseButton


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(_on_close_pressed)


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
	visible = true


func _clear_rows() -> void:
	for child in _mistakes_list.get_children():
		child.free()


func _on_close_pressed() -> void:
	visible = false
	closed.emit()
