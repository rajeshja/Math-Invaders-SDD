## Fraction ADDITION category strategy (Phase 13 FR13.6).
## All shared behavior - tier ladder, unlike-denominator gating, exact
## common-denominator math, simplification, representation choice, and
## misconception distractors - comes from FractionAddSubStrategyBase.
class_name FractionAdditionStrategy
extends FractionAddSubStrategyBase


func _apply(a: int, b: int) -> int:
	return a + b


func _opposite_apply(a: int, b: int) -> int:
	return absi(a - b)


func _symbol() -> String:
	return "+"


func _is_addition() -> bool:
	return true
