## Custom Resource defining a single game level (Phase 9 FR9.2/FR9.3).
##
## One .tres file per level under res://resources/levels/ centralizes
## everything LevelManager previously hardcoded or read from per-level
## Project Setting dictionaries: the category/wave sequence, difficulty,
## time budget, and attempts per question (FR9.1 migration).
##
## The resource also exposes procedural-math generation parameters so a
## non-programmer can tune question generation from the Inspector
## (NFR9.1): operand ceilings feed the existing strategies, while the
## fraction/decimal rules are carried through to strategies as forward-
## compatible options for the future fraction/decimal categories.
class_name LevelConfig
extends Resource

## Registry of every defined level, in order. Single source of truth for
## LevelManager (gameplay) and MainMenu (level-select population) alike.
const LEVEL_RESOURCE_PATHS: Array[String] = [
	"res://resources/levels/level_1.tres",
	"res://resources/levels/level_2.tres",
	"res://resources/levels/level_3.tres",
	"res://resources/levels/level_4.tres",
	"res://resources/levels/level_5.tres",
	"res://resources/levels/level_6.tres",
]

@export_group("Identity")
@export var level_number: int = 1

@export_group("Waves & Categories")
## Ordered wave/category sequence for this level.
@export var category_sequence: Array[String] = [
	"integer_addition", "integer_subtraction", "integer_multiplication", "integer_division"
]

@export_group("Difficulty")
## Difficulty value handed to QuestionGenerator.generate_question().
@export var difficulty: int = 1
## Ceiling on generated operands/factors/values; overrides each
## strategy's internal difficulty curve when >= 1 (FR9.3 "complexity").
@export var max_operand_size: int = 0

@export_group("Timing & Attempts")
## Total seconds for the level timer (replaces the per-level Project
## Setting override dictionary). Must be positive.
@export var time_limit_seconds: float = 120.0
## Allowed attempts per question (replaces the per-level Project Setting
## override dictionary). Minimum 1.
@export var tries_per_question: int = 1

@export_group("Fraction Rules")
## Forward-compatible knob for the future fractions category: when false,
## generated fraction questions keep like denominators.
@export var allow_unlike_denominators: bool = false

@export_group("Decimal Rules")
## Forward-compatible knob for the future decimals category: maximum
## number of places after the decimal point (0 = whole numbers only).
@export_range(0, 4) var max_decimal_places: int = 0


## Options Dictionary passed through QuestionGenerator into every
## strategy's generate() call (WaveManager -> generator -> strategy).
func generation_options() -> Dictionary:
	return {
		"max_operand": max_operand_size,
		"allow_unlike_denominators": allow_unlike_denominators,
		"max_decimal_places": max_decimal_places,
	}


## Loads and returns every registered level config in ascending level
## order. Missing/corrupt files are skipped with an error so a bad .tres
## cannot crash the game at startup.
static func load_all_levels() -> Array[LevelConfig]:
	var configs: Array[LevelConfig] = []
	for path in LEVEL_RESOURCE_PATHS:
		if not ResourceLoader.exists(path):
			push_error("LevelConfig: missing level resource '%s'." % path)
			continue
		var resource := load(path)
		if resource is LevelConfig:
			configs.append(resource)
		else:
			push_error("LevelConfig: '%s' is not a LevelConfig resource." % path)
	return configs


## Number of levels defined by LEVEL_RESOURCE_PATHS.
static func total_level_count() -> int:
	return LEVEL_RESOURCE_PATHS.size()
