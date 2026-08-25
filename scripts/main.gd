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
const MistakeTrackerScript = preload("res://scripts/mistake_tracker.gd")

## Developer force-start level (Phase 9 FR9.9). When > 0 the game starts
## directly at that level, bypassing the Main Menu AND unlock restrictions.
## Leave at 0 for the normal Splash -> Menu -> Game flow.
@export var debug_start_level: int = 0

@onready var _wave_manager: WaveManager = $WaveManager
@onready var _player: Player = $GameWorld/Player
@onready var _enemies_container: Node2D = $GameWorld/Enemies
@onready var _bullets_container: Node2D = $GameWorld/Bullets
@onready var _hud: Hud = $HUD
@onready var _question_panel: QuestionPanel = $QuestionPanel
@onready var _wave_banner: WaveBanner = $WaveBanner
@onready var _level_complete_banner: WaveBanner = $LevelCompleteBanner
@onready var _game_over_overlay: GameOverOverlay = $GameOverOverlay
@onready var _level_manager: LevelManager = $LevelManager
@onready var _camera: CameraShake = $Camera2D
@onready var _damage_flash: FlashOverlay = $DamageFlash

var _current_question: Dictionary = {}
var _accepting_input: bool = true
var _attempt_tracker: RefCounted = QuestionAttemptTrackerScript.new()
var _mistake_tracker: RefCounted = MistakeTrackerScript.new()
## Bumped by restart_session(); lets awaited wrong-answer continuations
## detect that the session they belonged to is gone (NFR7.4).
var _session_id: int = 0


func _ready() -> void:
	GameManager.score_changed.connect(_hud.update_score)
	GameManager.lives_changed.connect(_hud.update_lives)
	GameManager.time_changed.connect(_hud.update_time)
	GameManager.game_over.connect(_on_game_over)
	_level_manager.level_changed.connect(_on_level_changed)
	_hud.update_score(GameManager.score)
	_hud.update_lives(GameManager.lives)

	_wave_manager.enemies_container = _enemies_container
	_wave_manager.question_ready.connect(_on_question_ready)
	_wave_manager.wave_progress_updated.connect(_hud.update_wave_progress)
	_wave_manager.wave_cleared.connect(_on_wave_cleared)
	# The enemy return-fire visual path listens to the SAME single
	# wrong-answer event the damage path consumes (FR4.11/NFR4.2). It is
	# presentational only - it never decrements lives and never blocks
	# question flow, input, or Game Over.
	_wave_manager.wrong_answer.connect(_on_enemy_return_fire)
	# FR9.15: every incorrect answer lands in the capped mistake log for
	# this session's Mistake Review.
	_wave_manager.question_failed.connect(_on_question_failed)
	# Phase 10 FR9.3: damage feedback layers on top of the Phase 4 enemy-
	# fire/player-hit visuals, triggered from the same wrong_answer event.
	# Purely presentational listeners; GameManager is not modified.
	_wave_manager.wrong_answer.connect(_on_wrong_answer_feedback)
	# Phase 10 FR9.5: level-complete fanfare fires exactly when the last
	# wave of the level's sequence clears (same signal LevelManager uses).
	_wave_manager.all_waves_complete.connect(_on_level_complete_fx)

	_question_panel.answer_selected.connect(_on_answer_selected)
	_game_over_overlay.play_again_pressed.connect(restart_session)
	_game_over_overlay.return_to_menu_pressed.connect(_return_to_main_menu)

	_level_manager.start_session(effective_start_level())
	# FR9.6: looping gameplay music starts with the session and stops on
	# Game Over (see _on_game_over).
	AudioManager.play_music()


func _process(delta: float) -> void:
	GameManager.tick(delta)


## Resolves the session's starting level (FR9.6/FR9.9): the debug export
## wins when set, otherwise the Main Menu's pending choice, else Level 1.
func effective_start_level() -> int:
	if debug_start_level > 0:
		return debug_start_level
	if GameManager.pending_start_level > 0:
		var requested: int = GameManager.pending_start_level
		GameManager.pending_start_level = 0
		return requested
	return 1


func _on_question_failed(question: Dictionary, selected_answer, correct_answer) -> void:
	_mistake_tracker.add_mistake(question, selected_answer, correct_answer)


func _on_question_ready(question: Dictionary) -> void:
	if GameManager.is_game_over():
		return
	_current_question = question
	_attempt_tracker.reset_question()
	_accepting_input = true
	_question_panel.set_question(question)


func _on_level_changed(level: int) -> void:
	_attempt_tracker.configure(_level_manager.effective_tries_per_question)
	# Phase 19 FR19.3: every level boundary - session start, advancement,
	# and Play Again all funnel through start_level() - re-applies that
	# level's chosen player ship.
	_player.apply_ship_texture(
			_level_manager.resolved_config_for(level).resolved_player_ship_texture())
	_hud.update_level(level)
	_hud.update_time(GameManager.time_remaining)


func _on_wave_cleared(_category: String) -> void:
	AudioManager.play_sfx("wave_complete")
	_wave_banner.show_banner()


## FR9.3: screen shake + red flash on damage. Layered on top of the
## Phase 4 enemy-fire telegraph, enemy bullet, and player-hit flash;
## fire-and-forget so nothing gameplay-side waits on it (NFR9.2).
func _on_wrong_answer_feedback() -> void:
	_camera.shake(0.45)
	_damage_flash.flash()


func _on_level_complete_fx() -> void:
	AudioManager.play_sfx("level_complete")


## `value` is an int for integer categories or the canonical String form
## for fraction categories (Phase 13 FR13.1); comparison is exact equality
## against the active question's correct_answer.
func _on_answer_selected(value, button: Button) -> void:
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
		_resolve_wrong_answer(value, button)


## Correct answers launch the bullet and advance the question immediately.
## The enemy remains visible until the bullet's arrival callback confirms the
## hit, so visual destruction follows the projectile without blocking input.
func _resolve_correct_answer() -> void:
	var target: Node2D = _wave_manager.get_active_enemy() as Node2D
	if target != null:
		_fire_player_bullet(target)
		AudioManager.play_sfx("fire")
	GameManager.add_score(_level_manager.effective_points_per_question)
	_wave_manager.on_correct_answer(target)


func _fire_player_bullet(target: Node2D) -> void:
	var bullet: Bullet = BULLET_SCENE.instantiate()
	bullet.arrived.connect(_on_player_bullet_arrived.bind(target), CONNECT_ONE_SHOT)
	_bullets_container.add_child(bullet)
	bullet.launch(_player.get_muzzle_position(), target.global_position)
	_player.play_fire_feedback()


func _on_player_bullet_arrived(target: Node2D) -> void:
	AudioManager.play_sfx("hit")
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
	AudioManager.play_sfx("enemy_fire")
	var bullet: EnemyBullet = ENEMY_BULLET_SCENE.instantiate()
	bullet.arrived.connect(_on_enemy_bullet_impact)
	_bullets_container.add_child(bullet)
	bullet.launch(shooter.global_position, _player.global_position)


## Enemy bullet arrival: brief player-hit flash (FR4.11) plus the FR9.5
## player-hit impact cue. Presentational only.
func _on_enemy_bullet_impact() -> void:
	AudioManager.play_sfx("player_hit")
	_player.play_hit_flash()


## Wrong-answer logic resolves immediately (life loss, attempt counting,
## Game Over precedence). Only the next question's DISPLAY waits out the
## brief red-flash feedback interval; enemy return fire (introduced by the
## Phase 4 lives system) will hook the same wrong_answer event and fly
## fully in parallel - question changes never wait on bullet travel.
func _resolve_wrong_answer(selected_answer, button: Button) -> void:
	var session_at_answer := _session_id
	_question_panel.flash_wrong_answer(button)
	AudioManager.play_sfx("miss")
	_wave_manager.on_wrong_answer(selected_answer)
	GameManager.lose_life()
	var attempt_limit_reached: bool = _attempt_tracker.record_wrong_attempt()

	if GameManager.is_game_over():
		_question_panel.set_answer_buttons_enabled(false)
		return

	if attempt_limit_reached:
		await _question_panel.wait_wrong_feedback()
		if session_at_answer != _session_id or GameManager.is_game_over():
			return
		_wave_manager.regenerate_active_question()
	else:
		await _question_panel.wait_wrong_feedback()
		if session_at_answer != _session_id or GameManager.is_game_over():
			return
		_accepting_input = true
		_question_panel.set_answer_buttons_enabled(true)


func _on_game_over() -> void:
	_accepting_input = false
	_question_panel.set_answer_buttons_enabled(false)
	# FR9.6: music stops when GameManager enters GAME_OVER; FR9.5: the
	# game-over cue plays for both causes (lives/time).
	AudioManager.stop_music()
	AudioManager.play_sfx("game_over")
	# FR7.5: the same listener that swaps in the Game Over screen records the
	# final score with HighScoreManager; GameManager stays decoupled from it.
	var new_record: bool = HighScoreManager.save_if_higher(GameManager.score)
	_game_over_overlay.show_game_over(
		GameManager.score,
		_game_over_reason_text(),
		new_record,
		HighScoreManager.get_high_score(),
		HighScoreManager.get_player_name(),
		_mistake_tracker.get_mistakes())


## Single coordinated restart entry point (FR7.8/FR7.9), called only by the
## Game Over screen's Play Again button. Phase 9 FR9.18: the fresh session
## starts at the SAME level the user originally started at - not a
## hard-reset to Level 1/Wave 1. Stale nodes and banner overlays are
## cleared BEFORE the fresh spawn, all within one call so the two sessions
## never overlap on screen (NFR7.4). The mistake log is session-scoped and
## starts empty again; HighScoreManager is deliberately NOT touched here
## (FR7.10): the persisted value carries forward exactly as save_if_higher()
## left it.
func restart_session() -> void:
	_session_id += 1
	_game_over_overlay.hide_overlay()
	_wave_banner.hide_banner()
	_level_complete_banner.hide_banner()
	_clear_bullets()
	_wave_manager.clear_all()
	_current_question = {}
	_attempt_tracker.reset_question()
	_mistake_tracker.clear()
	GameManager.reset_session(_assumed_starting_score())
	_level_manager.reset_and_start()
	# FR9.6: a fresh session restarts the looping gameplay music (no-op if
	# it is somehow still playing).
	AudioManager.play_music()


## FR9.19: back to level select / name entry without starting a new game.
func _return_to_main_menu() -> void:
	AudioManager.stop_music()
	GameManager.pending_start_level = 0
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


## The assumed full score for this session's start level, re-applied on
## Play Again so a same-level restart begins with the same base as the
## first launch of that session (FR9.7/FR9.8/FR9.18).
func _assumed_starting_score() -> int:
	return HighScoreManager.get_assumed_score_for_level(_level_manager.session_start_level)


func _clear_bullets() -> void:
	for child in _bullets_container.get_children():
		child.free()


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
