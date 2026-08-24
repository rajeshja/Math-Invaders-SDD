## Projectile shared by the player bullet and (via enemy_bullet.gd) the
## enemy bullet. Travels from its spawn position to a target position
## captured at spawn time in EXACTLY TRAVEL_TIME seconds regardless of
## distance - a fixed-duration tween, not a fixed velocity (FR4.12).
##
## The launch-time answer flow resolves score and next-question selection;
## player-bullet arrival confirms enemy destruction, while flight never gates
## question advancement or input.
## The target is a plain Vector2 (not a live reference to the enemy node)
## so the bullet's own movement never depends on the enemy still existing.
class_name Bullet
extends Node2D

signal arrived

## Shared fixed travel time for ALL bullets (player and enemy). Defined
## once here; enemy_bullet.gd reuses this exact constant so the two can
## never drift apart (NFR4.7).
const TRAVEL_TIME := 0.3

var target_position: Vector2 = Vector2.ZERO
var _traveling: bool = false


func launch(from_position: Vector2, to_position: Vector2) -> void:
	global_position = from_position
	target_position = to_position
	# Point the bullet sprite toward its target (sprites face up/-Y at rest).
	rotation = (target_position - from_position).angle() + PI / 2.0
	_traveling = true

	var tween := create_tween()
	tween.tween_property(
		self, "global_position", target_position, TRAVEL_TIME)
	tween.finished.connect(_on_travel_finished)


func _on_travel_finished() -> void:
	if not _traveling:
		return
	_traveling = false
	arrived.emit()
	queue_free()
