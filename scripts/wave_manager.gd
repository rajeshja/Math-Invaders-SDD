## Owns the full lifecycle of a wave: spawning the 10-enemy formation,
## tracking which enemy is "active," handling correct/wrong answers, and
## sequencing categories across waves (Tech Stack §4, Phase 3).
##
## Scene-owned, NOT an autoload (Phase 0 §2 Architecture Ownership Note) -
## instantiated/owned by Main.gd for the active game session.
##
## Testability (Phase 3 NFR3.2): `enemy_scene` and `enemies_container` are
## both public, settable properties (not hardcoded preload/get_node calls
## baked into start_wave), specifically so GUT tests can inject a double
## scene and a throwaway Node2D container instead of the real enemy.tscn/
## live scene tree.
class_name WaveManager
extends Node

## -- Signals -----------------------------------------------------------
## Emitted whenever a new question should be shown for the current active
## enemy (on wave start and after every correct answer while enemies
## remain).
signal question_ready(question: Dictionary)

## Emitted whenever the remaining-enemy count changes, for HUD wiring
## (Spec §6 "Wave category + enemies remaining").
signal wave_progress_updated(category: String, remaining: int, total: int)

## Emitted when a wave's 10 enemies are all cleared, before the next
## wave's fresh set of 10 spawns.
signal wave_cleared(category: String)

## Emitted when the category_sequence is exhausted after a wave clears -
## the hook point for Phase 5's LevelManager. Not acted on further here.
signal level_cleared

## -- Config --------------------------------------------------------------
const ENEMIES_PER_WAVE: int = 10
const FORMATION_COLUMNS: int = 5
const FORMATION_ROWS: int = 2
const FORMATION_TOP_Y: float = 160.0
const FORMATION_ROW_SPACING: float = 130.0
const FORMATION_LEFT_X: float = 90.0
const FORMATION_COLUMN_SPACING: float = 135.0
const WRONG_ANSWER_STEP_PX: float = 40.0

## Default Stage A sequence (Spec §2 Level 1 example / Phase 3 FR3.7).
## LevelManager (Phase 5) will be what mutates/extends this per level.
@export var category_sequence: Array[String] = [
	"addition", "subtraction", "multiplication", "division"
]

## Injectable for tests (Phase 3 NFR3.2). Defaults to the real enemy scene.
var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")

## Injectable container node that spawned enemies are parented under.
## Defaults to null; Main.gd assigns the real GameWorld/Enemies node.
var enemies_container: Node = null

var question_generator: QuestionGenerator = QuestionGenerator.new()
var difficulty: int = 1

var current_category: String = ""
var enemies_remaining: int = 0
var _sequence_index: int = -1
var _active_enemy: Node = null


func _ready() -> void:
	if enemies_container == null and has_node("../GameWorld/Enemies"):
		enemies_container = get_node("../GameWorld/Enemies")


## Starts (or restarts) a wave for the given category: clears any leftover
## enemies, spawns a fresh formation of 10, generates a question per
## enemy up front, and emits the first question_ready (Phase 3 FR3.2).
func start_wave(category: String) -> void:
	current_category = category
	_clear_container()

	for i in range(ENEMIES_PER_WAVE):
		var enemy := enemy_scene.instantiate()
		enemies_container.add_child(enemy)
		enemy.position = _formation_position(i)
		var question: Dictionary = question_generator.generate_question(category, difficulty)
		if enemy.has_method("setup"):
			enemy.setup(category, question)

	enemies_remaining = ENEMIES_PER_WAVE
	wave_progress_updated.emit(current_category, enemies_remaining, ENEMIES_PER_WAVE)
	_active_enemy = get_active_enemy()
	_emit_active_question()


## Starts the first wave of the configured category_sequence. Convenience
## entry point for Main.gd's game-start call.
func start_first_wave() -> void:
	_sequence_index = 0
	if category_sequence.is_empty():
		push_error("WaveManager: category_sequence is empty.")
		return
	start_wave(category_sequence[_sequence_index])


## Returns the current active enemy: the frontmost/lowest-on-screen
## remaining enemy (greatest Y), tie-broken by leftmost (lowest X)
## (Phase 3 FR3.3 / NFR3.3). Returns null if no enemies remain.
func get_active_enemy() -> Node:
	var remaining: Array = _remaining_enemies()
	if remaining.is_empty():
		return null
	remaining.sort_custom(_compare_active_order)
	return remaining[0]


## Call after a bullet confirms it hit the active enemy. Destroys it,
## decrements the remaining count, and either triggers wave-clear or
## advances to the next active enemy's question (Phase 3 FR3.4).
func on_correct_answer() -> void:
	if _active_enemy == null:
		return
	if is_instance_valid(_active_enemy):
		# Detach immediately so get_active_enemy()'s next lookup (below)
		# never sees this enemy via get_children() - queue_free()/destroy()
		# only defers the actual memory free, not membership in the tree.
		if _active_enemy.get_parent() == enemies_container:
			enemies_container.remove_child(_active_enemy)
		if _active_enemy.has_method("destroy"):
			_active_enemy.destroy()
		else:
			_active_enemy.queue_free()

	enemies_remaining = max(0, enemies_remaining - 1)
	wave_progress_updated.emit(current_category, enemies_remaining, ENEMIES_PER_WAVE)

	if enemies_remaining == 0:
		_active_enemy = null
		_on_wave_clear()
	else:
		_active_enemy = get_active_enemy()
		_emit_active_question()


## Wrong answer: the whole remaining formation advances downward together
## by one movement step. The active enemy does not move independently
## (Phase 3 FR3.11 / NFR3.4).
func on_wrong_answer() -> void:
	for enemy in _remaining_enemies():
		if enemy.has_method("move_down"):
			enemy.move_down(WRONG_ANSWER_STEP_PX)
		else:
			enemy.position.y += WRONG_ANSWER_STEP_PX


## -- Internal -------------------------------------------------------------

func _on_wave_clear() -> void:
	wave_cleared.emit(current_category)
	_sequence_index += 1
	if _sequence_index >= category_sequence.size():
		# Sequence exhausted - hook point for Phase 5's LevelManager.
		level_cleared.emit()
		_sequence_index = 0
	start_wave(category_sequence[_sequence_index])


func _emit_active_question() -> void:
	if _active_enemy == null:
		return
	var question: Dictionary = _active_enemy.linked_question if "linked_question" in _active_enemy else {}
	question_ready.emit(question)


func _remaining_enemies() -> Array:
	if enemies_container == null:
		return []
	return enemies_container.get_children()


func _compare_active_order(a: Node, b: Node) -> bool:
	# "Lowest/frontmost" = visually lowest on screen = greatest Y in
	## Godot's top-left-origin 2D coordinate space. Tie-break: leftmost
	## (smallest X) (Phase 3 FR3.3 / NFR3.3).
	if a.position.y != b.position.y:
		return a.position.y > b.position.y
	return a.position.x < b.position.x


func _clear_container() -> void:
	if enemies_container == null:
		return
	# free() (not queue_free()) so the container's child list is correct
	# IMMEDIATELY - start_wave() spawns the new formation in the same call,
	# and a deferred removal would leave stale children counted alongside
	# the fresh 10 until the next process frame (Phase 3 FR3.8: a fresh
	# set of 10 spawns, not a mix of stale + new instances).
	for child in enemies_container.get_children():
		child.free()


func _formation_position(index: int) -> Vector2:
	var row: int = index / FORMATION_COLUMNS
	var col: int = index % FORMATION_COLUMNS
	var x: float = FORMATION_LEFT_X + col * FORMATION_COLUMN_SPACING
	var y: float = FORMATION_TOP_Y + row * FORMATION_ROW_SPACING
	return Vector2(x, y)
