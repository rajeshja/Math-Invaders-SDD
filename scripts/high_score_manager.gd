## Persists the single session high score to a small JSON file in user://
## so the player's best result survives app restarts (Tech Stack §5/§7).
##
## Deliberately decoupled from GameManager (Phase 0 architecture note):
## gameplay code calls save_if_higher() when a session ends; this autoload
## never reads game state on its own. `save_path` is a settable property
## purely so tests can redirect I/O away from the real save file (NFR7.1).
extends Node

const DEFAULT_SAVE_PATH := "user://highscore.json"
const HIGH_SCORE_KEY := "high_score"

var save_path: String = DEFAULT_SAVE_PATH
var high_score: int = 0


func _ready() -> void:
	load_high_score()


## Reads the persisted high score. A missing file (first run) or malformed
## content falls back to 0 rather than raising an error (FR7.3/NFR7.2).
func load_high_score() -> void:
	high_score = 0
	if not FileAccess.file_exists(save_path):
		return

	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_warning("HighScoreManager: could not open %s for reading." % save_path)
		return

	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	# Instance-level parse() returns an Error instead of printing one, keeping
	# corrupt saves a silent fallback-to-zero rather than a runtime error.
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return

	var value: Variant = json.data.get(HIGH_SCORE_KEY, 0)
	if value is int or value is float:
		high_score = max(0, int(value))


func get_high_score() -> int:
	return high_score


## Records `score` only when it strictly exceeds the stored value, so a tie
## is never reported as a new record (NFR7.3). Returns whether a new record
## was set; nothing is written to disk otherwise.
func save_if_higher(score: int) -> bool:
	if score <= high_score:
		return false
	high_score = score
	_write_save_file()
	return true


func _write_save_file() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("HighScoreManager: could not write %s." % save_path)
		return
	file.store_string(JSON.stringify({HIGH_SCORE_KEY: high_score}))
	file.close()
