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

@export_group("Scoring")
## Points awarded per correct answer in this level (Phase 17 FR17.1).
## Values below 1 clamp to 1 at resolution time (FR17.2).
@export var points_per_question: int = 1

@export_group("Wave Visuals")
## Per-wave enemy image overrides (Phase 18 FR18.1), index-aligned with
## category_sequence: element i lists texture path Strings for the wave at
## category_sequence[i]. Within a wave, spawn slot k uses element
## k % set.size() (cycling). Empty outer array / empty elements mean "use
## the category default sprite".
@export var wave_enemy_textures: Array = []

## Player ship image override (Phase 19 FR19.1): empty string keeps the
## default assets/images/ships/player_ship.png; a configured path must
## exist or the default is used with a one-time warning (FR19.2).
@export var player_ship_texture: String = ""

const DEFAULT_PLAYER_SHIP_TEXTURE := "res://assets/images/ships/player_ship.png"

## One-time warning guard shared across configs so a bad authored path
## logs once per session instead of at every resolution (FR19.2).
static var _warned_missing_player_ship := false


## Resolution rule (Phase 19 FR19.2): empty or missing paths fall back to
## the default ship texture; only genuinely missing configured paths warn,
## and only once. Unit-testable without the scene tree (NFR19.3).
func resolved_player_ship_texture() -> String:
	if player_ship_texture.is_empty():
		return DEFAULT_PLAYER_SHIP_TEXTURE
	if ResourceLoader.exists(player_ship_texture):
		return player_ship_texture
	if not _warned_missing_player_ship:
		_warned_missing_player_ship = true
		push_warning("LevelConfig: player ship '%s' is missing; using the default ship." % player_ship_texture)
	return DEFAULT_PLAYER_SHIP_TEXTURE


## Normalized per-index texture sets (FR18.1): one Array[String] per wave,
## empty when unset; malformed elements (non-String entries, non-Array
## elements) are tolerated by being dropped, so bad authored data can
## never crash spawning.
func resolved_wave_texture_sets() -> Array:
	var sets: Array = []
	for i in range(category_sequence.size()):
		var normalized: Array[String] = []
		if i < wave_enemy_textures.size() and wave_enemy_textures[i] is Array:
			for entry in wave_enemy_textures[i]:
				if entry is String and not (entry as String).is_empty():
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
