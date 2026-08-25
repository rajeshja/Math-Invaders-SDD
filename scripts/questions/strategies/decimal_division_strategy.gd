## Decimal DIVISION category strategy (Phase 15 FR15.5/FR15.6).
## Built DIVISOR-FIRST with a chosen quotient (mirroring integer_division's
## pattern): dividend = divisor x quotient exactly on scaled integers -
## terminating decimals only, divisors never zero, no rounding anywhere.
## The divisor/quotient place split keeps the derived dividend within the
## active place cap.
class_name DecimalDivisionStrategy
extends DecimalStrategyBase

## Quotients stay friendlier than operands at low tiers.
const QUOTIENT_PLACE_CAPS := [1, 2, 3, 3]


func _symbol() -> String:
	return "÷"


func _pick_operands(tier: int, place_cap: int, magnitude_cap: int) -> Array:
	var quotient_places: int = mini(QUOTIENT_PLACE_CAPS[tier - 1], place_cap)
	var divisor_places: int = randi_range(0, maxi(place_cap - quotient_places, 0))
	for attempt in range(MAX_GENERATION_ATTEMPTS):
		var quotient := _scaled_random(quotient_places, magnitude_cap)
		var divisor := _scaled_random(divisor_places, magnitude_cap)
		if divisor.compare(DecimalValue.from_scaled(0, 0)) == 0:
			continue  # divisors never zero (FR15.5)
		# Dividend = divisor x quotient exactly; terminating by construction.
		return [divisor.mul(quotient), divisor]
	return []


func _compute(dividend: DecimalValue, divisor: DecimalValue) -> Variant:
	return dividend.div_exact(divisor)


func _error_candidates(left: DecimalValue, right: DecimalValue, correct: DecimalValue) -> Array:
	var candidates: Array = []
	# Treating division like multiplication.
	candidates.append(left.mul(right))
	# Inverting the operands (divisor ÷ dividend mix-up); only usable when
	# exact, otherwise skipped safely.
	var inverted: Variant = right.div_exact(left)
	if inverted != null:
		candidates.append(inverted)
	# Ignoring the decimal points: integer division of digit strings.
	var left_digits: int = DecimalValue.digits_without_point(left)
	var right_digits: int = DecimalValue.digits_without_point(right)
	if right_digits != 0 and left_digits % right_digits == 0:
		candidates.append(DecimalValue.from_scaled(left_digits / right_digits, 0))
	return candidates
