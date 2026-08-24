## Player bullet/projectile. Travels in a straight line from its spawn
## position to a target position captured at spawn time, then emits
## `arrived` and frees itself.
##
## Purely presentational: whoever launched it resolves all gameplay (score,
## enemy destruction, next question) at launch time - the flight itself is
## feedback only and must never gate question advancement or input. The
## target is a plain Vector2 (not a live reference to the enemy node) so
## the bullet's own movement never depends on the enemy still existing.
class_name Bullet
extends Node2D

signal arrived

@export var speed_px_per_sec: float = 900.0
@export var arrival_distance: float = 6.0

var target_position: Vector2 = Vector2.ZERO
var _traveling: bool = false


func launch(from_position: Vector2, to_position: Vector2) -> void:
	global_position = from_position
	target_position = to_position
	_traveling = true
	# Point the bullet sprite toward its target.
	rotation = (target_position - from_position).angle() + PI / 2.0


func _process(delta: float) -> void:
	if not _traveling:
		return
	var to_target: Vector2 = target_position - global_position
	var distance: float = to_target.length()
	if distance <= arrival_distance:
		_traveling = false
		arrived.emit()
		queue_free()
		return
	var step: float = speed_px_per_sec * delta
	global_position += to_target.normalized() * min(step, distance)
