## Top-level game controller. Owns the WaveManager instance (scene-owned,
## not an autoload - Phase 0 §2) and wires together the question panel,
## HUD, and bullet-firing feedback loop.
##
## GameManager owns score/lives/game-over; this scene controller wires
## gameplay objects, question attempts, HUD updates, and feedback timing.
class_name Main
extends Node2D

const BULLET_SCENE: PackedScene = preload("res://scenes/bullet.tscn")
const ENEMY_BULLET_SCENE: PackedScene = preload("res://scenes/enemy_bullet.tscn")
const QuestionAttemptTrackerScript = preload("res://scripts/question_attempt_tracker.gd")

@onready var _wave_manager: WaveManager = $WaveManager
@onready var _player: Player = $GameWorld/Player
@onready var _enemies_container: Node2D = $GameWorld/Enemies
@onready var _bullets_container: Node2D = $GameWorld/Bullets
@onready var _hud: Hud = $HUD
@onready var _question_panel: QuestionPanel = $QuestionPanel
@onready var _wave_banner: WaveBanner = $WaveBanner
@onready var _game_over_overlay: GameOverOverlay = $GameOverOverlay

var _current_question: Dictionary = {}
var _accepting_input: bool = true
var _current_level: int = 1
var _attempt_tracker: RefCounted = QuestionAttemptTrackerScript.new()


func _ready() -> void:
	_attempt_tracker.configure(GameConfig.get_tries_per_question(_current_level))
	GameManager.score_changed.connect(_hud.update_score)
	GameManager.lives_changed.connect(_hud.update_lives)
	GameManager.time_changed.connect(_hud.update_time)
	GameManager.game_over.connect(_on_game_over)
	_hud.update_score(GameManager.score)
	_hud.update_lives(GameManager.lives)
	_start_level_timer()

	_wave_manager.enemies_container = _enemies_container
	_wave_manager.question_ready.connect(_on_question_ready)
	_wave_manager.wave_progress_updated.connect(_hud.update_wave_progress)
	_wave_manager.wave_cleared.connect(_on_wave_cleared)
	# The enemy return-fire visual path listens to the SAME single
	# wrong-answer event the damage path consumes (FR4.11/NFR4.2). It is
	# presentational only - it never decrements lives and never blocks
	# question flow, input, or Game Over.
	_wave_manager.wrong_answer.connect(_on_enemy_return_fire)

	_question_panel.answer_selected.connect(_on_answer_selected)

	_wave_manager.start_first_wave()


func _process(delta: float) -> void:
	GameManager.tick(delta)


func _start_level_timer() -> void:
	var wave_count: int = _wave_manager.category_sequence.size()
	var limit: float = GameConfig.get_level_time_limit(_current_level, wave_count)
	GameManager.start_level_timer(limit)
	_hud.update_time(GameManager.time_remaining)


func _on_question_ready(question: Dictionary) -> void:
	if GameManager.is_game_over():
		return
	_current_question = question
	_attempt_tracker.reset_question()
	_accepting_input = true
	_question_panel.set_question(question)


func _on_wave_cleared(_category: String) -> void:
	_wave_banner.show_banner()


func _on_answer_selected(value: int, button: Button) -> void:
	if not GameManager.is_playing():
		return
	if not _accepting_input:
		return
	if _current_question.is_empty():
		return
	_accepting_input = false

	if value == _current_question.get("correct_answer", null):
		_resolve_correct_answer()
	else:
		_resolve_wrong_answer(button)


## Correct answers launch the bullet and advance the question immediately.
## The enemy remains visible until the bullet's arrival callback confirms the
## hit, so visual destruction follows the projectile without blocking input.
func _resolve_correct_answer() -> void:
	var target: Node2D = _wave_manager.get_active_enemy() as Node2D
	if target != null:
		_fire_player_bullet(target)
	GameManager.add_score(1)
	_wave_manager.on_correct_answer(target)


func _fire_player_bullet(target: Node2D) -> void:
	var bullet: Bullet = BULLET_SCENE.instantiate()
	bullet.arrived.connect(_on_player_bullet_arrived.bind(target), CONNECT_ONE_SHOT)
	_bullets_container.add_child(bullet)
	bullet.launch(_player.get_muzzle_position(), target.global_position)
	_player.play_fire_feedback()


func _on_player_bullet_arrived(target: Node2D) -> void:
	_wave_manager.on_enemy_hit(target)


## Wrong-answer return-fire feedback (FR4.11): the active enemy plays a
## ~0.1 s fire telegraph and one enemy bullet launches from its position
## toward the player ship, flying exactly 0.3 s (Bullet.TRAVEL_TIME) and
## ending in a brief player-hit flash. Runs synchronously alongside the
## damage path; nothing here gates gameplay (NFR4.6).
func _on_enemy_return_fire() -> void:
	var shooter := _wave_manager.get_active_enemy() as Node2D
	if shooter == null:
		return
	shooter.play_fire_feedback()
	var bullet: EnemyBullet = ENEMY_BULLET_SCENE.instantiate()
	bullet.arrived.connect(_player.play_hit_flash)
	_bullets_container.add_child(bullet)
	bullet.launch(shooter.global_position, _player.global_position)


## Wrong-answer logic resolves immediately (life loss, attempt counting,
## Game Over precedence). Only the next question's DISPLAY waits out the
## brief red-flash feedback interval; enemy return fire (introduced by the
## Phase 4 lives system) will hook the same wrong_answer event and fly
## fully in parallel - question changes never wait on bullet travel.
func _resolve_wrong_answer(button: Button) -> void:
	_question_panel.flash_wrong_answer(button)
	_wave_manager.on_wrong_answer()
	GameManager.lose_life()
	var attempt_limit_reached: bool = _attempt_tracker.record_wrong_attempt()

	if GameManager.is_game_over():
		_question_panel.set_answer_buttons_enabled(false)
		return

	if attempt_limit_reached:
		await _question_panel.wait_wrong_feedback()
		if GameManager.is_game_over():
			return
		_wave_manager.regenerate_active_question()
	else:
		await _question_panel.wait_wrong_feedback()
		if GameManager.is_game_over():
			return
		_accepting_input = true
		_question_panel.set_answer_buttons_enabled(true)


func _on_game_over() -> void:
	_accepting_input = false
	_question_panel.set_answer_buttons_enabled(false)
	_game_over_overlay.show_game_over(GameManager.score, _game_over_reason_text())


## Maps GameManager's reason enum to the Game Over screen's reason line.
## "Time's up!" (TIME_EXPIRED) joins in Phase 5.
func _game_over_reason_text() -> String:
	match GameManager.last_game_over_reason:
		GameManager.GameOverReason.LIVES_DEPLETED:
			return "Out of lives!"
		GameManager.GameOverReason.TIME_EXPIRED:
			return "Time's up!"
		_:
			return ""
