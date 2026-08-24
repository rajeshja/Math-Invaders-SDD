extends GutTest

const WaveManagerScript = preload("res://scripts/wave_manager.gd")
const EnemyScene = preload("res://scenes/enemy.tscn")

var wave_manager: Node
var enemies_container: Node2D


func before_each() -> void:
	wave_manager = WaveManagerScript.new()
	add_child_autofree(wave_manager)

	enemies_container = Node2D.new()
	add_child_autofree(enemies_container)

	wave_manager.enemies_container = enemies_container
	# Phase 3 NFR3.2: use a GUT double of the enemy scene rather than
	# depending on the real enemy.tscn scene tree. partial_double (not a
	# full double) so real per-instance logic like move_down()/position
	# math still executes - only scene-tree-dependent bits (texture
	# loading via @onready Sprite2D) are effectively inert since these
	# doubles are never added under a Sprite2D-bearing tree in these tests.
	wave_manager.enemy_scene = partial_double(EnemyScene)


func test_wave_start_spawns_exactly_ten_enemies() -> void:
	wave_manager.start_wave("addition")
	assert_eq(enemies_container.get_child_count(), 10, "start_wave should spawn exactly 10 enemies")
	assert_eq(wave_manager.enemies_remaining, 10)


func test_wave_clear_fires_exactly_when_remaining_hits_zero() -> void:
	wave_manager.start_wave("addition")
	watch_signals(wave_manager)

	for i in range(9):
		wave_manager.on_correct_answer()
		assert_signal_not_emitted(wave_manager, "wave_cleared", "wave_cleared must not fire before all 10 enemies are gone (%d destroyed so far)" % (i + 1))

	wave_manager.on_correct_answer()  # 10th enemy
	assert_signal_emit_count(wave_manager, "wave_cleared", 1, "wave_cleared should fire exactly once, exactly when remaining hits 0")


func test_category_sequencing_advances_in_defined_order() -> void:
	wave_manager.start_first_wave()
	assert_eq(wave_manager.current_category, "addition")

	for i in range(10):
		wave_manager.on_correct_answer()
	assert_eq(wave_manager.current_category, "subtraction", "sequence should advance addition -> subtraction")

	for i in range(10):
		wave_manager.on_correct_answer()
	assert_eq(wave_manager.current_category, "multiplication", "sequence should advance subtraction -> multiplication")

	for i in range(10):
		wave_manager.on_correct_answer()
	assert_eq(wave_manager.current_category, "division", "sequence should advance multiplication -> division")


func test_sequence_does_not_skip_or_repeat_out_of_order() -> void:
	wave_manager.start_first_wave()
	var seen_order: Array = [wave_manager.current_category]
	wave_manager.wave_cleared.connect(func(_c): pass)  # no-op, ensures signal wiring doesn't error
	for wave_index in range(3):
		for i in range(10):
			wave_manager.on_correct_answer()
		seen_order.append(wave_manager.current_category)
	assert_eq(seen_order, ["addition", "subtraction", "multiplication", "division"])


func test_wrong_answer_moves_entire_remaining_formation_not_just_active() -> void:
	wave_manager.start_wave("addition")
	var before_positions := {}
	for enemy in enemies_container.get_children():
		before_positions[enemy] = enemy.position.y

	wave_manager.on_wrong_answer()

	var step = wave_manager.WRONG_ANSWER_STEP_PX
	for enemy in enemies_container.get_children():
		assert_almost_eq(enemy.position.y, before_positions[enemy] + step, 0.01,
			"every remaining enemy should move down by the same configured step")


func test_active_enemy_is_lowest_on_screen_then_leftmost() -> void:
	wave_manager.start_wave("addition")
	var enemies: Array = enemies_container.get_children()

	# Force a known layout: enemy A is frontmost (greatest Y), enemy B and
	# C tie for second-greatest Y with B to the left of C.
	enemies[0].position = Vector2(300, 500)   # A: frontmost
	enemies[1].position = Vector2(400, 300)   # B: tied second row, right
	enemies[2].position = Vector2(100, 300)   # C: tied second row, left (should win tiebreak)
	for i in range(3, enemies.size()):
		enemies[i].position = Vector2(50 * i, 100)  # clearly further back

	var active = wave_manager.get_active_enemy()
	assert_eq(active, enemies[0], "the enemy with the greatest Y (frontmost/lowest on screen) should be active")

	# Remove A, then C (left) should win over B (right) at the tied row.
	enemies_container.remove_child(enemies[0])
	active = wave_manager.get_active_enemy()
	assert_eq(active, enemies[2], "with A gone, the leftmost of the tied-Y enemies should be active")


func test_fresh_set_of_ten_spawns_on_wave_clear() -> void:
	wave_manager.start_wave("addition")
	var first_wave_ids: Array = []
	for enemy in enemies_container.get_children():
		first_wave_ids.append(enemy.get_instance_id())

	for i in range(10):
		wave_manager.on_correct_answer()

	assert_eq(enemies_container.get_child_count(), 10, "a fresh set of 10 should spawn after wave clear")
	var second_wave_ids: Array = []
	for enemy in enemies_container.get_children():
		second_wave_ids.append(enemy.get_instance_id())

	for id in second_wave_ids:
		assert_false(first_wave_ids.has(id), "fresh spawn must not reuse stale instances from the previous wave")
