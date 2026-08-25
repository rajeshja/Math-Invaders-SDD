## Screen-shake utility on the Main scene's Camera2D (Phase 10 FR9.3).
##
## Trauma-based: shake() adds trauma, which decays linearly; the applied
## offset is random each frame scaled by trauma squared so small hits feel
## subtle and stacked hits ramp up smoothly. Purely presentational - it
## never blocks or delays any gameplay transition (NFR9.2).
class_name CameraShake
extends Camera2D

const MAX_OFFSET_PIXELS := 14.0
const TRAUMA_DECAY_PER_SECOND := 1.8
const MAX_TRAUMA := 1.0

var _trauma: float = 0.0


func _ready() -> void:
	make_current()


func _process(delta: float) -> void:
	if _trauma <= 0.0:
		offset = Vector2.ZERO
		return
	_trauma = maxf(0.0, _trauma - TRAUMA_DECAY_PER_SECOND * delta)
	var strength := _trauma * _trauma
	offset = Vector2(
		MAX_OFFSET_PIXELS * strength * _noise(),
		MAX_OFFSET_PIXELS * strength * _noise())


## Adds an amount of trauma (clamped). ~0.4 = a wrong-answer hit.
func shake(amount: float = 0.4) -> void:
	_trauma = minf(MAX_TRAUMA, _trauma + amount)


func _noise() -> float:
	return randf_range(-1.0, 1.0)
