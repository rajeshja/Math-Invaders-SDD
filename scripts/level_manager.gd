## Owns level boundaries: progression, difficulty, lives, attempts, and the
## single level-wide timer. It is scene-owned by Main, not an autoload.
##
## Phase 9 (FR9.1-FR9.4): every per-level value now comes from LevelConfig
## custom resources (.tres) instead of hardcoded scaling thresholds or
## per-level Project Setting dictionaries. This manager also drives
## mastery bookkeeping: a level cleared without losing a life extends that
## level's flawless streak; three in a row unlock the NEXT level
## sequentially via HighScoreManager (FR9.3/FR9.4).
class_name LevelManager
extends Node

signal level_changed(level: int)

var wave_manager: Node = null
var level_complete_banner: Node = null

var current_level: int = 1
## The level this session was started at (menu choice or debug override).
## "Play Again" restarts here rather than hard-resetting to Level 1 (FR9.18).
var session_start_level: int = 1
var difficulty: int = 1
var effective_tries_per_question: int = GameConfig.DEFAULT_TRIES_PER_QUESTION
## Points per correct answer resolved from the active LevelConfig
## (Phase 17 FR17.3); Main reads this instead of the hardcoded +1.
var effective_points_per_question: int = 1
var category_sequence: Array[String] = []
var _configs: Array[LevelConfig] = []
var _level_clear_in_progress: bool = false
## Mastery tracking for the CURRENT level only (FR9.3): any lost life
## marks the level non-flawless and breaks its streak.
var _lives_lost_this_level: int = 0
## Score snapshot at level start; the difference at level clear is what a
## personal best is recorded from (FR9.5/FR9.7).
var _score_at_level_start: int = 0
## Phase 25 FR25.4: the level's adjusted score (earned + bonus - penalty,
## clamped at 0) computed at level completion and recorded as the personal
## best (FR25.5).
var _level_score: int = 0


func _ready() -> void:
	_configs = LevelConfig.load_all_levels()
	if wave_manager == null and has_node("../WaveManager"):
		wave_manager = get_node("../WaveManager")
	if level_complete_banner == null and has_node("../LevelCompleteBanner"):
		level_complete_banner = get_node("../LevelCompleteBanner")
	if wave_manager != null and wave_manager.has_signal("all_waves_complete"):
		wave_manager.all_waves_complete.connect(on_all_waves_complete)
	GameManager.lives_changed.connect(_on_lives_changed)


func total_defined_levels() -> int:
	return _configs.size()


## Resolves the LevelConfig governing `level`. Levels beyond the defined
## set reuse the last config's shape while continuing to raise difficulty
## (see effective_difficulty_for), so progression never dead-ends.
## The shared resource is never mutated.
func resolved_config_for(level: int) -> LevelConfig:
	if _configs.is_empty():
		push_error("LevelManager: no LevelConfig resources could be loaded.")
		return LevelConfig.new()
	return _configs[clampi(level - 1, 0, _configs.size() - 1)]


## Difficulty for levels past the defined set keeps climbing by one per
## level on top of the last config's value.
func effective_difficulty_for(level: int, config: LevelConfig) -> int:
	var overflow := maxi(0, level - _configs.size())
	return max(1, config.difficulty + overflow)


## Starts a fresh session at `start_level` (FR9.6/FR9.7): score begins at
## the assumed full score - the sum of personal bests of all skipped
## levels - before the first question is shown (FR9.8).
func start_session(start_level: int) -> void:
	session_start_level = validate_start_level(start_level)
	current_level = session_start_level
	GameManager.reset_session(HighScoreManager.get_assumed_score_for_level(current_level))
	start_level()


## Clamps an arbitrary requested start level into [1, defined levels].
## Unlock restrictions are enforced by the Main Menu UI; debug overrides
## deliberately bypass them (FR9.9), so no check lives here.
func validate_start_level(requested: int) -> int:
	return clampi(requested, 1, maxi(1, total_defined_levels()))


func start_level() -> void:
	var config := resolved_config_for(current_level)
	category_sequence = config.category_sequence.duplicate()
	difficulty = effective_difficulty_for(current_level, config)
	effective_tries_per_question = max(1, config.tries_per_question)
	effective_points_per_question = config.resolved_points_per_question()
	wave_manager.set_category_sequence(category_sequence)
	if wave_manager.has_method("set_generation_options"):
		wave_manager.set_generation_options(config.generation_options())
	if wave_manager.has_method("set_wave_texture_sets"):
		wave_manager.set_wave_texture_sets(config.resolved_wave_texture_sets())
	GameManager.reset_lives()
	GameManager.start_level_timer(maxf(1.0, config.time_limit_seconds))
	_lives_lost_this_level = 0
	_score_at_level_start = GameManager.score
	level_changed.emit(current_level)
	wave_manager.start_first_wave(difficulty)


func on_all_waves_complete() -> void:
	if _level_clear_in_progress or GameManager.is_game_over():
		return
	_level_clear_in_progress = true
	_apply_level_scoring_adjustments()
	_record_level_result()
	if level_complete_banner != null and level_complete_banner.has_method("show_banner"):
		level_complete_banner.show_banner()
	current_level += 1
	start_level()
	_level_clear_in_progress = false


## Phase 7 FR7.9 / Phase 9 FR9.18: returns the session to its ORIGINAL
## starting level (not hard-coded Level 1 anymore) before spawning that
## level's Wave 1. The caller (Main.restart_session) clears stale nodes
## first; persistence state carries forward untouched (FR7.10).
func reset_and_start() -> void:
	current_level = session_start_level
	_level_clear_in_progress = false
	start_level()


## -- Internal ---------------------------------------------------------------

## Phase 25 FR25.2/FR25.3/FR25.4: applies the level-completion scoring
## adjustments. The early-finish bonus is 1 point per full
## bonus_seconds_per_point remaining; each life lost deducts
## lives_lost_penalty_points. The adjusted level score is clamped at 0 and
## the net adjustment is applied to the running total (never below 0),
## emitting score_changed (FR25.5).
func _apply_level_scoring_adjustments() -> void:
	var earned: int = GameManager.score - _score_at_level_start
	var bonus: int = floori(GameManager.time_remaining / GameConfig.get_bonus_seconds_per_point())
	var penalty: int = _lives_lost_this_level * GameConfig.get_lives_lost_penalty_points()
	_level_score = maxi(0, earned + bonus - penalty)
	var net: int = bonus - penalty
	if net != 0:
		GameManager.score = maxi(0, GameManager.score + net)
		GameManager.score_changed.emit(GameManager.score)


## Persists one completed level's outcome: personal best for the adjusted
## level score, then either extends the flawless streak or breaks it because
## a life was lost during the level (FR9.3/FR9.5/FR25.5).
func _record_level_result() -> void:
	HighScoreManager.record_personal_best(current_level, _level_score)
	if _lives_lost_this_level > 0:
		HighScoreManager.reset_flawless_streak(current_level)
	else:
		HighScoreManager.record_flawless_clear(current_level, total_defined_levels())


## Any life drop during the active level flags it as non-flawless AND
## resets that level's persisted streak immediately (FR9.3 test plan:
## taking damage resets the streak counter). Lives resets/restores never
## raise the counter above zero lost lives.
func _on_lives_changed(lives: int) -> void:
	var baseline: int = GameManager.starting_lives
	if lives < baseline:
		_lives_lost_this_level = maxi(_lives_lost_this_level, baseline - lives)
		if _lives_lost_this_level > 0:
			HighScoreManager.reset_flawless_streak(current_level)
