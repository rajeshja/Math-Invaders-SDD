## Authoritative owner for session game state that must survive outside
## individual UI/gameplay nodes: score, lives, and game-over state.
extends Node

signal score_changed(score: int)
signal lives_changed(lives: int)
signal game_over

enum GameState {
	PLAYING,
	GAME_OVER,
}

var score: int = 0
var lives: int = 0
var starting_lives: int = GameConfig.DEFAULT_STARTING_LIVES
var game_state: GameState = GameState.PLAYING


func _ready() -> void:
	reset_session()


func reset_session() -> void:
	starting_lives = GameConfig.get_starting_lives()
	score = 0
	lives = starting_lives
	game_state = GameState.PLAYING
	score_changed.emit(score)
	lives_changed.emit(lives)


func add_score(amount: int = 1) -> void:
	if game_state == GameState.GAME_OVER:
		return
	score += amount
	score_changed.emit(score)


func lose_life() -> void:
	take_damage(1)


func take_damage(amount: int = 1) -> void:
	if game_state == GameState.GAME_OVER:
		return
	lives = max(0, lives - max(0, amount))
	lives_changed.emit(lives)
	if lives == 0:
		game_state = GameState.GAME_OVER
		game_over.emit()


func reset_lives() -> void:
	starting_lives = GameConfig.get_starting_lives()
	lives = starting_lives
	lives_changed.emit(lives)


func is_game_over() -> bool:
	return game_state == GameState.GAME_OVER
