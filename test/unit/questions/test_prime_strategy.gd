## PrimeStrategy unit tests (Phase 8).
##
## Primality is cross-checked against an independent reference check so
## the tests never merely re-assert PrimeStrategy.is_prime().
extends GutTest

var strategy: PrimeStrategy


func before_each() -> void:
	strategy = PrimeStrategy.new()


## Deliberately naive reference primality check (trial division up to n-1),
## written independently of the strategy's optimized implementation.
func _reference_is_prime(n: int) -> bool:
	if n < 2:
		return false
	for divisor in range(2, n):
		if n % divisor == 0:
			return false
	return true


func test_correct_answer_is_genuinely_prime() -> void:
	for i in range(100):
		var result: Dictionary = strategy.generate(randi_range(1, 6))
		assert_true(
			_reference_is_prime(result["correct_answer"]),
			"correct_answer %d should be prime" % result["correct_answer"])


func test_exactly_one_choice_is_correct_and_other_three_are_not_prime() -> void:
	for i in range(100):
		var result: Dictionary = strategy.generate(randi_range(1, 6))
		var choices: Array = result["choices"]
		var correct: int = result["correct_answer"]
		var correct_count := 0
		for choice in choices:
			if choice == correct:
				correct_count += 1
			else:
				assert_false(
					_reference_is_prime(choice),
					"distractor %d should not be prime" % choice)
		assert_eq(correct_count, 1, "exactly one choice should equal correct_answer")


func test_choices_has_four_unique_entries() -> void:
	for i in range(100):
		var result: Dictionary = strategy.generate(randi_range(1, 6))
		var choices: Array = result["choices"]
		assert_eq(choices.size(), 4, "choices should have exactly 4 entries")
		var unique := {}
		for choice in choices:
			unique[choice] = true
		assert_eq(unique.size(), 4, "no duplicates within choices")


func test_question_text_asks_which_number_is_prime() -> void:
	var result: Dictionary = strategy.generate(1)
	assert_string_contains(result["question_text"], "prime")


func test_number_range_scales_with_difficulty() -> void:
	var low_max: int = 0
	var high_max: int = 0
	for i in range(50):
		low_max = max(low_max, strategy.generate(1)["correct_answer"])
		high_max = max(high_max, strategy.generate(5)["correct_answer"])
	assert_gt(high_max, low_max, "higher difficulty should be able to produce larger primes than low difficulty")


func test_is_prime_helper_matches_reference_across_range() -> void:
	for n in range(-5, 200):
		assert_eq(PrimeStrategy.is_prime(n), _reference_is_prime(n), "is_prime(%d) disagrees with reference" % n)


func test_is_prime_helper_known_values() -> void:
	assert_false(PrimeStrategy.is_prime(0))
	assert_false(PrimeStrategy.is_prime(1))
	assert_true(PrimeStrategy.is_prime(2))
	assert_true(PrimeStrategy.is_prime(3))
	assert_false(PrimeStrategy.is_prime(4))
	assert_true(PrimeStrategy.is_prime(23))
	assert_false(PrimeStrategy.is_prime(91), "91 = 7 x 13 is composite")
	assert_true(PrimeStrategy.is_prime(97))
