## Decimal SUBTRACTION category strategy (Phase 15 FR15.5/FR15.6).
## Operands are ordered largest-first on exact scaled integers, so
## results are never negative; mixed place counts from Tier 2.
class_name DecimalSubtractionStrategy
extends DecimalStrategyBase


func _symbol() -> String:
	return "-"


func _pick_operands(tier: int, place_cap: int, magnitude_cap: int) -> Array:
	var left: DecimalValue
	var right: DecimalValue
	if tier == 1:
		left = _scaled_random(1, magnitude_cap)
		right = _scaled_random(1, magnitude_cap)
	else:
		left = _scaled_random(randi_range(1, place_cap), magnitude_cap)
		right = _scaled_random(randi_range(1, place_cap), magnitude_cap)
	# Ordered subtraction: results never negative (FR15.5).
	if left.compare(right) < 0:
		return [right, left]
	return [left, right]


func _compute(left: DecimalValue, right: DecimalValue) -> Variant:
	return left.sub(right)


func _error_candidates(left: DecimalValue, right: DecimalValue, correct: DecimalValue) -> Array:
	var candidates: Array = []
	# Wrong-operation result: add instead.
	candidates.append(left.add(right))
	# Swapped operand order, clamped non-negative.
	candidates.append(right.sub(left).abs_value())
	# Ignoring the decimal points: integer subtraction of digit strings.
	candidates.append(DecimalValue.from_scaled(
			absi(DecimalValue.digits_without_point(left)
					- DecimalValue.digits_without_point(right)), 0))
	return candidates
