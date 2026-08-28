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
	# depending on the real enemy.tscn scene tree.
	wave_manager.enemy_scene = partial_double(EnemyScene)


func test_wave_start_spawns_exactly_ten_enemies() -> void:
	wave_manager.start_wave("integer_addition")
	assert_eq(enemies_container.get_child_count(), 10, "start_wave should spawn exactly 10 enemies")
	assert_eq(wave_manager.enemies_remaining, 10)


func test_wave_clear_fires_exactly_when_remaining_hits_zero() -> void:
	wave_manager.start_wave("integer_addition")
	watch_signals(wave_manager)

	for i in range(9):
		wave_manager.on_correct_answer()
		assert_signal_not_emitted(wave_manager, "wave_cleared", "wave_cleared must not fire before all 10 enemies are gone (%d destroyed so far)" % (i + 1))

	wave_manager.on_correct_answer()  # 10th enemy
	assert_signal_emit_count(wave_manager, "wave_cleared", 1, "wave_cleared should fire exactly once, exactly when remaining hits 0")


func test_category_sequencing_advances_in_defined_order() -> void:
	wave_manager.start_first_wave()
	assert_eq(wave_manager.current_category, "integer_addition")

	for i in range(10):
		wave_manager.on_correct_answer()
	assert_eq(wave_manager.current_category, "integer_subtraction", "sequence should advance addition -> subtraction")

	for i in range(10):
		wave_manager.on_correct_answer()
	assert_eq(wave_manager.current_category, "integer_multiplication", "sequence should advance subtraction -> multiplication")

	for i in range(10):
		wave_manager.on_correct_answer()
	assert_eq(wave_manager.current_category, "integer_division", "sequence should advance multiplication -> division")


func test_sequence_does_not_skip_or_repeat_out_of_order() -> void:
	wave_manager.start_first_wave()
	var seen_order: Array = [wave_manager.current_category]
	wave_manager.wave_cleared.connect(func(_c): pass)  # no-op, ensures signal wiring doesn't error
	for wave_index in range(3):
		for i in range(10):
			wave_manager.on_correct_answer()
		seen_order.append(wave_manager.current_category)
	assert_eq(seen_order, ["integer_addition", "integer_subtraction", "integer_multiplication", "integer_division"])


func test_wrong_answer_does_not_move_remove_or_retarget_formation() -> void:
	wave_manager.start_wave("integer_addition")
	var before_positions := {}
	for enemy in enemies_container.get_children():
		before_positions[enemy] = enemy.position
	var active_before = wave_manager.get_active_enemy()
	var remaining_before: int = wave_manager.enemies_remaining
	watch_signals(wave_manager)

	wave_manager.on_wrong_answer()

	for enemy in enemies_container.get_children():
		assert_eq(enemy.position, before_positions[enemy],
			"wrong answers must leave every remaining enemy stationary")
	assert_eq(wave_manager.enemies_remaining, remaining_before, "wrong answers must not remove enemies")
	assert_eq(wave_manager.get_active_enemy(), active_before, "wrong answers must not retarget the active enemy")
	assert_signal_emit_count(wave_manager, "wrong_answer", 1, "one wrong answer event should be emitted per incorrect answer")


## Phase 9 FR9.15: every wrong answer carries Mistake Review details.
func test_wrong_answer_emits_question_failed_details_for_mistake_review() -> void:
	wave_manager.start_wave("integer_addition")
	var active = wave_manager.get_active_enemy()
	var linked: Dictionary = active.linked_question
	var captured := []
	wave_manager.question_failed.connect(func(question, selected, correct):
		captured.append([question, selected, correct]))

	wave_manager.on_wrong_answer(99)

	assert_eq(captured.size(), 1, "one question_failed per incorrect answer")
	assert_eq(captured[0][0], linked, "the active question travels with the event")
	assert_eq(captured[0][1], 99, "the tapped value is recorded")
	assert_eq(captured[0][2], int(linked.get("correct_answer", 0)), "so is the right answer")


func test_question_failed_defaults_to_no_selection_for_non_ui_callers() -> void:
	wave_manager.start_wave("integer_addition")
	var captured := []
	wave_manager.question_failed.connect(func(_question, selected, _correct):
		captured.append(selected))

	wave_manager.on_wrong_answer()

	assert_eq(captured, [-1])


## Phase 13 FR13.1: fraction questions carry canonical STRING answers
## through the failure path untouched (no int casting anywhere).
func test_wrong_answer_on_fraction_question_records_string_pair() -> void:
	wave_manager.start_wave("fraction_addition")
	var active = wave_manager.get_active_enemy()
	active.linked_question = {
		"question_text": "What is 1/2 + 1/4?",
		"correct_answer": "3/4",
		"choices": ["3/4", "2/6", "1/4", "3/8"],
	}
	var captured := []
	wave_manager.question_failed.connect(func(question, selected, correct):
		captured.append([selected, correct]))

	wave_manager.on_wrong_answer("2/6")

	assert_eq(captured.size(), 1, "one question_failed per incorrect answer")
	assert_eq(captured[0][0], "2/6", "the tapped STRING value is recorded")
	assert_eq(captured[0][1], "3/4", "the correct STRING answer is recorded")


## Phase 9 FR9.4: LevelConfig generation options flow into new questions.
func test_generation_options_are_applied_to_generated_questions() -> void:
	var sequence: Array[String] = ["integer_addition"]
	wave_manager.set_category_sequence(sequence)
	wave_manager.set_generation_options({"max_operand": 5})
	wave_manager.start_first_wave()

	for i in range(20):
		wave_manager.regenerate_active_question()

	for enemy in enemies_container.get_children():
		var text: String = str(enemy.linked_question.get("question_text", ""))
		for fragment in text.replace("What is ", "").replace("?", "").split("+"):
			var operand := int(fragment.strip_edges())
			if operand > 0:
				assert_lte(operand, 5, "pinned operand ceiling reaches every strategy")


func test_regenerate_active_question_keeps_same_enemy_and_formation() -> void:
	wave_manager.start_wave("integer_addition")
	var before_positions := {}
	for enemy in enemies_container.get_children():
		before_positions[enemy] = enemy.position
	var active_before = wave_manager.get_active_enemy()
	watch_signals(wave_manager)

	wave_manager.regenerate_active_question()

	for enemy in enemies_container.get_children():
		assert_eq(enemy.position, before_positions[enemy],
			"regenerating the active question must not move the formation")
	assert_eq(wave_manager.get_active_enemy(), active_before, "regenerating the question should keep the same active enemy")
	assert_eq(wave_manager.enemies_remaining, 10)
	assert_signal_emit_count(wave_manager, "question_ready", 1)


func test_active_enemy_is_lowest_on_screen_then_leftmost() -> void:
	wave_manager.start_wave("integer_addition")
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


func test_formation_spawns_as_inverted_triangle() -> void:
	wave_manager.start_wave("integer_addition")
	var enemies: Array = enemies_container.get_children()

	var row_y_positions: Array = []
	var rows := {}
	for enemy in enemies:
		var y: float = enemy.position.y
		if not rows.has(y):
			rows[y] = []
			row_y_positions.append(y)
		rows[y].append(enemy.position.x)

	assert_eq(row_y_positions.size(), 4, "the inverted triangle has exactly four rows")
	row_y_positions.sort()
	for row_index in range(row_y_positions.size()):
		var xs: Array = rows[row_y_positions[row_index]]
		assert_eq(xs.size(), WaveManagerScript.FORMATION_ROW_COUNTS[row_index],
			"row %d should hold %d enemies (4-3-2-1 top to bottom)" % [row_index, WaveManagerScript.FORMATION_ROW_COUNTS[row_index]])
		var row_center: float = (xs.min() + xs.max()) / 2.0
		assert_almost_eq(row_center, WaveManagerScript.FORMATION_CENTER_X, 0.01,
			"each triangle row must be centered on the screen's horizontal axis")

	# The single bottom tip is the frontmost enemy and is targeted first.
	var tip_y: float = row_y_positions[3]
	var tip: Node = null
	for enemy in enemies:
		if enemy.position.y == tip_y:
			tip = enemy
	assert_eq(wave_manager.get_active_enemy(), tip,
		"the triangle's bottom tip should be the first active enemy")


func test_fresh_set_of_ten_spawns_on_wave_clear() -> void:
	wave_manager.start_wave("integer_addition")
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


## -- Phase 18: per-wave enemy texture sets ------------------------------------

const SHIP1_TEX: Texture2D = preload("res://assets/images/enemies/ship1.png")
const SHIP2_TEX: Texture2D = preload("res://assets/images/enemies/ship2.png")
const SHIP3_TEX: Texture2D = preload("res://assets/images/enemies/ship3.png")
const DEFAULT_ADDITION_TEX: Texture2D = preload("res://assets/images/enemies/enemy_ship_addition.png")
const DEFAULT_SUBTRACTION_TEX: Texture2D = preload("res://assets/images/enemies/enemy_ship_subtraction.png")


func _spawned_texture_paths() -> Array:
	var paths: Array = []
	for enemy in enemies_container.get_children():
		var texture: Texture2D = enemy._sprite.texture
		paths.append(texture.resource_path)
	return paths


func _texture_sequence(sequence: Array, sets: Array) -> void:
	var typed: Array[String] = []
	for entry in sequence:
		typed.append(entry)
	wave_manager.set_category_sequence(typed)
	wave_manager.set_wave_texture_sets(sets)
	wave_manager.start_first_wave()


func test_three_image_set_cycles_in_formation_order() -> void:
	_texture_sequence(["integer_addition"], [[SHIP1_TEX, SHIP2_TEX, SHIP3_TEX]])

	var expected := [
		SHIP1_TEX.resource_path, SHIP2_TEX.resource_path, SHIP3_TEX.resource_path,
		SHIP1_TEX.resource_path, SHIP2_TEX.resource_path, SHIP3_TEX.resource_path,
		SHIP1_TEX.resource_path, SHIP2_TEX.resource_path, SHIP3_TEX.resource_path,
		SHIP1_TEX.resource_path,
	]
	assert_eq(_spawned_texture_paths(), expected,
			"FR18.2: slot k uses set element k %% set size")


func test_single_image_set_applies_to_all_ten() -> void:
	_texture_sequence(["integer_addition"], [[SHIP2_TEX]])

	var expected := []
	for i in range(10):
		expected.append(SHIP2_TEX.resource_path)
	assert_eq(_spawned_texture_paths(), expected, "FR18.6: one-image sets repeat")


func test_empty_set_uses_category_default_for_all_ten() -> void:
	_texture_sequence(["integer_addition"], [[]])

	var expected := []
	for i in range(10):
		expected.append(DEFAULT_ADDITION_TEX.resource_path)
	assert_eq(_spawned_texture_paths(), expected,
			"FR18.3: empty sets keep the category sprite")


func test_no_sets_at_all_matches_phase_17_behavior() -> void:
	wave_manager.start_wave("integer_addition")

	var expected := []
	for i in range(10):
		expected.append(DEFAULT_ADDITION_TEX.resource_path)
	assert_eq(_spawned_texture_paths(), expected,
			"NFR18.2: unset overrides are byte-identical to prior behavior")


func test_malformed_entries_fall_back_to_category_default_per_slot() -> void:
	# A non-Texture2D entry is dropped to null, so that slot keeps the
	# category default (Phase 21 FR21.4) - never a crash.
	_texture_sequence(["integer_addition"], [[SHIP1_TEX, "not_a_texture"]])

	var paths := _spawned_texture_paths()
	for k in range(paths.size()):
		if k % 2 == 0:
			assert_eq(paths[k], SHIP1_TEX.resource_path, "valid slots keep their image")
		else:
			assert_eq(paths[k], DEFAULT_ADDITION_TEX.resource_path,
					"malformed slot falls back to the category default")


func test_advancing_waves_pick_the_next_index_set() -> void:
	_texture_sequence(
			["integer_addition", "integer_subtraction"],
			[[SHIP1_TEX, SHIP2_TEX], [SHIP3_TEX]])

	assert_eq(_spawned_texture_paths()[0], SHIP1_TEX.resource_path,
			"wave 1 uses the first set's cycle")
	for i in range(10):
		wave_manager.on_correct_answer()

	assert_eq(wave_manager.current_category, "integer_subtraction")
	var second_wave := _spawned_texture_paths()
	for path in second_wave:
		assert_eq(path, SHIP3_TEX.resource_path,
				"wave 2 uses the second index's single-image set")


func test_clear_all_resets_stored_sets() -> void:
	_texture_sequence(["integer_addition"], [[SHIP1_TEX]])
	wave_manager.clear_all()
	wave_manager.start_wave("integer_subtraction")

	for path in _spawned_texture_paths():
		assert_eq(path, DEFAULT_SUBTRACTION_TEX.resource_path,
			"cleared sessions cannot leak the previous level's art")
