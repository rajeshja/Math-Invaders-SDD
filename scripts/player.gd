## Player ship. Handles firing position/animation only - it does not decide
## WHEN to fire or WHAT is hit; Main.gd/WaveManager own that decision and
## simply ask the player where to spawn a bullet from (Tech Stack §5).
class_name Player
extends Node2D

@onready var _sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var _muzzle: Marker2D = $Muzzle if has_node("Muzzle") else null

## Duration of the player-hit flash (FR4.11).
const HIT_FLASH_SECONDS := 0.15

var _hit_tween: Tween = null


## Global position bullets should spawn from. Falls back to this node's
## own position if no dedicated Muzzle marker exists yet.
func get_muzzle_position() -> Vector2:
	if _muzzle != null:
		return _muzzle.global_position
	return global_position


## Applies a per-level player ship image (Phase 19 FR19.3). Swaps ONLY the
## sprite texture - size, position, muzzle offset, and feedback animations
## are untouched (FR19.4). Invalid paths are ignored defensively so a bad
## configuration can never blank the ship.
func apply_ship_texture(path: String) -> void:
	if _sprite == null or path.is_empty():
		return
	if not ResourceLoader.exists(path):
		return
	var texture := load(path)
	if texture is Texture2D:
		_sprite.texture = texture


## Placeholder for firing juice (flash/recoil/animation). Intentionally a
## no-op stub until Phase 9 polish - kept as a single call site so visual
## feedback can be added later without touching callers.
func play_fire_feedback() -> void:
	pass


## Brief hit flash when the enemy return-fire bullet arrives (FR4.11).
## Fire-and-forget and purely presentational - it is NOT the damage
## mechanism; life loss stays event-driven via GameManager.take_damage().
func play_hit_flash() -> void:
	if _sprite == null:
		return
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	_sprite.modulate = Color(1.0, 0.25, 0.25, 1.0)
	_hit_tween = create_tween()
	_hit_tween.tween_property(
		_sprite, "modulate", Color(1, 1, 1, 1), HIT_FLASH_SECONDS)
