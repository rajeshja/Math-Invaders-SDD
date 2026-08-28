## Per-instance enemy template. NOT a manager - up to 10 instances of this
## script run concurrently within a wave, each independent, spawned and
## tracked by WaveManager.gd (Tech Stack §5).
##
## Holds a reference to this enemy's own linked question and its own
## category, and knows how to be destroyed. It does
## NOT decide which enemy is "active," track wave state, or generate
## questions - that's WaveManager's job.
class_name Enemy
extends Node2D

## Texture paths per category, matching the per-instance texture-swap
## approach from Tech Stack §7 (single enemy.tscn/enemy.gd serves every
## category - only the Sprite2D texture changes).
const CATEGORY_TEXTURES := {
	"integer_addition": "res://assets/images/enemies/enemy_ship_addition.png",
	"integer_subtraction": "res://assets/images/enemies/enemy_ship_subtraction.png",
	"integer_multiplication": "res://assets/images/enemies/enemy_ship_multiplication.png",
	"integer_division": "res://assets/images/enemies/enemy_ship_division.png",
	"prime": "res://assets/images/enemies/enemy_ship_prime.png",
	"fraction_addition": "res://assets/images/enemies/enemy_ship_fraction_addition.png",
	"fraction_subtraction": "res://assets/images/enemies/enemy_ship_fraction_subtraction.png",
	"fraction_multiplication": "res://assets/images/enemies/enemy_ship_fraction_multiplication.png",
	"fraction_division": "res://assets/images/enemies/enemy_ship_fraction_division.png",
	"decimal_addition": "res://assets/images/enemies/enemy_ship_decimal_addition.png",
	"decimal_subtraction": "res://assets/images/enemies/enemy_ship_decimal_subtraction.png",
	"decimal_multiplication": "res://assets/images/enemies/enemy_ship_decimal_multiplication.png",
	"decimal_division": "res://assets/images/enemies/enemy_ship_decimal_division.png",
	"ratio_proportion": "res://assets/images/enemies/enemy_ship_ratio_proportion.png",
	"hcf_lcm": "res://assets/images/enemies/enemy_ship_hcf_lcm.png",
}

## The math category this enemy belongs to (e.g. "integer_addition").
var category: String = ""

## The question Dictionary this enemy is linked to:
## { question_text, correct_answer, choices }. Set by WaveManager at spawn
## (or just-in-time when this enemy becomes active).
var linked_question: Dictionary = {}

@onready var _sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null

## Brief fire telegraph duration (~0.1 s) played on wrong answers (FR4.11).
const FIRE_TELEGRAPH_SECONDS := 0.1

## One-shot destruction animation spawned at this enemy's position on
## destroy() (Phase 10 FR9.1). WaveManager removes this enemy from the
## container BEFORE calling destroy(), so the node itself can no longer
## play anything - the effect is a standalone scene added to the scene's
## "fx_host" node (registered via the "fx_host" group) instead. When no
## host exists (unit tests, headless doubles) the visual is simply skipped
## and destruction behaves exactly as before, per NFR9.1.
const EXPLOSION_EFFECT_SCENE := preload("res://scenes/explosion_effect.tscn")

var _telegraph_tween: Tween = null
var _fx_host: Node = null


func _ready() -> void:
	_fx_host = get_tree().get_first_node_in_group("fx_host")


## Sets category + linked question and swaps the sprite texture for the
## category (Phase 2 FR2.7 / Phase 3 FR3.6). `texture_override`
## (Phase 18 FR18.5) applies AFTER the category default so configured
## per-wave images win; null overrides change nothing (Phase 21 FR21.4).
func setup(p_category: String, p_question: Dictionary, texture_override: Texture2D = null) -> void:
	category = p_category
	linked_question = p_question
	_apply_category_texture()
	if texture_override != null:
		_apply_override_texture(texture_override)


func _apply_category_texture() -> void:
	if _sprite == null:
		return
	var path: String = CATEGORY_TEXTURES.get(category, "")
	if path == "":
		return
	if ResourceLoader.exists(path):
		_sprite.texture = load(path)


func _apply_override_texture(texture: Texture2D) -> void:
	if _sprite == null:
		return
	_sprite.texture = texture


## Destroys this enemy instance. Bullet-travel-then-destroy timing is
## orchestrated by whoever calls this (WaveManager, via bullet.gd's
## arrival), not by the enemy itself.
##
## Phase 10 FR9.1: the caller removes this node from the tree first, so
## the explosion plays from a standalone effect scene parented to the
## cached "fx_host" node at this enemy's former position. Fire-and-forget:
## queue_free() happens immediately and nothing waits on the animation
## (NFR9.2 - HUD/wave updates already fired before this point).
func destroy() -> void:
	_spawn_explosion()
	queue_free()


func _spawn_explosion() -> void:
	if _fx_host == null or not is_instance_valid(_fx_host) \
			or not _fx_host.is_inside_tree():
		return
	var effect: ExplosionEffect = EXPLOSION_EFFECT_SCENE.instantiate()
	_fx_host.add_child(effect)
	# The Enemies/Effects containers both sit at the scene origin under
	# GameWorld, so this node's local position equals its former global one.
	effect.global_position = global_position


## Brief fire telegraph before this enemy's return-fire bullet launches
## (FR4.11): a quick flash + scale "recoil" tween. Fire-and-forget and
## non-blocking - callers must NOT await it; gameplay (life loss, attempt
## counting, Game Over) never waits on this animation.
func play_fire_feedback() -> void:
	if _sprite == null:
		return
	if _telegraph_tween != null and _telegraph_tween.is_valid():
		_telegraph_tween.kill()
	_sprite.scale = Vector2.ONE
	_sprite.modulate = Color(1, 1, 1, 1)
	_telegraph_tween = create_tween()
	_telegraph_tween.set_parallel(true)
	_telegraph_tween.tween_property(
		_sprite, "scale", Vector2(1.25, 1.25), FIRE_TELEGRAPH_SECONDS)
	_telegraph_tween.tween_property(
		_sprite, "modulate", Color(1.0, 0.3, 0.3, 1.0), FIRE_TELEGRAPH_SECONDS)
	_telegraph_tween.chain().tween_property(
		_sprite, "scale", Vector2.ONE, FIRE_TELEGRAPH_SECONDS)
	_telegraph_tween.parallel().tween_property(
		_sprite, "modulate", Color(1, 1, 1, 1), FIRE_TELEGRAPH_SECONDS)
