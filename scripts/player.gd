## Player ship. Handles firing position/animation only - it does not decide
## WHEN to fire or WHAT is hit; Main.gd/WaveManager own that decision and
## simply ask the player where to spawn a bullet from (Tech Stack §5).
class_name Player
extends Node2D

@onready var _sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var _muzzle: Marker2D = $Muzzle if has_node("Muzzle") else null


## Global position bullets should spawn from. Falls back to this node's
## own position if no dedicated Muzzle marker exists yet.
func get_muzzle_position() -> Vector2:
	if _muzzle != null:
		return _muzzle.global_position
	return global_position


## Placeholder for firing juice (flash/recoil/animation). Intentionally a
## no-op stub until Phase 8 polish - kept as a single call site so visual
## feedback can be added later without touching callers.
func play_fire_feedback() -> void:
	pass
