## Top-level game controller. Owns the WaveManager instance (scene-owned,
## not an autoload - Phase 0 §2) and wires together the question panel,
## HUD, and bullet-firing feedback loop.
##
## GameManager owns score/lives/game-over; this scene controller wires
## gameplay objects, question attempts, HUD updates, and feedback timing.
class_name Main
extends Node2D

const BULLET_SCENE: PackedScene = preload("res://scenes/bullet.tscn")
const QuestionAttemptTrackerScript = preload("res://scripts/question_attempt_tracker.gd")

@onready var _wave_manager: WaveManager = $WaveManager
@onready var _player: Player = $GameWorld/Player
@onready var _enemies_container: Node2D = $GameWorld/Enemies
@onready var _bullets_container: Node2D = $GameWorld/Bullets
@onready var _hud: Hud = $HUD
@onready var _question_panel: QuestionPanel = $QuestionPanel
@onready var _wave_banner: WaveBanner = $WaveBanner

var _current_question: Dictionary = {}
var _accepting_input: bool = true
var _current_level: int = 1
var _attempt_tracker: RefCounted = QuestionAttemptTrackerScript.new()


func _ready() -> void:
	_attempt_tracker.configure(GameConfig.get_tries_per_question(_current_level))
	GameManager.score_changed.connect(_hud.update_score)
	GameManager.lives_changed.connect(_hud.update_lives)
	GameManager.game_over.connect(_on_game_over)
	_hud.update_score(GameManager.score)
	_hud.update_lives(GameManager.lives)

	_wave_manager.enemies_container = _enemies_container
	_wave_manager.question_ready.connect(_on_question_ready)
	_wave_manager.wave_progress_updated.connect(_hud.update_wave_progress)
	_wave_manager.wave_cleared.connect(_on_wave_cleared)

	_question_panel.answer_selected.connect(_on_answer_selected)

	_wave_manager.start_first_wave()


func _on_question_ready(question: Dictionary) -> void:
	_current_question = question
	_attempt_tracker.reset_question()
	_accepting_input = true
	_question_panel.set_question(question)


func _on_wave_cleared(_category: String) -> void:
	_wave_banner.show_banner()


func _on_answer_selected(value: int, button: Button) -> void:
	if not _accepting_input:
		return
	if _current_question.is_empty():
		return

	if value == _current_question.get("correct_answer", null):
		_accepting_input = false
		_question_panel.set_answer_buttons_enabled(false)
		_fire_at_active_enemy()
	else:
		_accepting_input = false
		await _question_panel.flash_wrong_answer(button)
		_handle_wrong_answer_after_feedback()


func _handle_wrong_answer_after_feedback() -> void:
	_wave_manager.on_wrong_answer()
	GameManager.lose_life()
	var attempt_limit_reached: bool = _attempt_tracker.record_wrong_attempt()

	if GameManager.is_game_over():
		_accepting_input = false
		_question_panel.set_answer_buttons_enabled(false)
		return

	if attempt_limit_reached:
		_wave_manager.regenerate_active_question()
	else:
		_accepting_input = true
		_question_panel.set_answer_buttons_enabled(true)


func _fire_at_active_enemy() -> void:
	var active_enemy: Node2D = _wave_manager.get_active_enemy()
	if active_enemy == null:
		return

	var bullet: Bullet = BULLET_SCENE.instantiate()
	_bullets_container.add_child(bullet)
	bullet.arrived.connect(_on_bullet_arrived)
	bullet.launch(_player.get_muzzle_position(), active_enemy.global_position)
	_player.play_fire_feedback()


func _on_bullet_arrived() -> void:
	GameManager.add_score(1)
	_wave_manager.on_correct_answer()


func _on_game_over() -> void:
	_accepting_input = false
	_question_panel.set_answer_buttons_enabled(false)
