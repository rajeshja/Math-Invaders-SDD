## Main Menu (Phase 9 FR9.6/FR9.10/FR9.11): name entry, level select
## populated up to the player's unlocked level, the device-wide top-5
## leaderboard with rank medals (Phase 23 FR23.5), and a per-player Profile
## View (Phase 23 FR23.6).
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

## Phase 23 FR23.5: rank -> medal texture for the leaderboard rows.
const MEDAL_TEXTURES := {
	1: preload("res://assets/images/ui/medal-gold.png"),
	2: preload("res://assets/images/ui/medal-silver.png"),
	3: preload("res://assets/images/ui/medal-bronze.png"),
	4: preload("res://assets/images/ui/medal-iron.png"),
	5: preload("res://assets/images/ui/medal-wood.png"),
}

@onready var _name_edit: LineEdit = $Center/Rows/NameCard/NameRows/NameEdit
@onready var _level_grid: GridContainer = $Center/Rows/LevelCard/LevelRows/LevelGrid
@onready var _leaderboard_rows: VBoxContainer = $Center/Rows/LeaderboardCard/LeaderboardRows
@onready var _top_scores_label: Label = $Center/Rows/TopScoresLabel
@onready var _profile_button: Button = $Center/Rows/ProfileButton
@onready var _start_button: Button = $Center/Rows/StartButton
@onready var _center: CenterContainer = $Center
@onready var _profile_panel: PanelContainer = $ProfilePanel
@onready var _profile_name_label: Label = $ProfilePanel/ProfileRows/ProfileNameLabel
@onready var _record_count_label: Label = $ProfilePanel/ProfileRows/RecordCountLabel
@onready var _highest_level_label: Label = $ProfilePanel/ProfileRows/HighestLevelLabel
@onready var _best_scores_label: Label = $ProfilePanel/ProfileRows/BestScoresLabel
@onready var _per_level_bests_label: Label = $ProfilePanel/ProfileRows/PerLevelBestsLabel
@onready var _close_profile_button: Button = $ProfilePanel/ProfileRows/CloseProfileButton


func _ready() -> void:
	_name_edit.text = HighScoreManager.get_last_player_name()
	_name_edit.placeholder_text = "Enter your name"
	_name_edit.max_length = NAME_CHARACTER_LIMIT
	# FR22.2: the name in the field selects the active profile, so the grid
	# below reflects that player's unlocked levels (blank keeps last-used).
	HighScoreManager.set_active_player_name(_name_edit.text)
	_populate_level_grid()
	_populate_leaderboard()
	_update_top_scores_label()
	_start_button.pressed.connect(_on_start_pressed)
	_profile_button.pressed.connect(_on_profile_button_pressed)
	_close_profile_button.pressed.connect(_on_close_profile_pressed)
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
	if _profile_panel.visible:
		_update_profile_panel()


## FR9.8: locked levels render grayed out + disabled; unlocked ones are
## full color and start their level directly when tapped.
func _populate_level_grid() -> void:
	for child in _level_grid.get_children():
		child.free()
	var unlocked: int = HighScoreManager.get_unlocked_level()
	var total: int = LevelConfig.total_level_count()
	for level in range(1, total + 1):
		var button := Button.new()
		button.custom_minimum_size = Vector2(126, 82)
		button.add_theme_font_size_override("font_size", 21)
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


## Phase 23 FR23.5: renders the device-wide top-5 leaderboard as one row
## per entry: rank medal icon + player name + score, descending. Rows are
## compact (60 design px) so all five entries fit on screen: the medal
## renders at 22x26 (50% of the original 44x52) and the row separation is
## 6 px (50% of the original 12 px), keeping the name-score gap tight.
func _populate_leaderboard() -> void:
	for child in _leaderboard_rows.get_children():
		if child.name != "LeaderboardTitle":
			child.free()
	var entries: Array = HighScoreManager.get_leaderboard()
	if entries.is_empty():
		var empty := Label.new()
		empty.text = "No scores yet"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 26)
		_leaderboard_rows.add_child(empty)
		return
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 60)
		row.add_theme_constant_override("separation", 6)
		var medal := TextureRect.new()
		medal.texture = MEDAL_TEXTURES.get(i + 1)
		medal.custom_minimum_size = Vector2(22, 26)
		medal.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		medal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(medal)
		var name_label := Label.new()
		name_label.text = str(entry.get("name", ""))
		name_label.add_theme_font_size_override("font_size", 28)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name_label)
		var score_label := Label.new()
		score_label.text = str(entry.get("score", 0))
		score_label.add_theme_font_size_override("font_size", 28)
		score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(score_label)
		_leaderboard_rows.add_child(row)


## Phase 23 FR23.6: opens the Profile View for the active player.
func _on_profile_button_pressed() -> void:
	AudioManager.play_sfx("click")
	_update_profile_panel()
	_profile_panel.visible = true


func _on_close_profile_pressed() -> void:
	AudioManager.play_sfx("click")
	_profile_panel.visible = false


## Phase 23 FR23.6/FR23.7: fills the Profile View with the active player's
## best 3 session scores, record count, highest level reached, and per-level
## personal bests.
func _update_profile_panel() -> void:
	var name: String = HighScoreManager.get_active_player_name()
	_profile_name_label.text = name if not name.is_empty() else HighScoreManager.DEFAULT_PLAYER_NAME
	_record_count_label.text = "Records Set: %d" % HighScoreManager.get_record_count()
	_highest_level_label.text = "Highest Level Reached: %d" % HighScoreManager.get_highest_level_reached()

	var top: Array = HighScoreManager.get_top_scores()
	if top.is_empty():
		_best_scores_label.text = "Best Scores: -"
	else:
		var parts: Array[String] = []
		for score: int in top:
			parts.append(str(score))
		_best_scores_label.text = "Best Scores: %s" % ", ".join(parts)

	var bests: Array[String] = []
	for level in range(1, LevelConfig.total_level_count() + 1):
		var best: int = HighScoreManager.get_personal_best(level)
		if best > 0:
			bests.append("L%d: %d" % [level, best])
	_per_level_bests_label.text = "Per-Level Bests: %s" % (
			", ".join(bests) if not bests.is_empty() else "-")


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
