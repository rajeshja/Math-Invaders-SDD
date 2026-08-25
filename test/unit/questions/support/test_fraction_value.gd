## FractionValue helper tests (Phase 13 FR13.2): normalization, reduction
## vs an independent reference implementation, mixed decomposition, value
## equality across representations, and canonical display strings.
extends GutTest

const FractionValueScript = preload("res://scripts/questions/support/fraction_value.gd")


func _fv(numerator: int, denominator: int) -> FractionValue:
	return FractionValueScript.from_parts(numerator, denominator)


## Independent reference reduction written straight from the definition.
func _reference_reduce(numerator: int, denominator: int) -> Array:
	if denominator < 0:
		numerator = -numerator
		denominator = -denominator
	var a: int = absi(numerator)
	var b: int = denominator
	while b != 0:
		var t: int = b
		b = a % b
		a = t
	if a == 0:
		return [0, 1]
	return [numerator / a, denominator / a]


func test_from_parts_normalizes_sign_into_numerator() -> void:
	var value := _fv(1, -2)
	assert_eq(value.denominator, 2, "denominator must be strictly positive")
	assert_eq(value.numerator, -1, "sign moves onto the numerator")


func test_simplify_matches_independent_reference_on_random_pairs() -> void:
	for i in range(200):
		var numerator: int = randi_range(-50, 50)
		var denominator: int = randi_range(-50, 50)
		if denominator == 0:
			continue
		var reduced := _fv(numerator, denominator).simplify()
		var expected := _reference_reduce(numerator, denominator)
		assert_eq(reduced.numerator, expected[0],
				"reduction of %d/%d" % [numerator, denominator])
		assert_eq(reduced.denominator, expected[1],
				"reduction of %d/%d" % [numerator, denominator])


func test_simplify_reduces_zero_to_zero_over_one() -> void:
	var reduced := _fv(0, 7).simplify()
	assert_eq(reduced.numerator, 0)
	assert_eq(reduced.denominator, 1)


func test_gcd_and_lcm_basics() -> void:
	assert_eq(FractionValueScript.gcd(12, 18), 6)
	assert_eq(FractionValueScript.gcd(7, 13), 1)
	assert_eq(FractionValueScript.lcm(4, 6), 12)
	assert_eq(FractionValueScript.lcm(3, 5), 15)


func test_classification_proper_improper_whole() -> void:
	assert_true(_fv(3, 4).is_proper())
	assert_false(_fv(7, 3).is_proper())
	assert_true(_fv(7, 3).is_improper())
	assert_false(_fv(3, 4).is_improper())
	assert_true(_fv(8, 4).is_whole())
	assert_false(_fv(7, 4).is_whole())


func test_mixed_decomposition() -> void:
	var parts: Dictionary = _fv(7, 3).mixed_parts()
	assert_eq(parts.whole, 2)
	assert_eq(parts.numerator, 1)
	assert_eq(parts.denominator, 3)


func test_mixed_decomposition_of_negative_carries_sign_on_whole() -> void:
	var parts: Dictionary = _fv(-7, 3).mixed_parts()
	assert_eq(parts.whole, -2)
	assert_eq(parts.numerator, 1)
	assert_eq(parts.denominator, 3)


func test_value_equality_across_representations() -> void:
	assert_true(_fv(2, 4).value_equals(_fv(1, 2)), "2/4 == 1/2 on simplified value")
	assert_true(_fv(6, 3).value_equals(_fv(2, 1)), "6/3 == 2")
	assert_true(_fv(9, 3).value_equals(_fv(3, 1)), "9/3 == 3")
	assert_false(_fv(2, 3).value_equals(_fv(3, 2)))
	assert_false(_fv(1, 2).value_equals(null))


func test_canonical_display_strings() -> void:
	assert_eq(_fv(3, 4).to_display_string(false), "3/4", "proper stays n/d")
	assert_eq(_fv(7, 3).to_display_string(false), "7/3", "improper renders stacked form")
	assert_eq(_fv(7, 3).to_display_string(true), "2 1/3", "mixed form is whole + space + remainder")
	assert_eq(_fv(4, 8).to_display_string(false), "1/2", "display implies simplification")
	assert_eq(_fv(8, 4).to_display_string(true), "2", "wholes render bare regardless of mode")
	assert_eq(_fv(2, 4).to_display_string(false), "1/2")


func test_unsimplified_input_never_leaks_into_display() -> void:
	for i in range(100):
		var factor: int = randi_range(1, 12)
		var value := _fv(3 * factor, 4 * factor)
		assert_eq(value.to_display_string(false), "3/4",
				"canonical output of 3*%d/4*%d" % [factor, factor])
