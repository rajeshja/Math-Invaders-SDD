## Decimal ADDITION category strategy (Phase 15 FR15.5/FR15.6).
## Tier 1 keeps both operands at tenths with small magnitudes; from
## Tier 2 on, mixed place counts make point alignment the skill.
class_name DecimalAdditionStrategy
extends DecimalStrategyBase


func _symbol() -> String:
	return "+"


func _pick_operands(tier: int, place_cap: int, magnitude_cap: int) -> Array:
	if tier == 1:
		return [
			_scaled_random(1, magnitude_cap),
			_scaled_random(1, magnitude_cap),
		]
	# Mixed place counts from Tier 2 (both within the active cap).
	var left_places: int = randi_range(1, place_cap)
	var right_places: int = randi_range(1, place_cap)
	return [
		_scaled_random(left_places, magnitude_cap),
		_scaled_random(right_places, magnitude_cap),
	]


func _compute(left: DecimalValue, right: DecimalValue) -> Variant:
	return left.add(right)


func _error_candidates(left: DecimalValue, right: DecimalValue, correct: DecimalValue) -> Array:
	var candidates: Array = []
	# Wrong-operation result: subtract instead.
	candidates.append(left.sub(right).abs_value())
	# Ignoring the decimal points: integer addition of digit strings.
	candidates.append(DecimalValue.from_scaled(
			DecimalValue.digits_without_point(left)
					+ DecimalValue.digits_without_point(right), 0))
	return candidates
