## DecimalValue helper tests (Phase 15 FR15.2/FR15.3): canonical formatting
## rules exhaustively, scaled arithmetic against hand-computed references,
## exactness contract of division, and format round-trips - all computed
## on integers, never binary floats.
extends GutTest

const DecimalValueScript = preload("res://scripts/questions/support/decimal_value.gd")


func _dv(scaled: int, places: int) -> DecimalValue:
	return DecimalValueScript.from_scaled(scaled, places)


func test_canonical_formatting_rules() -> void:
	# Trailing zeros are stripped ("0.5", never "0.50").
	assert_eq(_dv(50, 2).to_canonical_string(), "0.5")
	assert_eq(_dv(500, 3).to_canonical_string(), "0.5")
	# Single leading zero (never ".25").
	assert_eq(_dv(25, 2).to_canonical_string(), "0.25")
	assert_eq(_dv(5, 2).to_canonical_string(), "0.05")
	# Whole results render bare (no ".0").
	assert_eq(_dv(100, 2).to_canonical_string(), "1")
	assert_eq(_dv(7, 0).to_canonical_string(), "7")
	# Mixed digits keep their fraction.
	assert_eq(_dv(105, 2).to_canonical_string(), "1.05")
	assert_eq(_dv(1234, 3).to_canonical_string(), "1.234")
	# No plus signs or separators anywhere by construction.


func test_negative_values_format_with_sign_on_first_digit() -> void:
	assert_eq(_dv(-50, 2).to_canonical_string(), "-0.5")
	assert_eq(_dv(-100, 2).to_canonical_string(), "-1")


func test_add_and_sub_match_hand_computed_references() -> void:
	assert_eq(_dv(5, 1).add(_dv(25, 2)).to_canonical_string(), "0.75",
			"0.5 + 0.25 aligns scales exactly")
	assert_eq(_dv(15, 1).sub(_dv(25, 2)).to_canonical_string(), "1.25",
			"1.5 - 0.25")
	assert_true(_dv(15, 1).sub(_dv(25, 2)).value_equals(_dv(125, 2)))


func test_mul_matches_hand_computed_reference() -> void:
	var product := _dv(4, 1).mul(_dv(23, 2))
	assert_eq(product.scaled, 92, "0.4 x 0.23 -> 92 thousandths")
	assert_eq(product.places, 3)
	assert_eq(product.to_canonical_string(), "0.092")


func test_div_exact_only_terminates() -> void:
	var quotient: Variant = _dv(12, 1).div_exact(_dv(4, 0))
	assert_true(quotient is DecimalValue)
	assert_eq((quotient as DecimalValue).to_canonical_string(), "0.3",
			"1.2 / 4 = 0.3 exactly")

	# 1 / 0.3 repeats forever -> null, never rounded.
	assert_null(_dv(1, 0).div_exact(_dv(3, 1)))
	# Division by zero is refused outright.
	assert_null(_dv(5, 1).div_exact(_dv(0, 0)))


func test_division_by_construction_round_trip() -> void:
	for i in range(100):
		var divisor := _dv(randi_range(1, 99), randi_range(0, 2))
		var quotient := _dv(randi_range(1, 999), randi_range(0, 2))
		var dividend: DecimalValue = divisor.mul(quotient)
		var back: Variant = dividend.div_exact(divisor)
		assert_true(back is DecimalValue,
				"divisor-first construction always divides exactly")


func test_compare_orders_on_common_scale() -> void:
	assert_lt(_dv(5, 1).compare(_dv(75, 2)), 0, "0.5 < 0.75")
	assert_eq(_dv(50, 2).compare(_dv(5, 1)), 0, "0.50 == 0.5")
	assert_gt(_dv(50, 2).compare(_dv(25, 2)), 0, "0.50 > 0.25")
	assert_lt(_dv(12, 1).compare(_dv(30, 0)), 0, "1.2 < 3")


func test_shift10_moves_the_point_exactly() -> void:
	var up: Variant = _dv(25, 2).shift10(1)
	assert_eq((up as DecimalValue).to_canonical_string(), "2.5")
	var down: Variant = _dv(25, 2).shift10(-1)
	assert_eq((down as DecimalValue).to_canonical_string(), "0.025")
	var deep: Variant = _dv(500, 2).shift10(-2)
	assert_eq((deep as DecimalValue).to_canonical_string(), "0.05",
			"deeper shifts strip their trailing zeros canonically")


func test_is_whole_detects_trailing_zero_fractions() -> void:
	assert_true(_dv(100, 2).is_whole())
	assert_false(_dv(105, 2).is_whole())
	assert_true(_dv(7, 0).is_whole())


func test_digits_without_point_models_the_misconception() -> void:
	assert_eq(DecimalValueScript.digits_without_point(_dv(1234, 2)), 1234,
			"'12.34' reads as 1234 when the point is ignored")
	assert_eq(DecimalValueScript.digits_without_point(_dv(5, 1)), 5,
			"'0.5' reads as 5")


func test_canonical_strings_round_trip_through_integer_parsing() -> void:
	for i in range(200):
		var places: int = randi_range(0, 4)
		var ceiling: int = DecimalValueScript.pow10(places + 2)
		var scaled: int = randi_range(1, ceiling)
		var text: String = _dv(scaled, places).to_canonical_string()
		var dot: int = text.find(".")
		var parsed_places: int = 0 if dot < 0 else text.length() - dot - 1
		var compact := text.replace(".", "")
		var parsed_scaled: int = int(compact)
		# Reformat must produce the identical string (canonical fixed point).
		assert_eq(DecimalValueScript.format_scaled(parsed_scaled, parsed_places), text,
				"round trip of %s (%d/%d)" % [text, scaled, places])
