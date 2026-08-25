## Canonical fraction value/representation helper shared by every fraction
## category strategy (Phase 13 FR13.2 - the ONLY place fraction math,
## reduction, and display formatting live; strategies must not implement
## their own gcd/reduction logic).
##
## A FractionValue is an exact rational number: an integer numerator over a
## positive integer denominator (sign is normalized onto the numerator).
## Instances are immutable-by-convention: operations return NEW instances
## (simplify()) rather than mutating receivers.
##
## Canonical display forms (FR13.1):
##   proper/improper  -> "3/4", "7/3"
##   mixed            -> "2 1/3"
##   whole numbers    -> "2" (single token, no "/1")
## Producers guarantee canonicity: simplified, no leading zeros, sign on
## the numerator only, single spaces in mixed form.
class_name FractionValue
extends RefCounted

var numerator: int
var denominator: int


## Builds a normalized value: denominator strictly positive (a negative
## denominator flips the sign into the numerator); denominator 0 pushes a
## clear error and falls back to a safe 0/1 rather than crashing.
static func from_parts(p_numerator: int, p_denominator: int) -> FractionValue:
	var value := FractionValue.new()
	if p_denominator == 0:
		push_error("FractionValue: denominator cannot be 0.")
		value.numerator = 0
		value.denominator = 1
		return value
	value.numerator = p_numerator
	value.denominator = p_denominator
	if p_denominator < 0:
		value.numerator = -p_numerator
		value.denominator = -p_denominator
	return value


## Greatest common divisor (Euclid) of two non-negative-normalized ints.
static func gcd(a: int, b: int) -> int:
	a = absi(a)
	b = absi(b)
	while b != 0:
		var t := b
		b = a % b
		a = t
	return a


## Least common multiple of two positive ints.
static func lcm(a: int, b: int) -> int:
	if a == 0 or b == 0:
		return 0
	return absi(a * b) / gcd(a, b)


## Returns a NEW fully-reduced instance (lowest terms; zero reduces to 0/1).
func simplify() -> FractionValue:
	var divisor := gcd(numerator, denominator)
	if divisor == 0:
		return FractionValue.from_parts(0, 1)
	return FractionValue.from_parts(numerator / divisor, denominator / divisor)


func is_whole() -> bool:
	return simplify().denominator == 1


## True when 0 < |numerator| < denominator after simplification.
func is_proper() -> bool:
	var reduced := simplify()
	return not reduced.is_whole() and absi(reduced.numerator) < reduced.denominator


## True when |numerator| > denominator > 1 after simplification (e.g. 7/3).
func is_improper() -> bool:
	var reduced := simplify()
	return not reduced.is_whole() and absi(reduced.numerator) > reduced.denominator


## Mixed-number decomposition {whole, numerator, denominator}: the whole
## part carries the sign, the remainder is non-negative, denominator stays
## positive (e.g. 7/3 -> {2, 1, 3}; -7/3 -> {-2, 1, 3}).
func mixed_parts() -> Dictionary:
	var reduced := simplify()
	var whole: int = reduced.numerator / reduced.denominator
	var remainder: int = reduced.numerator % reduced.denominator
	if remainder < 0:
		remainder = -remainder
		# Truncation already moved the sign into `whole`.
		if whole > 0:
			whole = -whole
	return {
		"whole": whole,
		"numerator": remainder,
		"denominator": reduced.denominator,
	}


## Exact value equality against another FractionValue (compares simplified
## forms, so 2/4 equals 1/2). Surface representation is irrelevant.
func value_equals(other: FractionValue) -> bool:
	if other == null:
		return false
	var a := simplify()
	var b := other.simplify()
	return a.numerator == b.numerator and a.denominator == b.denominator


## Canonical display string. When `mixed` is true, improper values render
## as "whole remainder" form ("2 1/3"); otherwise they render stacked-
## source form ("7/3"). Wholes always render as bare integers.
##
## Canonicalization ALWAYS simplifies first - this is the answer-side
## contract (FR13.1/FR13.9). For rendering question OPERANDS exactly as
## generated (e.g. keeping a like-denominator pair visually alike), use
## format_parts()/layout_parts() instead.
func to_display_string(mixed: bool = false) -> String:
	var reduced := simplify()
	return format_parts(reduced.numerator, reduced.denominator, mixed)


## Renders EXACTLY the given parts (no reduction) using the same display
## conventions: "n/d", "w n/d" when mixed and improper, bare integer when
## the denominator is 1.
static func format_parts(p_numerator: int, p_denominator: int, mixed: bool = false) -> String:
	if p_denominator == 0:
		push_error("FractionValue: denominator cannot be 0.")
		return "0"
	if p_denominator < 0:
		p_numerator = -p_numerator
		p_denominator = -p_denominator
	if p_denominator == 1:
		return str(p_numerator)
	var is_improper := absi(p_numerator) > p_denominator
	if mixed and is_improper:
		var whole: int = p_numerator / p_denominator
		var remainder: int = absi(p_numerator % p_denominator)
		return "%d %d/%d" % [whole, remainder, p_denominator]
	return "%d/%d" % [p_numerator, p_denominator]


## Stacking layout for EXACTLY the given parts (no reduction), matching
## format_parts(): {} for whole numbers (plain-text render),
## {whole, numerator, denominator} for mixed-improper, otherwise
## {numerator, denominator}.
static func layout_parts(p_numerator: int, p_denominator: int, mixed: bool = false) -> Dictionary:
	if p_denominator < 0:
		p_numerator = -p_numerator
		p_denominator = -p_denominator
	if p_denominator == 1:
		return {}
	var is_improper := absi(p_numerator) > p_denominator
	if mixed and is_improper:
		var whole: int = p_numerator / p_denominator
		var remainder: int = absi(p_numerator % p_denominator)
		return {
			"whole": whole,
			"numerator": remainder,
			"denominator": p_denominator,
		}
	return {
		"numerator": p_numerator,
		"denominator": p_denominator,
	}


func _to_string() -> String:
	return to_display_string(false)
