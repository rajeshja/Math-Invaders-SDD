extends GutTest

var generator: QuestionGenerator


func before_each() -> void:
	generator = QuestionGenerator.new()


func test_dispatches_addition_to_addition_strategy() -> void:
	var result: Dictionary = generator.generate_question("addition", 1)
	assert_true(result.has("question_text"))
	assert_true(result.has("correct_answer"))
	assert_true(result.has("choices"))
	assert_string_contains(result["question_text"], "+", "addition category should dispatch to AdditionStrategy")


func test_dispatches_subtraction_to_subtraction_strategy() -> void:
	var result: Dictionary = generator.generate_question("subtraction", 1)
	assert_string_contains(result["question_text"], "-", "subtraction category should dispatch to SubtractionStrategy")


func test_dispatches_multiplication_to_multiplication_strategy() -> void:
	var result: Dictionary = generator.generate_question("multiplication", 1)
	assert_string_contains(result["question_text"], "x", "multiplication category should dispatch to MultiplicationStrategy")


func test_dispatches_division_to_division_strategy() -> void:
	var result: Dictionary = generator.generate_question("division", 1)
	assert_string_contains(result["question_text"], "/", "division category should dispatch to DivisionStrategy")


func test_dispatches_prime_to_prime_strategy() -> void:
	var result: Dictionary = generator.generate_question("prime", 1)
	assert_true(result.has("question_text"))
	assert_true(result.has("correct_answer"))
	assert_true(result.has("choices"))
	assert_eq(result["choices"].size(), 4)
	assert_string_contains(result["question_text"], "prime", "prime category should dispatch to PrimeStrategy")


func test_well_formed_dictionary_shape_for_known_category() -> void:
	var result: Dictionary = generator.generate_question("addition", 1)
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
	assert_true(categories.has("addition"))
	assert_true(categories.has("subtraction"))
	assert_true(categories.has("multiplication"))
	assert_true(categories.has("division"))


func test_get_categories_includes_prime_stage_c_category() -> void:
	var categories: Array = generator.get_categories()
	assert_true(categories.has("prime"), "'prime' should be registered in the category map")
