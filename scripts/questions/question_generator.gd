## Dispatcher/factory for question strategies (Tech Stack §3).
##
## Holds a category-name -> strategy-instance map and exposes a single
## method, generate_question(), that the rest of the game calls. Callers
## (Main.gd, WaveManager.gd) never need to know which concrete strategy is
## running - this is the ONLY class they talk to for questions.
##
## Adding a new category (e.g. Phase 8's "prime") means adding one new
## strategy file and one registration line here - no other call site
## changes (Phase 2 NFR2.2, Phase 3 FR3.5).
class_name QuestionGenerator
extends RefCounted

var _strategies: Dictionary = {}


func _init() -> void:
	_strategies["addition"] = AdditionStrategy.new()
	_strategies["subtraction"] = SubtractionStrategy.new()
	_strategies["multiplication"] = MultiplicationStrategy.new()
	_strategies["division"] = DivisionStrategy.new()
	_strategies["prime"] = PrimeStrategy.new()


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
