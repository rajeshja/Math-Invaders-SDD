## Fraction MULTIPLICATION category strategy (Phase 14 FR14.3/FR14.5).
## Tier ladders construct canceling structures first (mirroring how
## integer_division picks divisor/quotient first): whole/unit items at
## Tier 1, cross-cancel pairs at Tier 2, mixed/improper operands from
## Tier 3.
class_name FractionMultiplicationStrategy
extends FractionMulDivStrategyBase


func _symbol() -> String:
	return "x"


func _compute(left: Dictionary, right: Dictionary) -> Array:
	return [left.numerator * right.numerator, left.denominator * right.denominator]


func _pick_operands(tier: int, den_cap: int, num_cap: int) -> Array:
	match tier:
		1:
			return _pick_tier_one(den_cap, num_cap)
		2:
			return [_proper_fraction(den_cap, num_cap), _proper_fraction(den_cap, num_cap)]
		3:
			return _pick_with_mixed(den_cap, num_cap, MIXED_OPERAND_CHANCE_TIER_3)
		_:
			return _pick_with_mixed(den_cap, num_cap, MIXED_OPERAND_CHANCE_TIER_4)


## FR14.3 Tier 1: proper x whole with canceling structure (e.g. 1/2 x 6),
## or two fractions with an obvious cross-cancel (e.g. 1/2 x 2/5). At
## least one operand is a whole number or a unit fraction.
func _pick_tier_one(den_cap: int, num_cap: int) -> Array:
	if randf() < 0.5:
		var denominator: int = randi_range(2, maxi(2, mini(den_cap, 6)))
		var multiples_available: int = maxi(1, mini(mini(num_cap, 12), den_cap * 2) / denominator)
		var multiple: int = randi_range(1, multiples_available)
		var numerator := 1
		if multiple >= 2 and randf() < 0.4:
			numerator = mini(maxi(1, denominator - 1), num_cap)
		return [
			{"numerator": numerator, "denominator": denominator},
			{"numerator": maxi(1, multiple) * denominator, "denominator": 1},
		]
	for attempt in range(MAX_GENERATION_ATTEMPTS):
		var first_denominator: int = randi_range(2, maxi(2, den_cap - 2))
		var second_denominator: int = randi_range(first_denominator + 1, den_cap)
		var item := {
			"numerator": 1,
			"denominator": first_denominator,
		}
		var canceling := {
			"numerator": first_denominator,
			"denominator": second_denominator,
		}
		if randf() < 0.5:
			return [item, canceling]
		return [canceling, item]
	return [
		{"numerator": 1, "denominator": 2},
		{"numerator": 2, "denominator": 5},
	]


## FR14.3 Tiers 3-4+: operands may be mixed/improper; Tier 4 commonly lets
## both sides go improper.
func _pick_with_mixed(den_cap: int, num_cap: int, mixed_chance: float) -> Array:
	var first: Dictionary = _maybe_improper(randi_range(2, den_cap), num_cap, mixed_chance)
	var second_chance: float = MIXED_OPERAND_CHANCE_TIER_4 \
			if mixed_chance >= MIXED_OPERAND_CHANCE_TIER_4 else 0.0
	var second: Dictionary = _maybe_improper(randi_range(2, den_cap), num_cap, second_chance)
	return [first, second]


## FR14.5 error candidates for multiplication.
func _error_candidates(left: Dictionary, right: Dictionary, correct_value: FractionValue) -> Array:
	var candidates: Array = []

	# Cross-pairing misconception: multiply numerators but DIVIDE
	# denominators (and the mirrored pairing).
	var crossed_n: int = left.numerator * right.denominator
	var crossed_d: int = left.denominator * right.numerator
	if crossed_d > 0:
		candidates.append(FractionValue.from_parts(crossed_n, crossed_d))
		candidates.append(FractionValue.from_parts(crossed_d, crossed_n))

	# Add-across / subtract-across results.
	candidates.append(FractionValue.from_parts(
			left.numerator * right.denominator + right.numerator * left.denominator,
			left.denominator * right.denominator))
	candidates.append(FractionValue.from_parts(
			absi(left.numerator * right.denominator - right.numerator * left.denominator),
			left.denominator * right.denominator))

	# Straight-across on a wrong pairing: numerators multiplied,
	# denominators ADDED.
	candidates.append(FractionValue.from_parts(
			left.numerator * right.numerator,
			left.denominator + right.denominator))

	# Off-by-one FACTOR errors on the raw product.
	var straight_n: int = left.numerator * right.numerator
	var straight_d: int = left.denominator * right.denominator
	candidates.append(FractionValue.from_parts(straight_n + left.numerator, straight_d))
	candidates.append(FractionValue.from_parts(straight_n, straight_d + right.denominator))

	return candidates
