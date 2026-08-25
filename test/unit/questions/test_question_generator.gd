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


## Phase 12 FR12.4: display-name registry maps every registered key to its
## player-facing HUD label.
func test_display_names_map_registered_keys_to_hud_labels() -> void:
	assert_eq(QuestionGenerator.get_display_name("integer_addition"), "Addition")
	assert_eq(QuestionGenerator.get_display_name("integer_subtraction"), "Subtraction")
	assert_eq(QuestionGenerator.get_display_name("integer_multiplication"), "Multiplication")
	assert_eq(QuestionGenerator.get_display_name("integer_division"), "Division")
	assert_eq(QuestionGenerator.get_display_name("prime"), "Prime Numbers")


## Phase 12 FR12.4: unknown keys fall back to String.capitalize().
func test_display_name_unknown_key_falls_back_to_capitalize() -> void:
	assert_eq(QuestionGenerator.get_display_name("not_a_real_category"), "Not A Real Category")
