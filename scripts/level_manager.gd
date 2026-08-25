## Owns level boundaries: progression, difficulty, lives, attempts, and the
## single level-wide timer. It is scene-owned by Main, not an autoload.
class_name LevelManager
extends Node

signal level_changed(level: int)

const CATEGORY_SEQUENCE: Array[String] = [
	"addition", "subtraction", "multiplication", "division"
]

## Phase 8 FR8.4/FR8.5: at levels >= this threshold the advanced "prime"
## category is appended ONCE to the sequence as a 5th wave. Below the
## threshold the sequence stays exactly the Phase 6 four-category rotation.
## Because GameConfig.get_level_time_limit() derives the budget from the
## wave count, advanced levels automatically get waves x seconds-per-wave
## (e.g. 5 x 30 = 150 s) unless a per-level override exists.
const ADVANCED_LEVEL_THRESHOLD := 5
const ADVANCED_CATEGORY := "prime"

var wave_manager: Node = null
var level_complete_banner: Node = null

var current_level: int = 1
var difficulty: int = 1
var effective_tries_per_question: int = GameConfig.DEFAULT_TRIES_PER_QUESTION
var category_sequence: Array[String] = CATEGORY_SEQUENCE.duplicate()
var _level_clear_in_progress: bool = false


func _ready() -> void:
	if wave_manager == null and has_node("../WaveManager"):
		wave_manager = get_node("../WaveManager")
	if level_complete_banner == null and has_node("../LevelCompleteBanner"):
		level_complete_banner = get_node("../LevelCompleteBanner")
	if wave_manager != null and wave_manager.has_signal("all_waves_complete"):
		wave_manager.all_waves_complete.connect(on_all_waves_complete)


## Stage A uses difficulty 1. Each later level increases the generator's
## difficulty by one, preserving the four categories while expanding their
## operand ranges through the existing question strategies.
func difficulty_for_level(level: int) -> int:
	return max(1, level)


func start_level() -> void:
	category_sequence = CATEGORY_SEQUENCE.duplicate()
	if current_level >= ADVANCED_LEVEL_THRESHOLD:
		category_sequence.append(ADVANCED_CATEGORY)
	difficulty = difficulty_for_level(current_level)
	effective_tries_per_question = GameConfig.get_tries_per_question(current_level)
	wave_manager.set_category_sequence(category_sequence)
	GameManager.reset_lives()
	var limit := GameConfig.get_level_time_limit(current_level, category_sequence.size())
	GameManager.start_level_timer(limit)
	level_changed.emit(current_level)
	wave_manager.start_first_wave(difficulty)


func on_all_waves_complete() -> void:
	if _level_clear_in_progress or GameManager.is_game_over():
		return
	_level_clear_in_progress = true
	if level_complete_banner != null and level_complete_banner.has_method("show_banner"):
		level_complete_banner.show_banner()
	current_level += 1
	start_level()
	_level_clear_in_progress = false


## Phase 7 FR7.9: returns the session to a freshly-launched state - Level 1,
## the Level 1 difficulty, and a rebuilt base category sequence - before
## spawning Wave 1 via start_level(). The caller (Main.restart_session) is
## responsible for clearing stale nodes first; HighScoreManager is never
## touched here (FR7.10).
func reset_and_start() -> void:
	current_level = 1
	_level_clear_in_progress = false
	start_level()