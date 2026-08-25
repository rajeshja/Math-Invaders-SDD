## Shared engine for the fraction ADDITION and SUBTRACTION strategies
## (Phase 13 FR13.6--FR13.9). Subclasses supply only the arithmetic sign
## and symbol; everything else - tier ladder, operand picking, exact
## common-denominator math, simplification, representation choice,
## misconception-driven distractors - lives here once.
##
## Pure logic, no scene-tree dependency (NFR13.1): all rendering data
## travels inside the returned Dictionary (question_segments /
## answer_layout) and QuestionPanel interprets it. All arithmetic runs on
## integer numerators over a common denominator - never floats.
class_name FractionAddSubStrategyBase
extends QuestionStrategy

const MAX_GENERATION_ATTEMPTS := 32
const MIXED_REPRESENTATION_CHANCE := 0.5
const MIXED_OPERAND_CHANCE_TIER_3 := 0.35
const MIXED_OPERAND_CHANCE_TIER_4 := 0.55

## Difficulty-curve ceilings when LevelConfig.max_operand_size does not
## pin them (option value 0 = defer to these curves).
const TIER_DENOMINATOR_CAPS := [10, 20, 20, 20]
const TIER_NUMERATOR_CAPS := [9, 19, 19, 29]

## Coprime pairs for Tier 4+ (LCD = product / non-trivial LCM).
const COPRIME_PAIRS := [
	[2, 3], [2, 5], [2, 7], [3, 4], [3, 5], [3, 7], [4, 5], [5, 6], [5, 7],
]


func generate(difficulty: int, options: Dictionary = {}) -> Dictionary:
	var tier: int = clampi(difficulty, 1, 4)
	var unlike_allowed: bool = bool(options.get("allow_unlike_denominators", false)) \
			and tier >= 3
	var pinned_cap: int = _positive_int_option(options, "max_operand", 1, 0)

	var den_cap: int = TIER_DENOMINATOR_CAPS[tier - 1]
	var num_cap: int = TIER_NUMERATOR_CAPS[tier - 1]
	if pinned_cap >= 1:
		den_cap = mini(den_cap, pinned_cap)
		num_cap = mini(num_cap, pinned_cap)
	den_cap = maxi(den_cap, 2)
	num_cap = maxi(num_cap, 1)

	var operands: Array = _pick_operands(tier, unlike_allowed, den_cap, num_cap)
	if not _is_addition():
		# Ordered subtraction: results are never negative (FR13.6).
		var a: Dictionary = operands[0]
		var b: Dictionary = operands[1]
		if a.numerator * b.denominator < b.numerator * a.denominator:
			operands = [b, a]

	# One consistent representation for EVERY value in this question, so
	# surface format never leaks which choice is correct (FR13.8).
	var use_mixed: bool = tier >= 2 and randf() < MIXED_REPRESENTATION_CHANCE

	var left: Dictionary = operands[0]
	var right: Dictionary = operands[1]
	var lcd: int = FractionValue.lcm(left.denominator, right.denominator)
	var scaled_left: int = left.numerator * lcd / left.denominator
	var scaled_right: int = right.numerator * lcd / right.denominator
	var correct_value: FractionValue = FractionValue \
			.from_parts(_apply(scaled_left, scaled_right), lcd) \
			.simplify()

	return _assemble_question(left, right, correct_value, use_mixed)


## -- Subclass contract ------------------------------------------------------

func _apply(a: int, b: int) -> int:
	push_error("FractionAddSubStrategyBase subclass must override _apply().")
	return 0


func _symbol() -> String:
	push_error("FractionAddSubStrategyBase subclass must override _symbol().")
	return "?"


## The OPPOSITE operation of this strategy, used for the wrong-operation
## distractor (FR13.9): subtraction for addition strategies, addition for
## subtraction strategies.
func _opposite_apply(a: int, b: int) -> int:
	push_error("FractionAddSubStrategyBase subclass must override _opposite_apply().")
	return 0


func _is_addition() -> bool:
	return false


## -- Operand picking (FR13.7 difficulty ladder) ------------------------------

func _pick_operands(tier: int, unlike_allowed: bool, den_cap: int, num_cap: int) -> Array:
	if not unlike_allowed:
		return _pick_like_denominator_operands(tier, den_cap, num_cap)
	if tier == 3:
		return _pick_related_multiple_operands(den_cap, num_cap)
	return _pick_coprime_operands(den_cap, num_cap)


## Tiers 1-2 (and every tier when allow_unlike_denominators is false):
## shared denominator, proper-fraction operands.
func _pick_like_denominator_operands(tier: int, den_cap: int, num_cap: int) -> Array:
	for attempt in range(MAX_GENERATION_ATTEMPTS):
		var denominator: int = randi_range(2, den_cap)
		var numerator_ceiling: int = mini(num_cap, denominator - 1)
		if numerator_ceiling < 1:
			continue
		var a_numerator: int = randi_range(1, numerator_ceiling)
		var b_numerator: int = randi_range(1, numerator_ceiling)
		if tier == 1 and _is_addition():
			# Tier 1 prefers results that stay proper after simplifying;
			# accept whatever we have after the attempt budget runs out.
			if a_numerator + b_numerator >= denominator:
				continue
		return [
			{"numerator": a_numerator, "denominator": denominator},
			{"numerator": b_numerator, "denominator": denominator},
		]
	var fallback_denominator: int = maxi(2, mini(den_cap, 4))
	return [
		{"numerator": 1, "denominator": fallback_denominator},
		{"numerator": 1, "denominator": fallback_denominator},
	]


## Tier 3: unlike denominators restricted to multiple-related pairs
## (halves & eighths style); operands occasionally presented mixed.
func _pick_related_multiple_operands(den_cap: int, num_cap: int) -> Array:
	for attempt in range(MAX_GENERATION_ATTEMPTS):
		var small: int = randi_range(2, maxi(2, mini(den_cap, 9)))
		var factor: int = randi_range(2, 4)
		var large: int = small * factor
		if large > den_cap:
			continue
		var first: Dictionary = _pick_operand_with_denominator(
				small, num_cap, MIXED_OPERAND_CHANCE_TIER_3)
		var second: Dictionary = _pick_operand_with_denominator(
				large, num_cap, MIXED_OPERAND_CHANCE_TIER_3)
		return [first, second] if randf() < 0.5 else [second, first]
	return [
		{"numerator": 1, "denominator": 2},
		{"numerator": 1, "denominator": 4},
	]


## Tier 4+: coprime pairs (LCD = product or non-trivial LCM), larger
## numerators, mixed-number operands common.
func _pick_coprime_operands(den_cap: int, num_cap: int) -> Array:
	var pool: Array = COPRIME_PAIRS.filter(func(pair):
		return pair[0] <= den_cap and pair[1] <= den_cap)
	if pool.is_empty():
		pool = COPRIME_PAIRS
	var pair: Array = pool[randi_range(0, pool.size() - 1)]
	var chance: float = MIXED_OPERAND_CHANCE_TIER_4
	var first: Dictionary = _pick_operand_with_denominator(pair[0], num_cap, chance)
	var second: Dictionary = _pick_operand_with_denominator(pair[1], num_cap, chance)
	return [first, second]


## One operand over a given denominator: usually a proper fraction, with a
## tier-scaled chance of being improper so it presents as a mixed number.
func _pick_operand_with_denominator(denominator: int, num_cap: int, mixed_chance: float) -> Dictionary:
	var proper_ceiling: int = maxi(1, mini(num_cap, denominator - 1))
	if randf() >= mixed_chance:
		return {"numerator": randi_range(1, proper_ceiling), "denominator": denominator}
	var improper_ceiling: int = mini(3 * denominator - 1, maxi(num_cap, proper_ceiling))
	if improper_ceiling < denominator:
		improper_ceiling = proper_ceiling
	return {"numerator": randi_range(denominator, improper_ceiling), "denominator": denominator}


## -- Question assembly (FR13.6/FR13.8/FR13.9) ---------------------------------

func _assemble_question(left: Dictionary, right: Dictionary, correct_value: FractionValue, use_mixed: bool) -> Dictionary:
	# Operands render EXACTLY as generated (raw parts), so like-denominator
	# questions stay visually alike (FR13.7); answers canonicalize instead.
	var left_text: String = FractionValue.format_parts(
			left.numerator, left.denominator, use_mixed)
	var right_text: String = FractionValue.format_parts(
			right.numerator, right.denominator, use_mixed)

	var choices: Array = []
	var layouts: Array = []
	var correct_string: String = _render(correct_value, use_mixed)
	var picked: Array = _pick_distractors(left, right, correct_value)
	choices.append(correct_string)
	layouts.append(_layout_for(correct_value, use_mixed))
	for distractor in picked:
		choices.append(_render(distractor, use_mixed))
		layouts.append(_layout_for(distractor, use_mixed))

	# Shuffle choices and their layouts together.
	var order: Array = range(choices.size())
	order.shuffle()
	var shuffled_choices: Array = []
	var shuffled_layouts: Array = []
	for index in order:
		shuffled_choices.append(choices[index])
		shuffled_layouts.append(layouts[index])

	return {
		"question_text": "What is %s %s %s?" % [left_text, _symbol(), right_text],
		"correct_answer": correct_string,
		"choices": shuffled_choices,
		"question_segments": _build_question_segments(left, right, use_mixed),
		"answer_layout": shuffled_layouts,
	}


func _build_question_segments(left: Dictionary, right: Dictionary, use_mixed: bool) -> Array:
	return [
		{"text": "What is "},
		_question_segment_for(left, use_mixed),
		{"text": " %s " % _symbol()},
		_question_segment_for(right, use_mixed),
		{"text": "?"},
	]


func _question_segment_for(operand: Dictionary, use_mixed: bool) -> Dictionary:
	var layout := FractionValue.layout_parts(
			operand.numerator, operand.denominator, use_mixed)
	if layout.is_empty():
		# Whole-number operand renders as a plain inline token.
		return {"text": str(operand.numerator)}
	return {"fraction": layout}


## Canonical string plus matching stacking data share this single source,
## so format can never differ between a choice and its layout (FR13.8).
func _render(value: FractionValue, use_mixed: bool) -> String:
	return value.to_display_string(use_mixed)


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


## Distractors modeled on real student errors (FR13.9), filtered so no
## distractor is value-equal to the correct answer or to another pick.
func _pick_distractors(left: Dictionary, right: Dictionary, correct_value: FractionValue) -> Array:
	var candidates: Array = []

	# Straight-across misconception: operate BOTH numerators and
	# denominators (clamped non-negative so kids see plausible values).
	var across_numerator: int = _apply(left.numerator, right.numerator)
	var across_denominator: int = _apply(left.denominator, right.denominator)
	if across_denominator > 0 and across_numerator >= 0:
		candidates.append(FractionValue.from_parts(across_numerator, across_denominator))

	# Wrong-operation result.
	var lcd: int = FractionValue.lcm(left.denominator, right.denominator)
	var scaled_left: int = left.numerator * lcd / left.denominator
	var scaled_right: int = right.numerator * lcd / right.denominator
	var wrong_operation: int = _opposite_apply(scaled_left, scaled_right)
	if wrong_operation >= 0:
		candidates.append(FractionValue.from_parts(wrong_operation, lcd))

	# Off-by-one numerator (both directions) and off-by-one denominator.
	var reduced_correct := correct_value.simplify()
	candidates.append(FractionValue.from_parts(reduced_correct.numerator + 1, reduced_correct.denominator))
	candidates.append(FractionValue.from_parts(maxi(reduced_correct.numerator - 1, 0), reduced_correct.denominator))
	candidates.append(FractionValue.from_parts(reduced_correct.numerator, reduced_correct.denominator + 1))
	if reduced_correct.denominator > 1:
		candidates.append(FractionValue.from_parts(reduced_correct.numerator, reduced_correct.denominator - 1))

	# Forgot-the-LCD error: operate raw numerators over a denominator that
	# appears in the operands (only meaningful for unlike-denominator items).
	if left.denominator != right.denominator:
		candidates.append(FractionValue.from_parts(
				maxi(_apply(left.numerator, right.numerator), 0), left.denominator))
		candidates.append(FractionValue.from_parts(
				maxi(_apply(left.numerator, right.numerator), 0), right.denominator))

	var picked: Array = []
	for candidate in candidates:
		if picked.size() >= 3:
			break
		var simplified: FractionValue = candidate.simplify()
		if simplified.denominator <= 0:
			continue
		if simplified.to_display_string(false).begins_with("-"):
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

	# Pad with small numerator jitters if the error patterns collided.
	var jitter := 1
	while picked.size() < 3:
		for direction in [1, -1]:
			if picked.size() >= 3:
				break
			var padded := FractionValue.from_parts(
					reduced_correct.numerator + jitter * direction,
					reduced_correct.denominator)
			if padded.to_display_string(false).begins_with("-"):
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
