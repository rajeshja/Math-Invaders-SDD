## Shared engine for the four DECIMAL strategies (Phase 15
## FR15.1--FR15.6). Subclasses supply the display symbol, their tier-aware
## operand constructor, the exact computation hook, and operation-specific
## error-pattern candidates; everything common - tiering, the
## max_decimal_places override, canonical string assembly, and the
## unique/non-negative distractor filter - lives here once, riding the
## shared DecimalValue scaled-integer helper (NFR15.3).
##
## Questions render as PLAIN text (no stacked layout): the returned
## Dictionary carries only question_text / correct_answer / choices, all
## canonically formatted strings compared by exact equality (Phase 13
## answer-value model reuse).
##
## Pure logic, no scene-tree dependency (NFR15.1).
class_name DecimalStrategyBase
extends QuestionStrategy

const MAX_GENERATION_ATTEMPTS := 32

## Difficulty curve (FR15.4): decimal-place ceiling per tier; operand
## magnitude ceiling (scaled to that tier's places) grows alongside.
const TIER_PLACE_CAPS := [1, 2, 3, 4]
const TIER_SCALED_MAGNITUDE_CAPS := [99, 999, 9999, 99999]


func generate(difficulty: int, options: Dictionary = {}) -> Dictionary:
	var tier: int = clampi(difficulty, 1, 4)
	var place_cap: int = TIER_PLACE_CAPS[tier - 1]
	# LevelConfig.max_decimal_places (> 0) overrides the tier curve,
	# exactly like max_operand_size does for integer strategies (FR15.4).
	var configured_cap: int = _positive_int_option(options, "max_decimal_places", 1, 0)
	if configured_cap >= 1:
		place_cap = mini(place_cap, configured_cap)
	var magnitude_cap: int = TIER_SCALED_MAGNITUDE_CAPS[tier - 1]

	for attempt in range(MAX_GENERATION_ATTEMPTS):
		var operands: Array = _pick_operands(tier, place_cap, magnitude_cap)
		if operands.is_empty():
			continue
		var left: DecimalValue = operands[0]
		var right: DecimalValue = operands[1]
		var result: Variant = _compute(left, right)
		if result == null or not (result is DecimalValue):
			continue
		return _assemble_question(left, right, result)

	var safe_left: DecimalValue = DecimalValue.from_scaled(12, 1)
	var safe_right: DecimalValue = DecimalValue.from_scaled(3, 1)
	return _assemble_question(safe_left, safe_right, _compute(safe_left, safe_right))


## -- Subclass contract ------------------------------------------------------

func _symbol() -> String:
	push_error("DecimalStrategyBase subclass must override _symbol().")
	return "?"


func _pick_operands(_tier: int, _place_cap: int, _magnitude_cap: int) -> Array:
	push_error("DecimalStrategyBase subclass must override _pick_operands().")
	return []


## Exact operation returning a DecimalValue (or null when undefined).
func _compute(_left: DecimalValue, _right: DecimalValue) -> Variant:
	push_error("DecimalStrategyBase subclass must override _compute().")
	return null


## Operation-specific misconception candidates (FR15.6), before the
## shared filtering.
func _error_candidates(_left: DecimalValue, _right: DecimalValue, _correct: DecimalValue) -> Array:
	push_error("DecimalStrategyBase subclass must override _error_candidates().")
	return []


## -- Shared operand helpers ---------------------------------------------------

func _scaled_random(places: int, magnitude_cap: int) -> DecimalValue:
	# Nonzero values only: zero operands make dull questions.
	var ceiling: int = maxi(1, mini(magnitude_cap, DecimalValue.pow10(places) - 1))
	return DecimalValue.from_scaled(randi_range(1, ceiling), places)


## -- Assembly & distractors ----------------------------------------------------

func _assemble_question(left: DecimalValue, right: DecimalValue, correct: DecimalValue) -> Dictionary:
	var choices: Array = [correct.to_canonical_string()]
	for distractor in _filtered_distractors(left, right, correct):
		choices.append(distractor.to_canonical_string())
	choices.shuffle()
	return {
		"question_text": "What is %s %s %s?" % [
			left.to_canonical_string(), _symbol(), right.to_canonical_string()],
		"correct_answer": correct.to_canonical_string(),
		"choices": choices,
	}


## Shared pipeline (FR15.6): universal misconceptions plus subclass error
## patterns, filtered to three unique strings distinct from the answer.
func _filtered_distractors(left: DecimalValue, right: DecimalValue, correct: DecimalValue) -> Array:
	var candidates: Array = _error_candidates(left, right, correct)

	# Place-value shifts of the true result.
	var up: Variant = correct.shift10(1)
	if up != null:
		candidates.append(up)
	var down: Variant = correct.shift10(-1)
	if down != null:
		candidates.append(down)

	# Off-by-one in the final decimal place (both directions).
	candidates.append(correct.add(correct.smallest_step()))
	candidates.append(correct.sub(correct.smallest_step()))

	var picked: Array = []
	for candidate in candidates:
		if picked.size() >= 3:
			break
		if candidate == null or not (candidate is DecimalValue):
			continue
		var value: DecimalValue = candidate
		if value.compare(DecimalValue.from_scaled(0, 0)) < 0:
			continue
		if value.value_equals(correct):
			continue
		var duplicate := false
		for existing in picked:
			if value.value_equals(existing):
				duplicate = true
				break
		if duplicate:
			continue
		picked.append(value)

	# Pad with last-place jitters if the patterns collided.
	var jitter := 2
	while picked.size() < 3:
		for direction in [1, -1]:
			if picked.size() >= 3:
				break
			var padded: DecimalValue = correct.add(
					DecimalValue.from_scaled(jitter * direction, correct.places))
			if padded.compare(DecimalValue.from_scaled(0, 0)) < 0:
				continue
			if padded.value_equals(correct):
				continue
			var duplicate := false
			for existing in picked:
				if padded.value_equals(existing):
					duplicate = true
					break
			if duplicate:
				continue
			picked.append(padded)
		jitter += 1
	return picked
