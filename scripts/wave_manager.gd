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

## Emitted exactly once per incorrect answer. GameManager/Main consume
## this as the lives/damage trigger; WaveManager does not move enemies.
signal wrong_answer

## Emitted when the category_sequence is exhausted after a wave clears -
## the hook point for Phase 6's LevelManager. Not acted on further here.
signal level_cleared

## -- Config --------------------------------------------------------------
## Inverted-triangle formation: rows of 4 - 3 - 2 - 1 enemies from top to
## bottom (summing to the default 10-enemy wave). Each row is centered on
## the screen's horizontal axis and narrows by one ship per row, ending in
## the single frontmost "tip" enemy just above the player.
const FORMATION_ROW_COUNTS: Array[int] = [4, 3, 2, 1]
const FORMATION_CENTER_X: float = 360.0
const FORMATION_TOP_Y: float = 160.0
const FORMATION_ROW_SPACING: float = 130.0
const FORMATION_COLUMN_SPACING: float = 135.0

## Default Stage A sequence (Spec §2 Level 1 example / Phase 3 FR3.7).
## LevelManager (Phase 6) will be what mutates/extends this per level.
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
var enemies_per_wave: int = GameConfig.DEFAULT_ENEMIES_PER_WAVE
var _sequence_index: int = -1
var _active_enemy: Node = null
var _pending_hit_enemies: Array[Node] = []


func _ready() -> void:
	if enemies_container == null and has_node("../GameWorld/Enemies"):
		enemies_container = get_node("../GameWorld/Enemies")


## Starts (or restarts) a wave for the given category: clears any leftover
## enemies, spawns a fresh formation of 10, generates a question per
## enemy up front, and emits the first question_ready (Phase 3 FR3.2).
func start_wave(category: String) -> void:
	current_category = category
	_clear_container()
	_pending_hit_enemies.clear()
	enemies_per_wave = GameConfig.get_enemies_per_wave()

	for i in range(enemies_per_wave):
		var enemy := enemy_scene.instantiate()
		enemies_container.add_child(enemy)
		enemy.position = _formation_position(i)
		var question: Dictionary = question_generator.generate_question(category, difficulty)
		if enemy.has_method("setup"):
			enemy.setup(category, question)

	enemies_remaining = enemies_per_wave
	wave_progress_updated.emit(current_category, enemies_remaining, enemies_per_wave)
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


## Call when a correct answer launches its player bullet. The targeted enemy
## stays visible until `on_enemy_hit()` receives that bullet's arrival, but is
## excluded from active-enemy selection so the next question can appear while
## the bullet is in flight. The no-argument form retains the original
## confirmed-hit behavior for non-visual callers.
func on_correct_answer(target: Node = null) -> void:
	var confirmed_immediately: bool = target == null
	if target == null:
		target = _active_enemy
	if target == null or not is_instance_valid(target):
		return
	if _pending_hit_enemies.has(target):
		return
	_pending_hit_enemies.append(target)
	if confirmed_immediately:
		on_enemy_hit(target)
		if enemies_remaining > 0:
			_active_enemy = get_active_enemy()
			_emit_active_question()
		return
	_active_enemy = get_active_enemy()
	_emit_active_question()


## Completes the gameplay side of a player-bullet hit: removes the enemy,
## updates wave progress, and starts the next wave only after the hit arrives.
func on_enemy_hit(enemy: Node) -> void:
	if enemy == null or not _pending_hit_enemies.has(enemy):
		return
	_pending_hit_enemies.erase(enemy)
	if is_instance_valid(enemy):
		if enemy.get_parent() == enemies_container:
			enemies_container.remove_child(enemy)
		if enemy.has_method("destroy"):
			enemy.destroy()
		else:
			enemy.queue_free()

	enemies_remaining = max(0, enemies_remaining - 1)
	wave_progress_updated.emit(current_category, enemies_remaining, enemies_per_wave)

	if enemies_remaining == 0:
		_active_enemy = null
		_on_wave_clear()


## Wrong answer: emit the damage event and leave the active enemy and
## formation stationary. Attempt counting/question replacement belongs to
## the question-flow owner, not WaveManager.
func on_wrong_answer() -> void:
	wrong_answer.emit()


## Retires the active enemy's current question and replaces it with a
## freshly generated one for the same category, without moving or removing
## any enemy. Used when an incorrect answer exhausts the configured attempt
## count but lives remain.
func regenerate_active_question() -> void:
	if _active_enemy == null or not is_instance_valid(_active_enemy):
		return
	var question: Dictionary = question_generator.generate_question(current_category, difficulty)
	if "linked_question" in _active_enemy:
		_active_enemy.linked_question = question
	question_ready.emit(question)


## -- Internal -------------------------------------------------------------

func _on_wave_clear() -> void:
	wave_cleared.emit(current_category)
	_sequence_index += 1
	if _sequence_index >= category_sequence.size():
		# Sequence exhausted - hook point for Phase 6's LevelManager.
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
	var remaining: Array = []
	for enemy in enemies_container.get_children():
		if not _pending_hit_enemies.has(enemy):
			remaining.append(enemy)
	return remaining


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


## Inverted-triangle layout: row r holds FORMATION_ROW_COUNTS[r] enemies
## centered on FORMATION_CENTER_X, rows stacked downward from
## FORMATION_TOP_Y. Indices beyond the defined rows overflow into a left-
## to-right continuation of the last row (only reachable when the
## configured enemies_per_wave exceeds 4 + 3 + 2 + 1).
func _formation_position(index: int) -> Vector2:
	var remaining: int = index
	var row: int = 0
	while row < FORMATION_ROW_COUNTS.size() - 1 and remaining >= FORMATION_ROW_COUNTS[row]:
		remaining -= FORMATION_ROW_COUNTS[row]
		row += 1
	var count_in_row: int = FORMATION_ROW_COUNTS[row]
	var row_width: float = (count_in_row - 1) * FORMATION_COLUMN_SPACING
	var x: float = FORMATION_CENTER_X - row_width / 2.0 + remaining * FORMATION_COLUMN_SPACING
	var y: float = FORMATION_TOP_Y + row * FORMATION_ROW_SPACING
	return Vector2(x, y)
