## Ratio & Proportion category strategy (Phase 16 FR16.1--FR16.3).
##
## Tier ladder of question forms:
##   1  proportion solve      a : b = c : ? (integer scale factor)
##   2  two-part sharing      total T split a : b, find a named share
##   3  three-part sharing    total T split a : b : c, largest/smallest
##   4+ unit-rate scaling     "n items cost X; what do m items cost?"
##
## Totals are derived BACKWARDS from a chosen unit share so every stated
## total divides exactly (same derive-backwards pattern as the division
## strategies). Answers ride the original int pipeline - plain text, no
## stacked layout. Pure logic, no scene-tree dependency (NFR16.1).
class_name RatioProportionStrategy
extends QuestionStrategy

const MAX_GENERATION_ATTEMPTS := 32


func generate(difficulty: int, options: Dictionary = {}) -> Dictionary:
	var tier: int = clampi(difficulty, 1, 4)
	var magnitude_cap: int = _positive_int_option(options, "max_operand", 1,
			20 + tier * 15)

	for attempt in range(MAX_GENERATION_ATTEMPTS):
		var item: Dictionary = _build_item(tier, magnitude_cap)
		if not item.is_empty():
			return item

	# Deterministic safe item if the attempt budget somehow runs out.
	return {
		"question_text": "Share 24 in the ratio 1 : 2. What is the larger share?",
		"correct_answer": 16,
		"choices": [8, 12, 16, 18],
	}


func _build_item(tier: int, cap: int) -> Dictionary:
	match tier:
		1:
			return _build_proportion(cap)
		2:
			return _build_two_part_sharing(cap)
		3:
			return _build_three_part_sharing(cap)
		_:
			return _build_unit_rate(cap)


## -- Form builders -----------------------------------------------------------

## FR16.2 Tier 1: a : b = c : ? with c = a x k for an integer k.
func _build_proportion(cap: int) -> Dictionary:
	var left_term: int = randi_range(1, maxi(1, mini(cap / 2, 6)))
	var right_term: int = randi_range(1, maxi(1, mini(cap / 2, 8)))
	if left_term == right_term:
		right_term = mini(right_term + 1, maxi(2, mini(cap / 2, 9)))
	var scale: int = randi_range(2, maxi(2, mini(cap / maxi(left_term, 1), 5)))
	var known_left: int = left_term * scale
	var missing: int = right_term * scale

	var candidates: Array = [
		right_term * (scale + 1),                       # off-by-one scale
		max(1, right_term * (scale - 1)),               # off-by-one scale
		known_left * right_term,                        # cross-product misapplied
		max(1, missing + left_term),                    # wrong-part style slip
		known_left + right_term,                        # add-across slip
	]
	return _assemble(
			"If %d : %d = %d : ?, what is the missing number?" \
					% [left_term, right_term, known_left],
			missing, candidates)


## FR16.2 Tier 2: divide T in ratio a : b (T exactly divisible by a + b).
func _build_two_part_sharing(cap: int) -> Dictionary:
	for attempt in range(MAX_GENERATION_ATTEMPTS):
		var first: int = randi_range(1, maxi(1, mini(cap, 6)))
		var second: int = randi_range(1, maxi(1, mini(cap, 8)))
		if first == second:
			continue
		var unit: int = randi_range(2, maxi(2, mini(cap / (first + second), 9)))
		var total: int = (first + second) * unit
		var larger: int = maxi(first, second) * unit
		var smaller: int = mini(first, second) * unit
		var candidates: Array = [
			smaller,                                   # wrong-part share
			total,                                     # sum of parts
			unit,                                      # per-part value
			larger + unit,                             # off-by-one part
			max(1, larger - unit),
			total / maxi(1, maxi(first, second)) * mini(first, second),
		]
		return _assemble(
				"Share %d in the ratio %d : %d. What is the larger share?" \
						% [total, first, second],
				larger, candidates)
	return {}


## FR16.2 Tier 3: three-part ratio; find the largest or smallest share.
func _build_three_part_sharing(cap: int) -> Dictionary:
	for attempt in range(MAX_GENERATION_ATTEMPTS):
		var terms: Array = [
			randi_range(1, maxi(1, mini(cap, 6))),
			randi_range(1, maxi(1, mini(cap, 7))),
			randi_range(1, maxi(1, mini(cap, 8))),
		]
		if terms[0] == terms[1] or terms[1] == terms[2] or terms[0] == terms[2]:
			continue
		var term_sum: int = terms[0] + terms[1] + terms[2]
		var unit: int = randi_range(2, maxi(2, mini(cap / maxi(term_sum, 1), 9)))
		var total: int = term_sum * unit
		var shares: Array = [terms[0] * unit, terms[1] * unit, terms[2] * unit]
		var want_largest: bool = randf() < 0.5
		var correct: int = shares.max() if want_largest else shares.min()
		var word := "largest" if want_largest else "smallest"
		var candidates: Array = []
		for share in shares:
			if share != correct:
				candidates.append(share)               # other named shares
		candidates.append(total)                       # sum of all parts
		candidates.append(unit)                        # single part value
		candidates.append(correct + unit if want_largest else max(1, correct - unit))
		return _assemble(
				"Share %d in the ratio %d : %d : %d. What is the %s share?" \
						% [total, terms[0], terms[1], terms[2], word],
				correct, candidates)
	return {}


## FR16.2 Tier 4+: unit-rate scaling with clean integer rates.
func _build_unit_rate(cap: int) -> Dictionary:
	var rate: int = randi_range(2, maxi(2, mini(cap / 2, 12)))
	var given_count: int = randi_range(2, maxi(2, mini(cap / rate, 9)))
	var wanted_count: int = randi_range(1, maxi(1, mini(cap / rate, 12)))
	if wanted_count == given_count:
		wanted_count = maxi(1, wanted_count - 1)
	var given_total: int = given_count * rate
	var correct: int = wanted_count * rate

	var candidates: Array = [
		rate,                                          # answered with unit rate
		given_total,                                   # restated given total
		correct + rate,                                # off-by-one scale step
		max(1, correct - rate),
		given_total + wanted_count,                    # add-across slip
	]
	return _assemble(
			"%d items cost %d coins. How much do %d items cost at the same rate?" \
					% [given_count, given_total, wanted_count],
			correct, candidates)


## -- Shared assembly ----------------------------------------------------------

func _assemble(question_text: String, correct: int, candidates: Array) -> Dictionary:
	var choices: Array = [correct]
	var seen := {correct: true}
	for candidate in candidates:
		if choices.size() >= 4:
			break
		var value := int(candidate)
		if value <= 0 or seen.has(value):
			continue
		seen[value] = true
		choices.append(value)
	# Pad with nearby positive offsets if the patterns collided.
	var jitter := 1
	while choices.size() < 4:
		for direction in [1, -1]:
			if choices.size() >= 4:
				break
			var padded: int = correct + jitter * direction
			if padded > 0 and not seen.has(padded):
				seen[padded] = true
				choices.append(padded)
		jitter += 1
	choices.shuffle()
	return {
		"question_text": question_text,
		"correct_answer": correct,
		"choices": choices,
	}
