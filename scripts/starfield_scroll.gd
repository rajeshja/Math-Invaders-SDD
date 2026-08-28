## Parallax starfield driver (Phase 10 FR9.2). Attached to the Main
## scene's Background node, above the static background_space sprite.
##
## Each layer is a single Sprite2D whose texture is vertically tileable;
## scrolling is done by sliding the texture's region rect (with texture
## repeat enabled), which loops seamlessly without any sprite juggling.
## Two layers at different speeds + opacities give the parallax feel.
## Purely presentational.
##
## The region offset DECREASES over time so the starfield appears to
## stream DOWNWARD past the camera, matching the player ship's forward
## (upward) motion. Scrolling the other way makes the ships look like
## they are flying backward.
class_name StarfieldScroll
extends Node2D

const TEXTURE_HEIGHT := 1280.0
const TEXTURE_WIDTH := 720.0

@export var far_scroll_speed: float = 22.0
@export var near_scroll_speed: float = 52.0

var _far_offset: float = 0.0
var _near_offset: float = 0.0

@onready var _far_layer: Sprite2D = $StarfieldFar
@onready var _near_layer: Sprite2D = $StarfieldNear


func _process(delta: float) -> void:
	_far_offset = _advance(_far_layer, _far_offset, far_scroll_speed, delta)
	_near_offset = _advance(_near_layer, _near_offset, near_scroll_speed, delta)


func _advance(layer: Sprite2D, offset: float, speed: float, delta: float) -> float:
	if layer == null or layer.texture == null:
		return offset
	offset = fposmod(offset - speed * delta, TEXTURE_HEIGHT)
	layer.region_rect = Rect2(0, offset, TEXTURE_WIDTH, TEXTURE_HEIGHT)
	return offset
