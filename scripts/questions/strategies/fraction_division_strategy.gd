## Fraction DIVISION category strategy (Phase 14 FR14.4/FR14.5).
## Divisor is generated first and is never zero (denominators >= 2,
## numerators >= 1 by construction); the true quotient is computed as the
## exact product with the reciprocal on integer parts, then simplified.
class_name FractionDivisionStrategy
extends FractionMulDivStrategyBase


func _symbol() -> String:
	return "÷"


func _compute(left: Dictionary, right: Dictionary) -> Array:
	# dividend x reciprocal(divisor): (n1/d1) / (n2/d2) = n1*d2 / (d1*n2).
	return [left.numerator * right.denominator, left.denominator * right.numerator]


func _pick_operands(tier: int, den_cap: int, num_cap: int) -> Array:
	match tier:
		1:
			return _pick_tier_one(den_cap, num_cap)
		2:
			return _pick_tier_two(den_cap)
		3:
			return _pick_general(den_cap, num_cap, MIXED_OPERAND_CHANCE_TIER_3)
		_:
			return _pick_general(den_cap, num_cap, MIXED_OPERAND_CHANCE_TIER_4)


## FR14.4 Tier 1: whole ÷ unit fraction and unit fraction ÷ whole
## (e.g. 3 ÷ 1/4, 1/4 ÷ 3) - the friendliest reciprocal forms.
func _pick_tier_one(den_cap: int, num_cap: int) -> Array:
	var unit := _unit_fraction(mini(den_cap, 6))
	var whole := {"numerator": randi_range(1, mini(9, num_cap * 3)), "denominator": 1}
	if randf() < 0.5:
		return [whole, unit]
	return [unit, whole]


## FR14.4 Tier 2: unit ÷ unit, plus proper ÷ proper arranged so the
## divisor's numerator cancels the dividend's denominator cleanly.
func _pick_tier_two(den_cap: int) -> Array:
	if randf() < 0.5:
		return [_unit_fraction(den_cap), _unit_fraction(den_cap)]
	for attempt in range(MAX_GENERATION_ATTEMPTS):
		var dividend_den: int = randi_range(2, maxi(2, den_cap - 2))
		var divisor_num: int = randi_range(2, mini(dividend_den, 6))
		var divisor_den: int = randi_range(dividend_den + 1, maxi(dividend_den + 1, den_cap))
		return [
			{"numerator": randi_range(1, dividend_den - 1), "denominator": dividend_den},
			{"numerator": divisor_num, "denominator": divisor_den},
		]
	return [
		{"numerator": 1, "denominator": 2},
		{"numerator": 1, "denominator": 3},
	]


## FR14.4 Tiers 3-4+: general proper ÷ proper; operands may be mixed
## numbers, commonly both at Tier 4+.
func _pick_general(den_cap: int, num_cap: int, mixed_chance: float) -> Array:
	var first_mixed_chance: float = mixed_chance if randf() < 0.6 else 0.0
	var second_mixed_chance: float = mixed_chance \
			if mixed_chance >= MIXED_OPERAND_CHANCE_TIER_4 else 0.0
	var dividend: Dictionary = _maybe_improper(randi_range(2, den_cap), num_cap, first_mixed_chance)
	var divisor: Dictionary = _maybe_improper(randi_range(2, den_cap), num_cap, second_mixed_chance)
	# Divisor must stay nonzero - numerators are always >= 1 here.
	return [dividend, divisor]


## FR14.5 error candidates for division.
func _error_candidates(left: Dictionary, right: Dictionary, correct_value: FractionValue) -> Array:
	var candidates: Array = []

	# Treating division like multiplication: straight across.
	candidates.append(FractionValue.from_parts(
			left.numerator * right.numerator,
			left.denominator * right.denominator))

	# Inverting the WRONG operand: reciprocal of the dividend instead.
	if left.numerator > 0:
		candidates.append(FractionValue.from_parts(
				left.denominator * right.denominator, left.numerator * right.numerator))

	# Add-across / subtract-across results.
	candidates.append(FractionValue.from_parts(
			left.numerator * right.denominator + right.numerator * left.denominator,
			left.denominator * right.denominator))
	candidates.append(FractionValue.from_parts(
			absi(left.numerator * right.denominator - right.numerator * left.denominator),
			left.denominator * right.denominator))

	# Divide-straight-across on a wrong pairing: divide numerators AND
	# denominators (scaled to stay integral where possible).
	if left.numerator % max(1, right.numerator) == 0 \
			and left.denominator % max(1, right.denominator) == 0:
		candidates.append(FractionValue.from_parts(
				left.numerator / max(1, right.numerator),
				left.denominator / max(1, right.denominator)))

	return candidates
