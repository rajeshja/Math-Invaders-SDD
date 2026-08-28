## Player ship texture application tests (Phase 19/21): apply_ship_texture
## swaps only the sprite texture; a null texture leaves the prior texture
## intact (FR19.4/NFR19.1/FR21.4).
extends GutTest

const PlayerScene := preload("res://scenes/player.tscn")
const DEFAULT_SHIP_TEX: Texture2D = preload("res://assets/images/ships/player_ship.png")
const VARIANT_SHIP_TEX: Texture2D = preload("res://assets/images/ships/player_ship_alt.png")

var player: Node


func before_each() -> void:
	player = PlayerScene.instantiate()
	add_child_autofree(player)


func _sprite_texture_path() -> String:
	return (player._sprite as Sprite2D).texture.resource_path


func test_valid_texture_swaps_only_the_sprite() -> void:
	assert_eq(_sprite_texture_path(), DEFAULT_SHIP_TEX.resource_path,
			"scene default matches the documented default ship")

	player.apply_ship_texture(VARIANT_SHIP_TEX)

	assert_eq(_sprite_texture_path(), VARIANT_SHIP_TEX.resource_path,
			"a valid variant replaces the sprite texture")


func test_null_texture_leaves_prior_texture_intact() -> void:
	player.apply_ship_texture(VARIANT_SHIP_TEX)
	player.apply_ship_texture(null)

	assert_eq(_sprite_texture_path(), VARIANT_SHIP_TEX.resource_path,
			"null overrides never blank the ship")
