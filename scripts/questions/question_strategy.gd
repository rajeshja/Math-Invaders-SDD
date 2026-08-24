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
func generate(difficulty: int) -> Dictionary:
	push_error("QuestionStrategy.generate() called directly - subclasses must override generate(difficulty).")
	return _empty_result()


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
