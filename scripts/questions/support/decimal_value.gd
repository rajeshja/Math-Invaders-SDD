## Canonical decimal value helper shared by every decimal category
## strategy (Phase 15 FR15.2/FR15.3/NFR15.3) - the ONLY place decimal
## scale/format logic lives.
##
## A DecimalValue is an exact rational with a power-of-ten denominator:
## an integer `scaled` over 10^places. ALL arithmetic runs on these scaled
## integers - binary floats never decide a correct answer. Instances are
## immutable-by-convention; operations return NEW values.
##
## Canonical display format (FR15.3): no trailing zeros after the point,
## single leading zero before it, no plus signs or separators. Whole
## results render as bare integer strings ("5", never "5.0" / "5.00"),
## applied uniformly so string equality stays safe.
class_name DecimalValue
extends RefCounted

var scaled: int
var places: int


## Builds value = p_scaled / 10^p_places. Negative places pushes an error
## and clamps to zero rather than crashing.
static func from_scaled(p_scaled: int, p_places: int) -> DecimalValue:
	var value := DecimalValue.new()
	if p_places < 0:
		push_error("DecimalValue: places cannot be negative.")
		p_places = 0
	value.scaled = p_scaled
	value.places = p_places
	return value


static func pow10(exponent: int) -> int:
	var result := 1
	for i in range(exponent):
		result *= 10
	return result


## The shared scale of two values: the larger place count.
func _common_places(other: DecimalValue) -> int:
	return maxi(places, other.places)


func _rescaled(target_places: int) -> int:
	return scaled * pow10(target_places - places)


## Exact sum on the common scale.
func add(other: DecimalValue) -> DecimalValue:
	var target := _common_places(other)
	return DecimalValue.from_scaled(_rescaled(target) + other._rescaled(target), target)


## Exact difference on the common scale (may be negative; callers order
## operands when negativity matters).
func sub(other: DecimalValue) -> DecimalValue:
	var target := _common_places(other)
	return DecimalValue.from_scaled(_rescaled(target) - other._rescaled(target), target)


## Exact product: scales multiply, place counts add.
func mul(other: DecimalValue) -> DecimalValue:
	return DecimalValue.from_scaled(scaled * other.scaled, places + other.places)


## Exact quotient, defined ONLY when the true rational terminates as a
## finite decimal (decimal division is built divisor-first so this always
## holds by construction). Returns null otherwise instead of rounding -
## no repeating/rounded answers can ever leak through.
func div_exact(other: DecimalValue) -> Variant:
	# value = (sa/10^pa) / (sb/10^pb) = (sa * 10^pb) / (sb * 10^pa).
	var numerator: int = scaled * pow10(other.places)
	var denominator: int = other.scaled * pow10(places)
	if denominator == 0:
		return null
	var negative: bool = (numerator < 0) != (denominator < 0)
	numerator = absi(numerator)
	denominator = absi(denominator)
	var divisor_gcd := _gcd(numerator, denominator)
	if divisor_gcd > 0:
		numerator /= divisor_gcd
		denominator /= divisor_gcd
	# Terminating iff the reduced denominator's prime factors are only
	# 2s and 5s. With den = 2^t x 5^f, multiplying the fraction by
	# 10^max(t,f) clears the denominator exactly once.
	var twos := 0
	var fives := 0
	while denominator % 2 == 0:
		denominator /= 2
		twos += 1
	while denominator % 5 == 0:
		denominator /= 5
		fives += 1
	if denominator != 1:
		return null
	var extra_places: int = maxi(twos, fives)
	var result_scaled: int = numerator
	if twos >= fives:
		for i in range(twos - fives):
			result_scaled *= 5
	else:
		for i in range(fives - twos):
			result_scaled *= 2
	return DecimalValue.from_scaled(-result_scaled if negative else result_scaled,
			extra_places)


static func _gcd(a: int, b: int) -> int:
	a = absi(a)
	b = absi(b)
	while b != 0:
		var t := b
		b = a % b
		a = t
	return a


## Exact comparison on the common scale: -1 / 0 / 1.
func compare(other: DecimalValue) -> int:
	var target := _common_places(other)
	var mine: int = _rescaled(target)
	var theirs: int = other._rescaled(target)
	if mine < theirs:
		return -1
	if mine > theirs:
		return 1
	return 0


func value_equals(other: DecimalValue) -> bool:
	if other == null:
		return false
	return compare(other) == 0


## Shifts the point by k positions: k > 0 multiplies by 10^k (scaled
## grows); k < 0 moves digits into deeper places (exactness preserved -
## trailing zeros simply strip away canonically).
func shift10(k: int) -> Variant:
	if k >= 0:
		return DecimalValue.from_scaled(scaled * pow10(k), places)
	return DecimalValue.from_scaled(scaled, places - k)


## Smallest representable step at this value's scale ("one unit in the
## last place"): 1 at scaled scale.
func smallest_step() -> DecimalValue:
	return DecimalValue.from_scaled(1, places)


func is_whole() -> bool:
	# Whole iff all trailing decimal digits are zero (or there are none).
	if places == 0:
		return true
	var divisor := pow10(places)
	return scaled % divisor == 0


## Magnitude copy with the sign removed.
func abs_value() -> DecimalValue:
	return DecimalValue.from_scaled(absi(scaled), places)


func to_canonical_string() -> String:
	return format_scaled(scaled, places)


## Canonical formatter for any scaled pair (FR15.3): strips trailing
## zeros, restores the leading zero, keeps whole numbers bare.
static func format_scaled(p_scaled: int, p_places: int) -> String:
	if p_places < 0:
		p_places = 0
	var sign := ""
	var magnitude: int = absi(p_scaled)
	if p_scaled < 0:
		sign = "-"
	if p_places == 0:
		return sign + str(magnitude)
	var divisor := pow10(p_places)
	var whole_part: int = magnitude / divisor
	var fraction_part: int = magnitude % divisor
	if fraction_part == 0:
		return sign + str(whole_part)
	var digits := str(fraction_part).pad_zeros(p_places)
	while digits.ends_with("0"):
		digits = digits.left(digits.length() - 1)
	return "%s%d.%s" % [sign, whole_part, digits]


## Integer formed by deleting the point ("12.34" -> 1234): models the
## ignore-the-decimal-points misconception for distractors (FR15.6).
static func digits_without_point(value: DecimalValue) -> int:
	var text := value.to_canonical_string().replace("-", "")
	if text.contains("."):
		text = text.replace(".", "")
	return int(text)


func _to_string() -> String:
	return to_canonical_string()
