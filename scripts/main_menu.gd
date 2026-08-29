## Main Menu (Phase 9 FR9.6/FR9.10/FR9.11): name entry, level select
## populated up to the player's unlocked level, and the persisted high
## score with its holder's name.
##
## Start hands off via GameManager.pending_start_level, which Main.gd
## consumes when the game scene loads - this scene never touches gameplay
## state directly.
##
## Phase 10 FR9.8 polish (all presentational): the level select is a grid
## of per-level buttons where locked levels are grayed out and disabled
## while unlocked ones are full color; the menu slides in on open; level
## buttons get distinct hover/click sounds; and a celebratory fanfare
## plays when the player arrives with a newly unlocked level. The
## "celebrated already?" marker lives in a local ConfigFile so
## HighScoreManager stays untouched (NFR9.1).
class_name MainMenu
extends Control

const GAME_SCENE := "res://scenes/main.tscn"
const NAME_CHARACTER_LIMIT := 20
const MENU_STATE_PATH := "user://menu_state.cfg"
const SLIDE_IN_SECONDS := 0.35
const SLIDE_IN_OFFSET := 90.0
const LOCKED_COLOR := Color(0.55, 0.57, 0.66, 1.0)
const UNLOCKED_COLOR := Color(1, 1, 1, 1)

@onready var _name_edit: LineEdit = $Center/Rows/NameCard/NameRows/NameEdit
@onready var _level_grid: GridContainer = $Center/Rows/LevelCard/LevelRows/LevelGrid
@onready var _high_score_label: Label = $Center/Rows/HighScoreLabel
@onready var _top_scores_label: Label = $Center/Rows/TopScoresLabel
@onready var _start_button: Button = $Center/Rows/StartButton
@onready var _center: CenterContainer = $Center


func _ready() -> void:
	_name_edit.text = HighScoreManager.get_last_player_name()
	_name_edit.placeholder_text = "Enter your name"
	_name_edit.max_length = NAME_CHARACTER_LIMIT
	# FR22.2: the name in the field selects the active profile, so the grid
	# below reflects that player's unlocked levels (blank keeps last-used).
	HighScoreManager.set_active_player_name(_name_edit.text)
	_populate_level_grid()
	_update_high_score_label()
	_update_top_scores_label()
	_start_button.pressed.connect(_on_start_pressed)
	_name_edit.text_submitted.connect(func(_text: String): _on_start_pressed())
	_name_edit.text_changed.connect(_on_name_changed)
	_play_unlock_fanfare_if_new()
	_animate_slide_in()


## FR22.2: typing a name previews that player's unlocked levels before
## START commits the profile. Previewing never creates a profile.
func _on_name_changed(_text: String) -> void:
	HighScoreManager.set_active_player_name(_name_edit.text)
	_populate_level_grid()
	_update_top_scores_label()


## FR9.8: locked levels render grayed out + disabled; unlocked ones are
## full color and start their level directly when tapped.
func _populate_level_grid() -> void:
	for child in _level_grid.get_children():
		child.free()
	var unlocked: int = HighScoreManager.get_unlocked_level()
	var total: int = LevelConfig.total_level_count()
	for level in range(1, total + 1):
		var button := Button.new()
		button.custom_minimum_size = Vector2(168, 110)
		button.add_theme_font_size_override("font_size", 28)
		if level <= unlocked:
			button.text = "Level %d" % level
			button.modulate = UNLOCKED_COLOR
			button.pressed.connect(_on_level_button_pressed.bind(level))
			button.mouse_entered.connect(_on_level_button_hovered)
		else:
			button.text = "Level %d\nLOCKED" % level
			button.modulate = LOCKED_COLOR
			button.disabled = true
		_level_grid.add_child(button)


func _on_level_button_pressed(level: int) -> void:
	AudioManager.play_sfx("click")
	_start_game_at(level)


func _on_level_button_hovered() -> void:
	AudioManager.play_sfx("hover", -6.0)


func _update_high_score_label() -> void:
	var high_score: int = HighScoreManager.get_high_score()
	var holder: String = HighScoreManager.get_player_name()
	if holder.is_empty():
		_high_score_label.text = "High Score: %d" % high_score
	else:
		_high_score_label.text = "High Score: %d  -  %s" % [high_score, holder]


## FR22.6: the active player's best 3 session scores, shown under the high
## score and refreshed as the name field previews different profiles.
func _update_top_scores_label() -> void:
	var top: Array = HighScoreManager.get_top_scores()
	if top.is_empty():
		_top_scores_label.text = "Best Scores: -"
		return
	var parts: Array[String] = []
	for score: int in top:
		parts.append(str(score))
	_top_scores_label.text = "Best Scores: %s" % ", ".join(parts)


## START continues at the highest unlocked level; the level grid above is
## the explicit per-level choice (replacing Phase 9's OptionButton select).
func _on_start_pressed() -> void:
	HighScoreManager.set_player_name(_name_edit.text)
	AudioManager.play_sfx("click")
	_start_game_at(HighScoreManager.get_unlocked_level())


func _start_game_at(level: int) -> void:
	HighScoreManager.set_player_name(_name_edit.text)
	GameManager.pending_start_level = level
	get_tree().change_scene_to_file(GAME_SCENE)


## FR9.8: celebratory sound the first time the menu is opened after a new
## level unlocked. Marker is local to the menu; HighScoreManager untouched.
func _play_unlock_fanfare_if_new() -> void:
	var config := ConfigFile.new()
	config.load(MENU_STATE_PATH)
	var celebrated: int = maxi(1, int(config.get_value("progress", "celebrated_unlock", 1)))
	var unlocked: int = HighScoreManager.get_unlocked_level()
	if unlocked > celebrated:
		AudioManager.play_sfx("unlock")
		config.set_value("progress", "celebrated_unlock", unlocked)
		config.save(MENU_STATE_PATH)


## FR9.8: the menu slides up + fades in when it opens.
func _animate_slide_in() -> void:
	var target := _center.position
	_center.position = target + Vector2(0, SLIDE_IN_OFFSET)
	_center.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_center, "position", target, SLIDE_IN_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_center, "modulate:a", 1.0, SLIDE_IN_SECONDS)
