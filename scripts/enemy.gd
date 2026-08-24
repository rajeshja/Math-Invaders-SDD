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
	"addition": "res://assets/images/enemies/enemy_ship_addition.png",
	"subtraction": "res://assets/images/enemies/enemy_ship_subtraction.png",
	"multiplication": "res://assets/images/enemies/enemy_ship_multiplication.png",
	"division": "res://assets/images/enemies/enemy_ship_division.png",
	"prime": "res://assets/images/enemies/enemy_ship_prime.png",
}

## The math category this enemy belongs to (e.g. "addition").
var category: String = ""

## The question Dictionary this enemy is linked to:
## { question_text, correct_answer, choices }. Set by WaveManager at spawn
## (or just-in-time when this enemy becomes active).
var linked_question: Dictionary = {}

@onready var _sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null


## Sets category + linked question and swaps the sprite texture for the
## category (Phase 2 FR2.7 / Phase 3 FR3.6).
func setup(p_category: String, p_question: Dictionary) -> void:
	category = p_category
	linked_question = p_question
	_apply_category_texture()


func _apply_category_texture() -> void:
	if _sprite == null:
		return
	var path: String = CATEGORY_TEXTURES.get(category, "")
	if path == "":
		return
	if ResourceLoader.exists(path):
		_sprite.texture = load(path)


## Destroys this enemy instance. Bullet-travel-then-destroy timing is
## orchestrated by whoever calls this (WaveManager, via bullet.gd's
## arrival), not by the enemy itself.
func destroy() -> void:
	queue_free()
