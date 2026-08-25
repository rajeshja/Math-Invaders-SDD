## Shared engine for the fraction MULTIPLICATION and DIVISION strategies
## (Phase 14 FR14.1--FR14.5). Subclasses supply the arithmetic hook, the
## display symbol, their tier-specific operand constructors, and their
## error-pattern distractor candidates; everything common - tiering, the
## Phase 13 assembly conventions (canonical string answers,
## question_segments / answer_layout stacked-render data, one consistent
## representation per question), and the value-distinctness filter - lives
## here once, reusing FractionValue for all math and formatting.
##
## Pure logic, no scene-tree dependency (NFR14.1).
class_name FractionMulDivStrategyBase
extends QuestionStrategy

const MAX_GENERATION_ATTEMPTS := 32
const MIXED_REPRESENTATION_CHANCE := 0.5
const MIXED_OPERAND_CHANCE_TIER_3 := 0.4
const MIXED_OPERAND_CHANCE_TIER_4 := 0.7

## Difficulty-curve ceilings when LevelConfig.max_operand_size does not
## pin them (option value 0 = defer to these curves). Products/quotients
## grow faster than sums, so operand caps stay modest.
const TIER_DENOMINATOR_CAPS := [8, 10, 12, 15]
const TIER_NUMERATOR_CAPS := [9, 9, 19, 29]


func generate(difficulty: int, options: Dictionary = {}) -> Dictionary:
	var tier: int = clampi(difficulty, 1, 4)
	var pinned_cap: int = _positive_int_option(options, "max_operand", 1, 0)

	var den_cap: int = maxi(mini(TIER_DENOMINATOR_CAPS[tier - 1],
			pinned_cap if pinned_cap >= 1 else TIER_DENOMINATOR_CAPS[tier - 1]), 2)
	var num_cap: int = maxi(mini(TIER_NUMERATOR_CAPS[tier - 1],
			pinned_cap if pinned_cap >= 1 else TIER_NUMERATOR_CAPS[tier - 1]), 1)

	# One consistent representation for EVERY value in this question, so
	# surface format never leaks which choice is correct (FR13.8 reuse).
	var use_mixed: bool = tier >= 2 and randf() < MIXED_REPRESENTATION_CHANCE

	for attempt in range(MAX_GENERATION_ATTEMPTS):
		var operands: Array = _pick_operands(tier, den_cap, num_cap)
		if operands.is_empty():
			continue
		var left: Dictionary = operands[0]
		var right: Dictionary = operands[1]
		var raw: Array = _compute(left, right)
		if raw[1] <= 0:
			continue
		var correct_value: FractionValue = FractionValue \
				.from_parts(raw[0], raw[1]).simplify()
		return _assemble_question(left, right, correct_value, use_mixed)

	# Attempt budget exhausted: deterministic safe item (never happens in
	# practice; keeps generate() total).
	var safe_left: Dictionary = {"numerator": 1, "denominator": 2}
	var safe_right: Dictionary = {"numerator": 1, "denominator": 2}
	var raw: Array = _compute(safe_left, safe_right)
	var safe_correct: FractionValue = FractionValue.from_parts(raw[0], raw[1]).simplify()
	return _assemble_question(safe_left, safe_right, safe_correct, false)


## -- Subclass contract ------------------------------------------------------

func _pick_operands(_tier: int, _den_cap: int, _num_cap: int) -> Array:
	push_error("FractionMulDivStrategyBase subclass must override _pick_operands().")
	return []


## Exact operation on RAW parts; returns [numerator, denominator].
func _compute(_left: Dictionary, _right: Dictionary) -> Array:
	push_error("FractionMulDivStrategyBase subclass must override _compute().")
	return [0, 1]


func _symbol() -> String:
	push_error("FractionMulDivStrategyBase subclass must override _symbol().")
	return "?"


## Error-pattern candidates specific to this operation (FR14.5), before
## the shared value-distinctness filtering.
func _error_candidates(_left: Dictionary, _right: Dictionary, _correct_value: FractionValue) -> Array:
	push_error("FractionMulDivStrategyBase subclass must override _error_candidates().")
	return []


## -- Operand helpers ---------------------------------------------------------

func _proper_fraction(den_cap: int, num_cap: int) -> Dictionary:
	var denominator: int = randi_range(2, den_cap)
	var ceiling: int = maxi(1, mini(num_cap, denominator - 1))
	return {"numerator": randi_range(1, ceiling), "denominator": denominator}


func _unit_fraction(den_cap: int) -> Dictionary:
	return {"numerator": 1, "denominator": randi_range(2, den_cap)}


func _whole_number(cap: int) -> Dictionary:
	return {"numerator": randi_range(1, maxi(1, mini(cap, 12))), "denominator": 1}


## Proper-or-improper operand; improper values present as mixed numbers.
func _maybe_improper(denominator: int, num_cap: int, mixed_chance: float) -> Dictionary:
	var proper_ceiling: int = maxi(1, mini(num_cap, denominator - 1))
	if randf() >= mixed_chance:
		return {"numerator": randi_range(1, proper_ceiling), "denominator": denominator}
	var improper_ceiling: int = mini(3 * denominator + 2, maxi(num_cap, proper_ceiling))
	if improper_ceiling < denominator:
		improper_ceiling = proper_ceiling
	return {"numerator": randi_range(denominator, improper_ceiling), "denominator": denominator}


func _is_whole(operand: Dictionary) -> bool:
	return operand.denominator == 1


func _is_unit(operand: Dictionary) -> bool:
	return operand.numerator == 1 and operand.denominator > 1


## -- Question assembly (Phase 13 conventions reused) --------------------------

func _assemble_question(left: Dictionary, right: Dictionary, correct_value: FractionValue, use_mixed: bool) -> Dictionary:
	# Operands render EXACTLY as generated (raw parts); answers canonicalize.
	var left_text: String = FractionValue.format_parts(
			left.numerator, left.denominator, use_mixed)
	var right_text: String = FractionValue.format_parts(
			right.numerator, right.denominator, use_mixed)

	var choices: Array = []
	var layouts: Array = []
	choices.append(correct_value.to_display_string(use_mixed))
	layouts.append(_layout_for(correct_value, use_mixed))
	for distractor in _filtered_distractors(left, right, correct_value):
		choices.append(distractor.to_display_string(use_mixed))
		layouts.append(_layout_for(distractor, use_mixed))

	var order: Array = range(choices.size())
	order.shuffle()
	var shuffled_choices: Array = []
	var shuffled_layouts: Array = []
	for index in order:
		shuffled_choices.append(choices[index])
		shuffled_layouts.append(layouts[index])

	return {
		"question_text": "What is %s %s %s?" % [left_text, _symbol(), right_text],
		"correct_answer": choices[0],
		"choices": shuffled_choices,
		"question_segments": [
			{"text": "What is "},
			_question_segment_for(left, use_mixed),
			{"text": " %s " % _symbol()},
			_question_segment_for(right, use_mixed),
			{"text": "?"},
		],
		"answer_layout": shuffled_layouts,
	}


func _question_segment_for(operand: Dictionary, use_mixed: bool) -> Dictionary:
	var layout := FractionValue.layout_parts(
			operand.numerator, operand.denominator, use_mixed)
	if layout.is_empty():
		return {"text": str(operand.numerator)}
	return {"fraction": layout}


func _layout_for(value: FractionValue, use_mixed: bool) -> Variant:
	var reduced := value.simplify()
	if reduced.is_whole():
		return null
	if use_mixed and reduced.is_improper():
		var parts := reduced.mixed_parts()
		return {
			"whole": parts.whole,
			"numerator": parts.numerator,
			"denominator": parts.denominator,
		}
	return {
		"numerator": reduced.numerator,
		"denominator": reduced.denominator,
	}


## Shared candidate pipeline: subclass error patterns plus the universal
## off-by-one patterns, filtered to three value-distinct, non-negative,
## not-value-equal-to-the-answer picks (FR14.2/FR14.5).
func _filtered_distractors(left: Dictionary, right: Dictionary, correct_value: FractionValue) -> Array:
	var candidates: Array = _error_candidates(left, right, correct_value)

	# Off-by-one numerator (both directions) and off-by-one denominator.
	var reduced := correct_value.simplify()
	candidates.append(FractionValue.from_parts(reduced.numerator + 1, reduced.denominator))
	candidates.append(FractionValue.from_parts(maxi(reduced.numerator - 1, 0), reduced.denominator))
	candidates.append(FractionValue.from_parts(reduced.numerator, reduced.denominator + 1))

	# Dropped fractional part: the whole-number-only misconception.
	if not reduced.is_whole():
		candidates.append(FractionValue.from_parts(reduced.numerator / reduced.denominator, 1))

	var picked: Array = []
	for candidate in candidates:
		if picked.size() >= 3:
			break
		var simplified: FractionValue = candidate.simplify()
		if simplified.denominator <= 0 or simplified.numerator < 0:
			continue
		if simplified.value_equals(correct_value):
			continue
		var duplicate := false
		for existing in picked:
			if simplified.value_equals(existing):
				duplicate = true
				break
		if duplicate:
			continue
		picked.append(simplified)

	var jitter := 1
	while picked.size() < 3:
		for direction in [1, -1]:
			if picked.size() >= 3:
				break
			var padded := FractionValue.from_parts(
					reduced.numerator + jitter * direction, reduced.denominator)
			if padded.simplify().numerator < 0:
				continue
			if padded.value_equals(correct_value):
				continue
			var duplicate := false
			for existing in picked:
				if padded.value_equals(existing):
					duplicate = true
					break
			if duplicate:
				continue
			picked.append(padded.simplify())
		jitter += 1
	return picked
