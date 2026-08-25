## Startup splash (Phase 9 FR9.12): shows the Game Title and Developer
## Logo for a short duration, fades out, then lands on the Main Menu.
## Tapping/clicking/pressing any key skips straight into the fade.
class_name SplashScreen
extends Control

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const SPLASH_HOLD_SECONDS := 1.6
const FADE_OUT_SECONDS := 0.7

var _finished := false

@onready var _content: Control = $Content


func _ready() -> void:
	get_tree().create_timer(SPLASH_HOLD_SECONDS).timeout.connect(_begin_fade_out)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		_begin_fade_out()
	elif event is InputEventScreenTouch and event.pressed:
		_begin_fade_out()
	elif event is InputEventMouseButton and event.pressed:
		_begin_fade_out()


func _begin_fade_out() -> void:
	if _finished:
		return
	_finished = true
	var tween := create_tween()
	tween.tween_property(_content, "modulate:a", 0.0, FADE_OUT_SECONDS)
	tween.tween_callback(_go_to_main_menu)


func _go_to_main_menu() -> void:
	if not is_inside_tree():
		return
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
