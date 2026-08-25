## LevelConfig resource tests (Phase 9 Testing Plan: verify .tres files can
## be loaded and supply expected parameters).
extends GutTest

const LEVEL_PATHS: Array[String] = [
	"res://resources/levels/level_1.tres",
	"res://resources/levels/level_2.tres",
	"res://resources/levels/level_3.tres",
	"res://resources/levels/level_4.tres",
	"res://resources/levels/level_5.tres",
	"res://resources/levels/level_6.tres",
]


func test_every_registered_level_resource_loads_as_level_config() -> void:
	for path in LevelConfig.LEVEL_RESOURCE_PATHS:
		assert_true(ResourceLoader.exists(path), "%s exists" % path)
		var resource := load(path)
		assert_is(resource, LevelConfig)


func test_levels_are_numbered_sequentially_from_one() -> void:
	var configs := LevelConfig.load_all_levels()

	assert_eq(configs.size(), LEVEL_PATHS.size())
	for i in range(configs.size()):
		assert_eq(configs[i].level_number, i + 1, "slot %d holds level %d" % [i, i + 1])


func test_each_config_supplies_valid_gameplay_parameters() -> void:
	for path in LEVEL_PATHS:
		var config: LevelConfig = load(path)
		assert_gt(config.time_limit_seconds, 0.0, "%s time budget positive" % path)
		assert_gte(config.tries_per_question, 1, "%s attempts at least one" % path)
		assert_gte(config.difficulty, 1, "%s difficulty sane" % path)
		assert_false(config.category_sequence.is_empty(), "%s defines waves" % path)


func test_levels_one_two_and_four_keep_base_integer_rotation_budget() -> void:
	var expected: Array[String] = [
		"integer_addition", "integer_subtraction", "integer_multiplication", "integer_division"
	]
	# Levels 1-2 stay pure-integer on the base budget; level 4 grew fraction
	# waves (see the dedicated tests below) but keeps them appended after
	# the unchanged integer rotation.
	for level in [1, 2]:
		var config: LevelConfig = load(LEVEL_PATHS[level - 1])
		assert_eq(config.category_sequence, expected,
			"level %d keeps the Phase 6 four-category rotation" % level)
		assert_eq(config.time_limit_seconds, 120.0)

	var level_four: LevelConfig = load(LEVEL_PATHS[3])
	assert_eq(level_four.category_sequence.slice(0, 4), expected,
			"level 4 keeps the integer rotation up front")


## Phase 13 FR13.11: Level 3 debuts the fraction categories appended after
## the integer waves, with unlike denominators gated OFF.
func test_level_three_debuts_fraction_waves_with_unlike_denominators_gated_off() -> void:
	var config: LevelConfig = load(LEVEL_PATHS[2])

	assert_eq(config.category_sequence.size(), 6)
	assert_eq(config.category_sequence[4], "fraction_addition")
	assert_eq(config.category_sequence[5], "fraction_subtraction")
	assert_false(config.allow_unlike_denominators,
			"debut level serves Tier 1/2 like-denominator content first")
	assert_gt(config.time_limit_seconds, 120.0,
			"two extra waves extend the time budget")


func test_level_four_enables_unlike_denominators_for_fraction_waves() -> void:
	var config: LevelConfig = load("res://resources/levels/level_4.tres")

	assert_eq(config.category_sequence[4], "fraction_addition")
	assert_eq(config.category_sequence[5], "fraction_subtraction")
	assert_true(config.allow_unlike_denominators,
			"a later level turns unlike denominators on")


func test_level_five_keeps_prime_once_then_appends_decimal_waves() -> void:
	var config: LevelConfig = load("res://resources/levels/level_5.tres")

	var prime_count := 0
	for category in config.category_sequence:
		if category == "prime":
			prime_count += 1
	assert_eq(prime_count, 1)
	# Phase 15 FR15.8: the four decimal waves ride after the original five.
	assert_eq(config.category_sequence.size(), 9)
	assert_eq(config.category_sequence[4], "prime")
	assert_eq(config.category_sequence[5], "decimal_addition")
	assert_eq(config.category_sequence.back(), "decimal_division")
	assert_eq(config.time_limit_seconds, 270.0,
			"nine waves extend the budget from the five-wave baseline")


func test_level_five_debuts_decimals_with_one_decimal_place() -> void:
	var config: LevelConfig = load("res://resources/levels/level_5.tres")

	assert_eq(config.max_decimal_places, 1,
			"FR15.8: decimal debut level serves tenths first")


## Phase 16 FR16.8: the roster extends with a sixth level hosting the
## ratio/proportion and HCF/LCM debut waves alongside review waves.
func test_level_six_hosts_ratio_and_hcf_lcm_debuts() -> void:
	var config: LevelConfig = load("res://resources/levels/level_6.tres")

	assert_eq(config.level_number, 6)
	assert_true(config.category_sequence.has("ratio_proportion"))
	assert_true(config.category_sequence.has("hcf_lcm"))
	assert_gt(config.time_limit_seconds, 0.0)
	assert_gt(config.difficulty, 0)
	assert_eq(config.max_decimal_places, 2, "decimal places rise on later levels")


func test_generation_options_expose_procedural_math_knobs() -> void:
	var config: LevelConfig = load("res://resources/levels/level_3.tres")
	config.max_operand_size = 50

	var options: Dictionary = config.generation_options()

	assert_eq(options.get("max_operand"), 50)
	assert_eq(options.get("allow_unlike_denominators"), false)
	assert_eq(options.get("max_decimal_places"), 0)


## Phase 17 FR17.1/FR17.2: scoring field defaults to 1, clamps invalid
## values with a one-time warning, and round-trips through authored .tres
## fixtures.
func test_points_per_question_defaults_to_one() -> void:
	var config := LevelConfig.new()
	assert_eq(config.points_per_question, 1, "fresh resources default to 1")
	assert_eq(config.resolved_points_per_question(), 1)


func test_resolved_points_clamps_invalid_values_with_warning() -> void:
	# Reset the one-time warning guard so this test owns its emission.
	LevelConfig._warned_invalid_points = false
	var config := LevelConfig.new()
	config.points_per_question = 0

	assert_eq(config.resolved_points_per_question(), 1, "0 clamps to 1")
	assert_push_warning("clamping to 1", "invalid values warn exactly once")

	# Further invalid resolutions stay clamped but never re-warn.
	assert_eq(config.resolved_points_per_question(), 1)

	# Restore the guard state for any other test touching invalid values.
	LevelConfig._warned_invalid_points = false


func test_authored_levels_carry_non_default_scoring() -> void:
	var level_one: LevelConfig = load(LEVEL_PATHS[0])
	assert_eq(level_one.points_per_question, 1,
			"FR17.6: Level 1 stays at the default 1")
	var level_five: LevelConfig = load(LEVEL_PATHS[4])
	assert_eq(level_five.points_per_question, 3,
			"later levels rise modestly as categories get harder")
	assert_eq(level_five.resolved_points_per_question(), 3)


## Phase 18 FR18.1: wave texture sets default empty and normalize into
## per-index String arrays aligned with category_sequence.
func test_wave_enemy_textures_default_empty_and_align() -> void:
	var config := LevelConfig.new()
	config.category_sequence = ["a", "b", "c"] as Array[String]

	var sets: Array = config.resolved_wave_texture_sets()
	assert_eq(sets.size(), 3, "one slot per sequence entry")
	for set_array in sets:
		assert_eq(set_array.size(), 0, "unset waves resolve to empty sets")


func test_wave_enemy_textures_partial_configuration_pads_with_empty() -> void:
	var config := LevelConfig.new()
	config.category_sequence = ["a", "b", "c"] as Array[String]
	config.wave_enemy_textures = [["res://x.png"]]

	var sets: Array = config.resolved_wave_texture_sets()
	assert_eq(sets[0].size(), 1)
	assert_eq(str(sets[0][0]), "res://x.png")
	assert_eq(sets[1].size(), 0, "unconfigured later waves stay default")
	assert_eq(sets[2].size(), 0)


func test_wave_enemy_textures_tolerates_malformed_elements() -> void:
	var config := LevelConfig.new()
	config.category_sequence = ["a", "b", "c"] as Array[String]
	config.wave_enemy_textures = [
		"not_an_array",                       # whole element malformed
		["res://ok.png", 42, "", null],       # mixed junk entries
		{"dict": true},
	]

	var sets: Array = config.resolved_wave_texture_sets()
	assert_eq(sets[0].size(), 0, "non-array elements resolve empty")
	assert_eq(sets[1].size(), 1, "only valid non-empty strings survive")
	assert_eq(str(sets[1][0]), "res://ok.png")
	assert_eq(sets[2].size(), 0)


func test_level_one_ships_the_three_image_demo() -> void:
	var level_one: LevelConfig = load(LEVEL_PATHS[0])
	assert_eq(level_one.wave_enemy_textures.size(), 1,
			"FR18.7: Wave 1 demonstrates the three-image set")
	var wave_one_set: Array = level_one.wave_enemy_textures[0]
	assert_eq(wave_one_set.size(), 3)
	for path in wave_one_set:
		assert_true(ResourceLoader.exists(str(path)),
				"demo placeholder art exists (%s)" % str(path))


## -- Phase 19: player ship resolution -----------------------------------------

func test_player_ship_resolution_defaults_without_warning() -> void:
	var config := LevelConfig.new()
	assert_eq(config.player_ship_texture, "", "default is empty (FR19.1)")
	assert_eq(config.resolved_player_ship_texture(),
			LevelConfig.DEFAULT_PLAYER_SHIP_TEXTURE,
			"empty selection keeps the default ship")


func test_player_ship_resolution_returns_valid_configured_path() -> void:
	var config := LevelConfig.new()
	config.player_ship_texture = "res://assets/images/ships/player_ship.png"
	assert_eq(config.resolved_player_ship_texture(),
			"res://assets/images/ships/player_ship.png",
			"valid configured paths pass through")


func test_player_ship_missing_path_falls_back_and_warns_once() -> void:
	LevelConfig._warned_missing_player_ship = false
	var config := LevelConfig.new()
	config.player_ship_texture = "res://assets/images/ships/no_such_ship.png"

	assert_eq(config.resolved_player_ship_texture(),
			LevelConfig.DEFAULT_PLAYER_SHIP_TEXTURE,
			"missing paths fall back to the default")
	assert_push_warning("no_such_ship", "missing configured ships warn once")

	# Further resolutions stay defaulted but never re-warn.
	assert_eq(config.resolved_player_ship_texture(),
			LevelConfig.DEFAULT_PLAYER_SHIP_TEXTURE)

	LevelConfig._warned_missing_player_ship = false


func test_level_two_ships_the_variant_demo() -> void:
	var level_two: LevelConfig = load(LEVEL_PATHS[1])
	assert_eq(level_two.player_ship_texture,
			"res://assets/images/ships/player_ship_alt.png",
			"FR19.6: Level 2 demonstrates a variant ship")
	assert_eq(level_two.resolved_player_ship_texture(),
			"res://assets/images/ships/player_ship_alt.png")


## FR9.3/NFR9.1: fraction and decimal rules must be Inspector-editable
## fields on the resource itself.
func test_fraction_and_decimal_rule_exports_exist_on_the_resource() -> void:
	var script: Script = load("res://scripts/level_config.gd")
	var property_names: Array = script.get_script_property_list().map(
		func(prop): return prop.name)
	assert_has(property_names, "allow_unlike_denominators")
	assert_has(property_names, "max_decimal_places")


func test_max_operand_option_overrides_strategy_difficulty_curve() -> void:
	var generator := QuestionGenerator.new()
	var pinned := {"max_operand": 5}

	for attempt in range(30):
		var question: Dictionary = generator.generate_question("integer_addition", 10, pinned)
		var text: String = question.get("question_text", "")
		var operands := text.replace("What is ", "").replace("?", "").split(" + ")
		for operand_text in operands:
			assert_lte(int(operand_text.strip_edges()), 5,
				"pinned ceiling beats the difficulty curve")
