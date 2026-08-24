## Authoritative owner for session game state that must survive outside
## individual UI/gameplay nodes: score, lives, game-over state, and the
## reason the session ended (Tech Stack §5).
##
## Single damage path: every wrong answer calls take_damage(1) exactly
## once (FR4.3/NFR4.2); no other node decrements lives. Game Over is
## terminal until reset_session() starts a fresh session.
extends Node

signal score_changed(score: int)
signal lives_changed(lives: int)
signal time_changed(time_remaining: float)
signal game_over

enum GameState {
	PLAYING,
	PAUSED,
	GAME_OVER,
}

## Why the current session ended. Phase 4 introduces LIVES_DEPLETED;
## Phase 5 extends this enum with TIME_EXPIRED.
enum GameOverReason {
	NONE,
	LIVES_DEPLETED,
	TIME_EXPIRED,
}

var score: int = 0
var lives: int = 0
var starting_lives: int = GameConfig.DEFAULT_STARTING_LIVES
var level_time_limit: float = 0.0
var time_remaining: float = 0.0
var game_state: GameState = GameState.PLAYING
var last_game_over_reason: GameOverReason = GameOverReason.NONE


func _ready() -> void:
	reset_session()


func reset_session() -> void:
	starting_lives = GameConfig.get_starting_lives()
	score = 0
	lives = starting_lives
	time_remaining = level_time_limit
	game_state = GameState.PLAYING
	last_game_over_reason = GameOverReason.NONE
	score_changed.emit(score)
	lives_changed.emit(lives)
	time_changed.emit(time_remaining)


func start_level_timer(limit: float) -> void:
	level_time_limit = max(0.0, limit)
	time_remaining = level_time_limit
	time_changed.emit(time_remaining)


func tick(delta: float) -> void:
	if game_state != GameState.PLAYING:
		return
	if time_remaining <= 0.0:
		return
	if delta <= 0.0:
		return

	time_remaining = max(0.0, time_remaining - delta)
	time_changed.emit(time_remaining)
	if time_remaining == 0.0:
		last_game_over_reason = GameOverReason.TIME_EXPIRED
		game_state = GameState.GAME_OVER
		game_over.emit()


func add_score(amount: int = 1) -> void:
	if game_state == GameState.GAME_OVER:
		return
	score += amount
	score_changed.emit(score)


func lose_life() -> void:
	take_damage(1)


## Consumes up to `amount` lives, clamped so lives never go negative.
## Gameplay always calls this with the default of 1 per wrong answer.
## Idempotent at the event level once GAME_OVER: further calls do nothing
## and game_over is emitted exactly once (FR4.7/FR4.9).
func take_damage(amount: int = 1) -> void:
	if game_state != GameState.PLAYING:
		return
	lives = max(0, lives - max(0, amount))
	lives_changed.emit(lives)
	if lives == 0:
		last_game_over_reason = GameOverReason.LIVES_DEPLETED
		game_state = GameState.GAME_OVER
		game_over.emit()


func reset_lives() -> void:
	starting_lives = GameConfig.get_starting_lives()
	lives = starting_lives
	lives_changed.emit(lives)


func is_game_over() -> bool:
	return game_state == GameState.GAME_OVER


func is_playing() -> bool:
	return game_state == GameState.PLAYING
