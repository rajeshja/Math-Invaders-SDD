## LevelConfig resource tests (Phase 9 Testing Plan: verify .tres files can
## be loaded and supply expected parameters).
extends GutTest

const LEVEL_PATHS: Array[String] = [
	"res://resources/levels/level_1.tres",
	"res://resources/levels/level_2.tres",
	"res://resources/levels/level_3.tres",
	"res://resources/levels/level_4.tres",
	"res://resources/levels/level_5.tres",
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


func test_generation_options_expose_procedural_math_knobs() -> void:
	var config: LevelConfig = load("res://resources/levels/level_3.tres")
	config.max_operand_size = 50

	var options: Dictionary = config.generation_options()

	assert_eq(options.get("max_operand"), 50)
	assert_eq(options.get("allow_unlike_denominators"), false)
	assert_eq(options.get("max_decimal_places"), 0)


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
