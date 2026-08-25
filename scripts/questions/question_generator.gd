## Dispatcher/factory for question strategies (Tech Stack §3).
##
## Holds a category-name -> strategy-instance map and exposes a single
## method, generate_question(), that the rest of the game calls. Callers
## (Main.gd, WaveManager.gd) never need to know which concrete strategy is
## running - this is the ONLY class they talk to for questions.
##
## This is also the canonical category registry (Phase 12 FR12.4/NFR12.3):
## adding a category means one strategy file, one registration line in
## _init(), and one display-name entry in DISPLAY_NAMES - no other call
## site changes.
class_name QuestionGenerator
extends RefCounted

## Player-facing labels per category key, used by the HUD wave-progress
## line (e.g. "Subtraction 6/10 remaining"). Unknown keys fall back to
## String.capitalize() via get_display_name() (Phase 12 FR12.4).
const DISPLAY_NAMES := {
	"integer_addition": "Addition",
	"integer_subtraction": "Subtraction",
	"integer_multiplication": "Multiplication",
	"integer_division": "Division",
	"prime": "Prime Numbers",
	"fraction_addition": "Fraction Addition",
	"fraction_subtraction": "Fraction Subtraction",
	"fraction_multiplication": "Fraction Multiplication",
	"fraction_division": "Fraction Division",
	"decimal_addition": "Decimal Addition",
	"decimal_subtraction": "Decimal Subtraction",
	"decimal_multiplication": "Decimal Multiplication",
	"decimal_division": "Decimal Division",
	"ratio_proportion": "Ratio & Proportion",
	"hcf_lcm": "HCF & LCM",
}

var _strategies: Dictionary = {}


func _init() -> void:
	_strategies["integer_addition"] = IntegerAdditionStrategy.new()
	_strategies["integer_subtraction"] = IntegerSubtractionStrategy.new()
	_strategies["integer_multiplication"] = IntegerMultiplicationStrategy.new()
	_strategies["integer_division"] = IntegerDivisionStrategy.new()
	_strategies["prime"] = PrimeStrategy.new()
	_strategies["fraction_addition"] = FractionAdditionStrategy.new()
	_strategies["fraction_subtraction"] = FractionSubtractionStrategy.new()
	_strategies["fraction_multiplication"] = FractionMultiplicationStrategy.new()
	_strategies["fraction_division"] = FractionDivisionStrategy.new()
	_strategies["decimal_addition"] = DecimalAdditionStrategy.new()
	_strategies["decimal_subtraction"] = DecimalSubtractionStrategy.new()
	_strategies["decimal_multiplication"] = DecimalMultiplicationStrategy.new()
	_strategies["decimal_division"] = DecimalDivisionStrategy.new()
	_strategies["ratio_proportion"] = RatioProportionStrategy.new()
	_strategies["hcf_lcm"] = HcfLcmStrategy.new()


## Returns the display label for a category key: the DISPLAY_NAMES entry
## when registered, otherwise String.capitalize() for unknown keys
## (Phase 12 FR12.4).
static func get_display_name(category: String) -> String:
	return DISPLAY_NAMES.get(category, category.capitalize())


## Returns the same Dictionary shape as QuestionStrategy.generate():
## { question_text, correct_answer, choices }.
##
## `options` carries LevelConfig's procedural-generation parameters
## (Phase 9 FR9.3/FR9.4) straight through to the strategy; strategies
## ignore keys they don't use and fall back to their difficulty curve
## when an option is absent.
##
## Unknown categories fail gracefully: logs an error and returns a safe
## empty/default Dictionary rather than crashing (Phase 2 FR2.3 / the
## test_question_generator.gd "unknown category" case).
func generate_question(category: String, difficulty: int, options: Dictionary = {}) -> Dictionary:
	if not _strategies.has(category):
		push_error("QuestionGenerator: unknown category '%s'" % category)
		return {
			"question_text": "",
			"correct_answer": 0,
			"choices": [],
		}
	var strategy: QuestionStrategy = _strategies[category]
	return strategy.generate(difficulty, options)


## Returns the list of category names this generator currently supports,
## in registration order. Used by WaveManager for sequencing (Phase 3).
func get_categories() -> Array:
	return _strategies.keys()
