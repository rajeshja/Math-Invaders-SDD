## HCF & LCM category strategy (Phase 16 FR16.4--FR16.6).
##
## Every question names its target explicitly (HCF or LCM, never
## ambiguous). Ground truth comes from Euclid's algorithm for the HCF and
## a x b / hcf(a, b) for the LCM. Number sets are CONSTRUCTED to satisfy
## each tier's structural rules: shared-factor pairs early (so the LCM is
## never just the product - multiplication must not be rewarded as an LCM
## shortcut), coprime pairs and three-number items arriving higher up.
## Distractors are mathematically meaningful near-misses (FR16.6).
##
## Pure logic, no scene-tree dependency (NFR16.1).
class_name HcfLcmStrategy
extends QuestionStrategy

const MAX_GENERATION_ATTEMPTS := 48


func generate(difficulty: int, options: Dictionary = {}) -> Dictionary:
	var tier: int = clampi(difficulty, 1, 4)
	var magnitude_cap: int = _positive_int_option(options, "max_operand", 1,
			_tier_number_cap(tier))

	var ask_lcm: bool = randf() < 0.5
	for attempt in range(MAX_GENERATION_ATTEMPTS):
		var item: Dictionary
		if ask_lcm:
			item = _build_lcm_item(tier, magnitude_cap)
		else:
			item = _build_hcf_item(tier, magnitude_cap)
		if not item.is_empty():
			return item

	return {
		"question_text": "What is the highest common factor (HCF) of 8 and 12?",
		"correct_answer": 4,
		"choices": [2, 4, 6, 24],
	}


func _tier_number_cap(tier: int) -> int:
	match tier:
		1: return 20
		2: return 100
		3: return 100
		_: return 150


static func gcd(a: int, b: int) -> int:
	a = absi(a)
	b = absi(b)
	while b != 0:
		var t := b
		b = a % b
		a = t
	return a


static func lcm(a: int, b: int) -> int:
	if a == 0 or b == 0:
		return 0
	return absi(a * b) / gcd(a, b)


static func lcm_of_three(a: int, b: int, c: int) -> int:
	return lcm(lcm(a, b), c)


## -- HCF forms ---------------------------------------------------------------

func _build_hcf_item(tier: int, cap: int) -> Dictionary:
	var count := 3 if tier >= 3 else 2
	var ceiling: int = mini(cap, _tier_number_cap(tier))
	for attempt in range(MAX_GENERATION_ATTEMPTS):
		# Shared-factor construction: numbers are h x distinct multipliers,
		# so the HCF is exactly h (never 1, never a full operand).
		var hcf: int = randi_range(2, maxi(2, ceiling / 4))
		var multipliers: Array = []
		while multipliers.size() < count:
			var m: int = randi_range(2, maxi(2, ceiling / hcf))
			if not multipliers.has(m):
				multipliers.append(m)
		if tier <= 2:
			# Keep pairwise coprime-ish so the HCF isn't accidentally larger.
			if gcd(multipliers[0], multipliers[1]) != 1:
				continue
		if count == 3:
			if gcd(multipliers[1], multipliers[2]) != 1 \
					or gcd(multipliers[0], multipliers[2]) != 1:
				continue
		var numbers: Array = []
		for m in multipliers:
			numbers.append(hcf * m)
		var number_text := "%d and %d" % [numbers[0], numbers[1]] if count == 2 \
				else "%d, %d and %d" % [numbers[0], numbers[1], numbers[2]]
		var candidates: Array = [
			lcm(numbers[0], numbers[1]),               # the classic HCF/LCM swap
			max(1, hcf + 1),                           # small offsets
			max(1, hcf - 1),
			gcd(numbers[0], numbers[1] - 1),           # near-miss factor
			hcf * 2,                                   # overshoot factor
			absi(numbers[0] - numbers[1]),             # difference
		]
		if count == 3:
			candidates.append(gcd(numbers[0], lcm(numbers[1], numbers[2])))
		return _assemble(
				"What is the highest common factor (HCF) of %s?" % number_text,
				hcf, candidates)
	return {}


## -- LCM forms -----------------------------------------------------------------

func _build_lcm_item(tier: int, cap: int) -> Dictionary:
	if tier >= 4:
		return _build_three_number_lcm(cap)
	for attempt in range(MAX_GENERATION_ATTEMPTS):
		var lcm_cap: int = 60 if tier == 1 else 240
		var first: int
		var second: int
		if tier <= 2:
			# Shared-factor pair: product != LCM by construction.
			var shared_ceiling: int = 5 if tier == 1 else 10
			var shared: int = randi_range(2, maxi(2, mini(cap, shared_ceiling)))
			first = shared * randi_range(1, maxi(1, mini(cap / shared, 6)))
			second = shared * randi_range(1, maxi(1, mini(cap / shared, 6)))
			if first == second or gcd(first / shared, second / shared) != 1:
				continue
			if lcm(first, second) > lcm_cap:
				continue
		else:
			# Tier 3 may include coprime pairs (LCM == product) now that the
			# shortcut has been earned; keep it occasional.
			first = randi_range(2, maxi(2, mini(cap, 30)))
			second = randi_range(2, maxi(2, mini(cap, 30)))
			if first == second:
				continue
			if gcd(first, second) == 1 and randf() > 0.3:
				continue
			if lcm(first, second) > lcm_cap:
				continue
		var answer_lcm: int = lcm(first, second)
		var candidates: Array = [
			gcd(first, second),                        # the classic LCM/HCF swap
			answer_lcm * 2,                            # common-but-not-least multiple
			first * second if first * second != answer_lcm else answer_lcm + first,
			max(1, answer_lcm - 1),
			answer_lcm + 1,
			absi(first - second),
			first + second,
		]
		return _assemble(
				"What is the lowest common multiple (LCM) of %d and %d?" % [first, second],
				answer_lcm, candidates)
	return {}


func _build_three_number_lcm(cap: int) -> Dictionary:
	for attempt in range(MAX_GENERATION_ATTEMPTS):
		var numbers: Array = [
			randi_range(2, maxi(2, mini(cap, 15))),
			randi_range(2, maxi(2, mini(cap, 15))),
			randi_range(2, maxi(2, mini(cap, 15))),
		]
		if numbers[0] == numbers[1] or numbers[1] == numbers[2] \
				or numbers[0] == numbers[2]:
			continue
		var answer: int = lcm_of_three(numbers[0], numbers[1], numbers[2])
		if answer > 360:
			continue
		var candidates: Array = [
			gcd(gcd(numbers[0], numbers[1]), numbers[2]),
			numbers[0] * numbers[1] * numbers[2] if
					numbers[0] * numbers[1] * numbers[2] != answer else answer + numbers[0],
			answer * 2,
			max(1, answer - 1),
			answer + 1,
		]
		return _assemble(
				"What is the lowest common multiple (LCM) of %d, %d and %d?" \
						% [numbers[0], numbers[1], numbers[2]],
				answer, candidates)
	return {}


## -- Shared assembly ------------------------------------------------------------

func _assemble(question_text: String, correct: int, candidates: Array) -> Dictionary:
	var choices: Array = [correct]
	var seen := {correct: true}
	for candidate in candidates:
		if choices.size() >= 4:
			break
		var value := int(candidate)
		if value <= 0 or value > 2000 or seen.has(value):
			continue
		seen[value] = true
		choices.append(value)
	var jitter := 1
	while choices.size() < 4:
		for direction in [1, -1]:
			if choices.size() >= 4:
				break
			var padded: int = correct + jitter * direction
			if padded > 0 and not seen.has(padded):
				seen[padded] = true
				choices.append(padded)
		jitter += 1
	choices.shuffle()
	return {
		"question_text": question_text,
		"correct_answer": correct,
		"choices": choices,
	}
