## Full-screen damage flash overlay (Phase 10 FR9.3). A CanvasLayer holding
## a transparent ColorRect; flash() briefly tints the screen (default: red)
## on top of the Phase 4 enemy-fire animation and player-hit flash, which
## remain the primary damage feedback. Purely presentational.
class_name FlashOverlay
extends CanvasLayer

const DEFAULT_COLOR := Color(0.85, 0.1, 0.12, 1.0)
const DEFAULT_DURATION := 0.28
const PEAK_ALPHA := 0.32

@onready var _rect: ColorRect = $Rect

var _tween: Tween = null


func flash(color: Color = DEFAULT_COLOR, duration: float = DEFAULT_DURATION) -> void:
	if _rect == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_rect.color = Color(color.r, color.g, color.b, PEAK_ALPHA)
	_tween = create_tween()
	_tween.tween_property(_rect, "color:a", 0.0, duration)
