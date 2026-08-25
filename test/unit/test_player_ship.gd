## Player ship texture application tests (Phase 19): apply_ship_texture
## swaps only the sprite texture; invalid paths leave the prior texture
## intact (FR19.4/NFR19.1).
extends GutTest

const PlayerScene := preload("res://scenes/player.tscn")
const DEFAULT_SHIP := "res://assets/images/ships/player_ship.png"
const VARIANT_SHIP := "res://assets/images/ships/player_ship_alt.png"

var player: Node


func before_each() -> void:
	player = PlayerScene.instantiate()
	add_child_autofree(player)


func _sprite_texture_path() -> String:
	return (player._sprite as Sprite2D).texture.resource_path


func test_valid_texture_swaps_only_the_sprite() -> void:
	assert_eq(_sprite_texture_path(), DEFAULT_SHIP,
			"scene default matches the documented default ship")

	player.apply_ship_texture(VARIANT_SHIP)

	assert_eq(_sprite_texture_path(), VARIANT_SHIP,
			"a valid variant replaces the sprite texture")


func test_bogus_path_leaves_prior_texture_intact() -> void:
	player.apply_ship_texture(VARIANT_SHIP)
	player.apply_ship_texture("res://assets/images/ships/no_such_ship.png")

	assert_eq(_sprite_texture_path(), VARIANT_SHIP,
			"invalid overrides never blank the ship")


func test_empty_path_is_a_no_op() -> void:
	player.apply_ship_texture(VARIANT_SHIP)
	player.apply_ship_texture("")

	assert_eq(_sprite_texture_path(), VARIANT_SHIP,
			"empty overrides change nothing (FR18.5-style contract)")
