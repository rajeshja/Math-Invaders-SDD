## One-shot enemy destruction effect (Phase 10 FR9.1).
##
## Spawned by enemy.gd's destroy() at the enemy's position; plays the
## 4-frame enemy_explosion_spritesheet animation once and frees itself.
## Fully decoupled from gameplay (NFR9.2): whoever spawned it returns
## immediately - this node's lifetime affects nothing but pixels.
class_name ExplosionEffect
extends Node2D

const EXPLOSION_ANIMATION := "explode"

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	_sprite.visible = false
	_sprite.animation_finished.connect(queue_free)
	_sprite.visible = true
	_sprite.play(EXPLOSION_ANIMATION)
