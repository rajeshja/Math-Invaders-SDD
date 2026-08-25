## Fraction SUBTRACTION category strategy (Phase 13 FR13.6).
## The base class orders operands largest-first, so results are never
## negative for this age group; all other behavior is shared with fraction
## addition via FractionAddSubStrategyBase.
class_name FractionSubtractionStrategy
extends FractionAddSubStrategyBase


func _apply(a: int, b: int) -> int:
	return a - b


func _opposite_apply(a: int, b: int) -> int:
	return a + b


func _symbol() -> String:
	return "-"


func _is_addition() -> bool:
	return false
