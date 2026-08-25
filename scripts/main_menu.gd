## Main Menu (Phase 9 FR9.6/FR9.10/FR9.11): name entry, level select
## populated up to the player's unlocked level, and the persisted high
## score with its holder's name.
##
## Start hands off via GameManager.pending_start_level, which Main.gd
## consumes when the game scene loads - this scene never touches gameplay
## state directly.
class_name MainMenu
extends Control

const GAME_SCENE := "res://scenes/main.tscn"
const NAME_CHARACTER_LIMIT := 20

@onready var _name_edit: LineEdit = $Center/Rows/NameCard/NameRows/NameEdit
@onready var _level_select: OptionButton = $Center/Rows/LevelCard/LevelRows/LevelSelect
@onready var _high_score_label: Label = $Center/Rows/HighScoreLabel
@onready var _start_button: Button = $Center/Rows/StartButton


func _ready() -> void:
	_name_edit.text = HighScoreManager.get_player_name()
	_name_edit.placeholder_text = "Enter your name"
	_name_edit.max_length = NAME_CHARACTER_LIMIT
	_populate_level_select()
	_update_high_score_label()
	_start_button.pressed.connect(_on_start_pressed)
	_name_edit.text_submitted.connect(func(_text: String): _on_start_pressed())


func _populate_level_select() -> void:
	_level_select.clear()
	var unlocked: int = HighScoreManager.get_unlocked_level()
	var selectable: int = mini(unlocked, LevelConfig.total_level_count())
	for level in range(1, max(1, selectable) + 1):
		_level_select.add_item("Level %d" % level, level)
	_level_select.select(0)


func _update_high_score_label() -> void:
	var high_score: int = HighScoreManager.get_high_score()
	var holder: String = HighScoreManager.get_player_name()
	if holder.is_empty():
		_high_score_label.text = "High Score: %d" % high_score
	else:
		_high_score_label.text = "High Score: %d  -  %s" % [high_score, holder]


func _selected_start_level() -> int:
	return maxi(1, _level_select.get_selected_id())


func _on_start_pressed() -> void:
	HighScoreManager.set_player_name(_name_edit.text)
	GameManager.pending_start_level = _selected_start_level()
	get_tree().change_scene_to_file(GAME_SCENE)
