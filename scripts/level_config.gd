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
## Ordered wave/category sequence for this level. Each element is chosen
## from a dropdown of the canonical categories (Phase 21 FR21.7), kept in
## sync with QuestionGenerator.DISPLAY_NAMES (FR21.8).
@export_enum(
	"integer_addition", "integer_subtraction", "integer_multiplication", "integer_division",
	"prime", "fraction_addition", "fraction_subtraction", "fraction_multiplication",
	"fraction_division", "decimal_addition", "decimal_subtraction", "decimal_multiplication",
	"decimal_division", "ratio_proportion", "hcf_lcm"
) var category_sequence: Array[String] = [
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

@export_group("Scoring")
## Points awarded per correct answer in this level (Phase 17 FR17.1).
## Values below 1 clamp to 1 at resolution time (FR17.2).
@export var points_per_question: int = 1

@export_group("Wave Visuals")
## Per-wave enemy image overrides (Phase 18 FR18.1), index-aligned with
## category_sequence: element i lists Texture2D images for the wave at
## category_sequence[i]. Within a wave, spawn slot k uses element
## k % set.size() (cycling). Empty outer array / empty elements mean "use
## the category default sprite". Each inner element is edited through a
## native texture picker (Phase 21 FR21.2). The outer array is untyped
## because Godot does not support nested typed collections
## (Array[Array[Texture2D]]); each inner element is an Array[Texture2D].
@export var wave_enemy_textures: Array = []

## Player ship image override (Phase 19 FR19.1): null keeps the default
## ship; a configured texture is used as-is (Phase 21 FR21.1). Edited
## through a native texture picker with preview.
@export var player_ship_texture: Texture2D = null

## Preloaded default player ship (Phase 21 FR21.6): resolution needs no
## scene tree or filesystem lookup.
const DEFAULT_PLAYER_SHIP_TEXTURE: Texture2D = preload("res://assets/images/ships/player_ship.png")


## Resolution rule (Phase 19 FR19.2 / Phase 21 FR21.3): a configured texture
## is returned as-is; null falls back to the default ship. Because a
## Texture2D is either a valid loaded resource or null, no path-existence
## check or warning is needed. Unit-testable without the scene tree
## (NFR21.3).
func resolved_player_ship_texture() -> Texture2D:
	return player_ship_texture if player_ship_texture != null else DEFAULT_PLAYER_SHIP_TEXTURE


## Normalized per-index texture sets (FR18.1 / Phase 21 FR21.3): one
## Array[Texture2D] per wave, empty when unset; malformed elements
## (non-Texture2D entries, non-Array elements) are tolerated by being
## dropped, so bad authored data can never crash spawning.
func resolved_wave_texture_sets() -> Array:
	var sets: Array = []
	for i in range(category_sequence.size()):
		var normalized: Array[Texture2D] = []
		if i < wave_enemy_textures.size() and wave_enemy_textures[i] is Array:
			for entry in wave_enemy_textures[i]:
				if entry is Texture2D:
					normalized.append(entry)
		sets.append(normalized)
	return sets

## One-time warning guard so an invalid authored value logs exactly once
## instead of spamming every level start (FR17.2).
static var _warned_invalid_points := false


## Single validation path (FR17.2): values below 1 resolve to 1 with a
## one-time push_warning; valid values pass through untouched.
func resolved_points_per_question() -> int:
	if points_per_question < 1:
		if not _warned_invalid_points:
			_warned_invalid_points = true
			push_warning(
					"LevelConfig: points_per_question %d is invalid; clamping to 1."
							% points_per_question)
		return 1
	return points_per_question


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
