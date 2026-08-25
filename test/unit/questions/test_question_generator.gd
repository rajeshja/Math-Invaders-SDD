extends GutTest

var generator: QuestionGenerator


func before_each() -> void:
	generator = QuestionGenerator.new()


func test_dispatches_integer_addition_to_integer_addition_strategy() -> void:
	var result: Dictionary = generator.generate_question("integer_addition", 1)
	assert_true(result.has("question_text"))
	assert_true(result.has("correct_answer"))
	assert_true(result.has("choices"))
	assert_string_contains(result["question_text"], "+", "integer_addition category should dispatch to IntegerAdditionStrategy")


func test_dispatches_integer_subtraction_to_integer_subtraction_strategy() -> void:
	var result: Dictionary = generator.generate_question("integer_subtraction", 1)
	assert_string_contains(result["question_text"], "-", "integer_subtraction category should dispatch to IntegerSubtractionStrategy")


func test_dispatches_integer_multiplication_to_integer_multiplication_strategy() -> void:
	var result: Dictionary = generator.generate_question("integer_multiplication", 1)
	assert_string_contains(result["question_text"], "x", "integer_multiplication category should dispatch to IntegerMultiplicationStrategy")


func test_dispatches_integer_division_to_integer_division_strategy() -> void:
	var result: Dictionary = generator.generate_question("integer_division", 1)
	assert_string_contains(result["question_text"], "/", "integer_division category should dispatch to IntegerDivisionStrategy")


func test_dispatches_prime_to_prime_strategy() -> void:
	var result: Dictionary = generator.generate_question("prime", 1)
	assert_true(result.has("question_text"))
	assert_true(result.has("correct_answer"))
	assert_true(result.has("choices"))
	assert_eq(result["choices"].size(), 4)
	assert_string_contains(result["question_text"], "prime", "prime category should dispatch to PrimeStrategy")


func test_dispatches_fraction_addition_to_fraction_addition_strategy() -> void:
	var result: Dictionary = generator.generate_question("fraction_addition", 1)
	assert_true(result.has("question_text"))
	assert_eq(result["choices"].size(), 4, "fraction questions keep 4 choices")
	assert_string_contains(result["question_text"], "+",
			"fraction_addition should dispatch to FractionAdditionStrategy")
	assert_string_contains(result["question_text"], "/",
			"fraction questions carry fraction operands")
	assert_true(result.has("answer_layout"), "stacking data travels with the question")


func test_dispatches_fraction_subtraction_to_fraction_subtraction_strategy() -> void:
	var result: Dictionary = generator.generate_question("fraction_subtraction", 1)
	assert_string_contains(result["question_text"], "-",
			"fraction_subtraction should dispatch to FractionSubtractionStrategy")
	assert_true(result.has("answer_layout"), "stacking data travels with the question")


func test_dispatches_fraction_multiplication_to_fraction_multiplication_strategy() -> void:
	var result: Dictionary = generator.generate_question("fraction_multiplication", 1)
	assert_eq(result["choices"].size(), 4, "fraction questions keep 4 choices")
	assert_string_contains(result["question_text"], "x",
			"fraction_multiplication should dispatch to FractionMultiplicationStrategy")
	assert_string_contains(result["question_text"], "/",
			"fraction questions carry fraction operands")
	assert_true(result.has("answer_layout"), "stacking data travels with the question")


func test_dispatches_fraction_division_to_fraction_division_strategy() -> void:
	var result: Dictionary = generator.generate_question("fraction_division", 1)
	assert_string_contains(result["question_text"], "÷",
			"fraction_division should dispatch to FractionDivisionStrategy")
	assert_true(result.has("answer_layout"), "stacking data travels with the question")


func test_dispatches_decimal_addition_strategy() -> void:
	var result: Dictionary = generator.generate_question("decimal_addition", 1)
	assert_string_contains(result["question_text"], "+",
			"decimal_addition should dispatch to DecimalAdditionStrategy")
	assert_string_contains(result["question_text"], ".",
			"decimal questions carry decimal operands")
	assert_false(result.has("answer_layout"), "decimals render as plain text")


func test_dispatches_decimal_subtraction_strategy() -> void:
	var result: Dictionary = generator.generate_question("decimal_subtraction", 1)
	assert_string_contains(result["question_text"], "-",
			"decimal_subtraction should dispatch to DecimalSubtractionStrategy")


func test_dispatches_decimal_multiplication_strategy() -> void:
	var result: Dictionary = generator.generate_question("decimal_multiplication", 1)
	assert_string_contains(result["question_text"], "x",
			"decimal_multiplication should dispatch to DecimalMultiplicationStrategy")


func test_dispatches_decimal_division_strategy() -> void:
	var result: Dictionary = generator.generate_question("decimal_division", 1)
	assert_string_contains(result["question_text"], "÷",
			"decimal_division should dispatch to DecimalDivisionStrategy")


func test_dispatches_ratio_proportion_strategy() -> void:
	var result: Dictionary = generator.generate_question("ratio_proportion", 1)
	assert_string_contains(result["question_text"], "?",
			"ratio_proportion should dispatch to RatioProportionStrategy")
	assert_eq(typeof(result["correct_answer"]), TYPE_INT,
			"ratio answers ride the int pipeline")


func test_dispatches_hcf_lcm_strategy() -> void:
	var result: Dictionary = generator.generate_question("hcf_lcm", 1)
	assert_true(result["question_text"].contains("(HCF)") \
			or result["question_text"].contains("(LCM)"),
			"hcf_lcm should dispatch to HcfLcmStrategy")
	assert_eq(typeof(result["correct_answer"]), TYPE_INT,
			"HCF/LCM answers ride the int pipeline")


func test_well_formed_dictionary_shape_for_known_category() -> void:
	var result: Dictionary = generator.generate_question("integer_addition", 1)
	assert_true(result.has("question_text"))
	assert_true(result.has("correct_answer"))
	assert_true(result.has("choices"))
	assert_eq(typeof(result["choices"]), TYPE_ARRAY)


func test_unknown_category_handled_gracefully() -> void:
	var result: Dictionary = generator.generate_question("not_a_real_category", 1)
	# Must not crash. push_error() is the "clear, catchable error" half of
	# the graceful-failure contract - assert_push_error both confirms it
	# fired AND tells GUT this error was expected (so the test doesn't
	# fail on it as an "unexpected error").
	assert_push_error("unknown category", "should push a clear error for an unrecognized category")
	assert_true(result.has("question_text"))
	assert_true(result.has("choices"))
	assert_eq(result["question_text"], "", "unknown category should return an empty/default question_text")
	assert_eq(result["choices"], [], "unknown category should return an empty/default choices array")


func test_get_categories_includes_all_four_stage_a_categories() -> void:
	var categories: Array = generator.get_categories()
	assert_true(categories.has("integer_addition"))
	assert_true(categories.has("integer_subtraction"))
	assert_true(categories.has("integer_multiplication"))
	assert_true(categories.has("integer_division"))


func test_get_categories_includes_prime_stage_c_category() -> void:
	var categories: Array = generator.get_categories()
	assert_true(categories.has("prime"), "'prime' should be registered in the category map")


func test_get_categories_includes_decimal_categories() -> void:
	var categories: Array = generator.get_categories()
	assert_true(categories.has("decimal_addition"), "'decimal_addition' should be registered")
	assert_true(categories.has("decimal_subtraction"), "'decimal_subtraction' should be registered")
	assert_true(categories.has("decimal_multiplication"), "'decimal_multiplication' should be registered")
	assert_true(categories.has("decimal_division"), "'decimal_division' should be registered")


func test_get_categories_includes_ratio_and_hcf_lcm_categories() -> void:
	var categories: Array = generator.get_categories()
	assert_true(categories.has("ratio_proportion"), "'ratio_proportion' should be registered")
	assert_true(categories.has("hcf_lcm"), "'hcf_lcm' should be registered")


func test_get_categories_includes_fraction_categories() -> void:
	var categories: Array = generator.get_categories()
	assert_true(categories.has("fraction_addition"), "'fraction_addition' should be registered")
	assert_true(categories.has("fraction_subtraction"), "'fraction_subtraction' should be registered")
	assert_true(categories.has("fraction_multiplication"), "'fraction_multiplication' should be registered")
	assert_true(categories.has("fraction_division"), "'fraction_division' should be registered")


## Phase 12 FR12.4 / Phase 13 FR13.6: display-name registry maps every
## registered key to its player-facing HUD label.
func test_display_names_map_registered_keys_to_hud_labels() -> void:
	assert_eq(QuestionGenerator.get_display_name("integer_addition"), "Addition")
	assert_eq(QuestionGenerator.get_display_name("integer_subtraction"), "Subtraction")
	assert_eq(QuestionGenerator.get_display_name("integer_multiplication"), "Multiplication")
	assert_eq(QuestionGenerator.get_display_name("integer_division"), "Division")
	assert_eq(QuestionGenerator.get_display_name("prime"), "Prime Numbers")
	assert_eq(QuestionGenerator.get_display_name("fraction_addition"), "Fraction Addition")
	assert_eq(QuestionGenerator.get_display_name("fraction_subtraction"), "Fraction Subtraction")
	assert_eq(QuestionGenerator.get_display_name("fraction_multiplication"), "Fraction Multiplication")
	assert_eq(QuestionGenerator.get_display_name("fraction_division"), "Fraction Division")
	assert_eq(QuestionGenerator.get_display_name("decimal_addition"), "Decimal Addition")
	assert_eq(QuestionGenerator.get_display_name("decimal_subtraction"), "Decimal Subtraction")
	assert_eq(QuestionGenerator.get_display_name("decimal_multiplication"), "Decimal Multiplication")
	assert_eq(QuestionGenerator.get_display_name("decimal_division"), "Decimal Division")
	assert_eq(QuestionGenerator.get_display_name("ratio_proportion"), "Ratio & Proportion")
	assert_eq(QuestionGenerator.get_display_name("hcf_lcm"), "HCF & LCM")


## Phase 12 FR12.4: unknown keys fall back to String.capitalize().
func test_display_name_unknown_key_falls_back_to_capitalize() -> void:
	assert_eq(QuestionGenerator.get_display_name("not_a_real_category"), "Not A Real Category")
