## Decimal MULTIPLICATION category strategy (Phase 15 FR15.5/FR15.6).
## Factors are picked FIRST with place counts whose SUM stays within the
## active cap, so the exact product's place count always respects the
## curve/override; low tiers favor whole-number-friendly structures.
class_name DecimalMultiplicationStrategy
extends DecimalStrategyBase


func _symbol() -> String:
	return "x"


func _pick_operands(tier: int, place_cap: int, magnitude_cap: int) -> Array:
	if tier == 1:
		# Whole x tenths friendly structures (e.g. 0.5 x 4).
		var tenths: DecimalValue = _scaled_random(1, magnitude_cap)
		var whole: DecimalValue = DecimalValue.from_scaled(
				randi_range(2, maxi(2, mini(9, magnitude_cap))), 0)
		if randf() < 0.5:
			return [tenths, whole]
		return [whole, tenths]
	for attempt in range(MAX_GENERATION_ATTEMPTS):
		# Place split: p1 + p2 <= cap keeps the product within the cap.
		var left_places: int = randi_range(0, place_cap)
		var right_places: int = randi_range(0, place_cap - left_places)
		var left_ceiling: int = maxi(1, mini(magnitude_cap,
				DecimalValue.pow10(left_places + (2 if tier >= 3 else 1))))
		var right_ceiling: int = maxi(1, mini(magnitude_cap,
				DecimalValue.pow10(right_places + (2 if tier >= 3 else 1))))
		var left := DecimalValue.from_scaled(randi_range(1, left_ceiling), left_places)
		var right := DecimalValue.from_scaled(randi_range(1, right_ceiling), right_places)
		return [left, right]
	return [
		DecimalValue.from_scaled(5, 1),
		DecimalValue.from_scaled(4, 0),
	]


func _compute(left: DecimalValue, right: DecimalValue) -> Variant:
	return left.mul(right)


func _error_candidates(left: DecimalValue, right: DecimalValue, correct: DecimalValue) -> Array:
	var candidates: Array = []
	# Wrong-operation results.
	candidates.append(left.add(right))
	candidates.append(left.sub(right).abs_value())
	# Ignoring the decimal points: integer product of the digit strings.
	candidates.append(DecimalValue.from_scaled(
			DecimalValue.digits_without_point(left)
					* DecimalValue.digits_without_point(right), 0))
	# Place-split slip: shift one factor's contribution by one place.
	var slipped: Variant = correct.shift10(2)
	if slipped != null:
		candidates.append(slipped)
	return candidates
