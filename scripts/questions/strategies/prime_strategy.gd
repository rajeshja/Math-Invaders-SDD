## Prime number identification category strategy (Stage C, Phase 8).
##
## The question shows 4 distinct numbers of which EXACTLY ONE is prime;
## the player must pick it. Unlike the arithmetic strategies, the choice
## set is built directly (rather than via build_choices()) so the padding
## jitter - which can land on a neighbouring prime by accident - can never
## introduce a second correct answer.
##
## Difficulty scaling follows Spec §5: the number range widens as
## difficulty rises. LevelManager drives difficulty; this file stays a
## pure-logic strategy with no scene-tree dependencies (Tech Stack §3).
class_name PrimeStrategy
extends QuestionStrategy

const CHOICE_COUNT := 4
const SMALLEST_PRIME := 2


func generate(difficulty: int) -> Dictionary:
	var clamped_difficulty: int = max(1, difficulty)
	var max_value: int = _max_value_for_difficulty(clamped_difficulty)

	var prime: int = _pick_random_prime(max_value)
	var choices: Array = _build_choice_set(prime, max_value)

	return {
		"question_text": "Which of these numbers is prime?",
		"correct_answer": prime,
		"choices": choices,
	}


## Trial-division primality check. Static so future Stage C strategies
## (factors/multiples) can reuse it without duplicating the math.
static func is_prime(n: int) -> bool:
	if n < SMALLEST_PRIME:
		return false
	if n == SMALLEST_PRIME:
		return true
	if n % 2 == 0:
		return false
	var divisor := 3
	while divisor * divisor <= n:
		if n % divisor == 0:
			return false
		divisor += 2
	return true


func _max_value_for_difficulty(difficulty: int) -> int:
	return 25 + (difficulty - 1) * 25


func _primes_up_to(max_value: int) -> Array:
	var primes: Array = []
	for n in range(SMALLEST_PRIME, max_value + 1):
		if is_prime(n):
			primes.append(n)
	return primes


func _pick_random_prime(max_value: int) -> int:
	var primes: Array = _primes_up_to(max_value)
	return primes[randi_range(0, primes.size() - 1)]


## Builds the full 4-number choice set: the answer plus unique NON-prime
## distractors only, guaranteeing exactly one correct choice (NFR8.1 -
## no duplicates, no nonsensical values).
func _build_choice_set(prime: int, max_value: int) -> Array:
	var choices: Array = [prime]
	var seen := {prime: true}
	var candidates: Array = range(SMALLEST_PRIME, max_value + 1)
	candidates.shuffle()
	for candidate in candidates:
		if choices.size() >= CHOICE_COUNT:
			break
		if seen.has(candidate) or is_prime(candidate):
			continue
		seen[candidate] = true
		choices.append(candidate)
	choices.shuffle()
	return choices
