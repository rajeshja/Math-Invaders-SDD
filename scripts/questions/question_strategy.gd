## Base class / interface for all math-category question strategies.
##
## Every concrete strategy (AdditionStrategy, SubtractionStrategy, ...)
## extends this and implements generate(difficulty). Strategies are pure
## logic with no dependency on the scene tree (Tech Stack §3, §8 / Phase 2
## NFR2.1), which is what makes them directly unit-testable with GUT.
class_name QuestionStrategy
extends RefCounted


## Returns a Dictionary shaped like:
## {
##   "question_text": String,
##   "correct_answer": int,
##   "choices": Array[int]  # length 4, exactly one entry == correct_answer
## }
##
## Subclasses MUST override this. The base implementation pushes an error
## and returns a safe empty/default dictionary rather than crashing, so a
## strategy that forgets to override generate() fails loudly but safely.
##
## `options` (Phase 9 FR9.3) carries LevelConfig's procedural-generation
## parameters (e.g. max_operand, allow_unlike_denominators,
## max_decimal_places) from the level resource into the strategy.
## Strategies fall back to their internal difficulty curve for any option
## that is absent/invalid, so generate(difficulty) keeps working unchanged.
func generate(difficulty: int, options: Dictionary = {}) -> Dictionary:
	push_error("QuestionStrategy.generate() called directly - subclasses must override generate(difficulty, options).")
	return _empty_result()


## Shared helper for option resolution: returns options[option_key] as an
## int when it is a valid integer >= minimum_value, otherwise fallback.
func _positive_int_option(options: Dictionary, option_key: String, minimum_value: int, fallback: int) -> int:
	if not options.has(option_key):
		return fallback
	var raw: Variant = options[option_key]
	if raw is bool or not (raw is int or raw is float):
		return fallback
	var value := int(raw)
	if value < minimum_value:
		return fallback
	return value


func _empty_result() -> Dictionary:
	return {
		"question_text": "",
		"correct_answer": 0,
		"choices": [],
	}


## Shared helper: builds a 4-choice array containing correct_answer plus
## unique distractor candidates, shuffled, with no duplicates anywhere in
## the final list (Spec §5 "Distractor & Difficulty Rules" /
## Phase 2 NFR2.3).
##
## candidate_distractors may contain more values than needed, duplicates,
## negative numbers, or values equal to correct_answer - this function
## filters all of that out and pads with small random jitter if it runs
## short of valid unique candidates.
func build_choices(correct_answer: int, candidate_distractors: Array) -> Array:
	var choices: Array = [correct_answer]
	var seen: Dictionary = {correct_answer: true}

	for candidate in candidate_distractors:
		if choices.size() >= 4:
			break
		var value: int = int(candidate)
		if value < 0:
			continue
		if seen.has(value):
			continue
		seen[value] = true
		choices.append(value)

	# Pad out to 4 unique choices if the candidate list ran short/collided.
	var jitter := 1
	while choices.size() < 4:
		for sign_val in [1, -1]:
			if choices.size() >= 4:
				break
			var padded: int = correct_answer + (jitter * sign_val)
			if padded >= 0 and not seen.has(padded):
				seen[padded] = true
				choices.append(padded)
		jitter += 1

	choices.shuffle()
	return choices
