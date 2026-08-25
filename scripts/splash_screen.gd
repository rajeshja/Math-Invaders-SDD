## Startup splash (Phase 9 FR9.12, polished in Phase 10 FR9.8): the
## logo/title fades in smoothly with a welcoming startup chime, holds
## briefly, then the whole screen fades to black before the Main Menu
## loads. Tapping/clicking/pressing any key skips straight into the
## fade-to-black.
class_name SplashScreen
extends Control

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const FADE_IN_SECONDS := 0.9
const SPLASH_HOLD_SECONDS := 1.1
const FADE_OUT_SECONDS := 0.7
const SKIP_FADE_SECONDS := 0.25

var _finished := false
var _sequence: Tween = null

@onready var _content: Control = $Content
@onready var _fade_rect: ColorRect = $FadeRect
@onready var _chime: AudioStreamPlayer = $Chime


func _ready() -> void:
	_content.modulate.a = 0.0
	_fade_rect.modulate.a = 0.0
	_chime.play()
	_sequence = create_tween()
	_sequence.tween_property(_content, "modulate:a", 1.0, FADE_IN_SECONDS)
	_sequence.tween_interval(SPLASH_HOLD_SECONDS)
	_sequence.tween_property(_fade_rect, "modulate:a", 1.0, FADE_OUT_SECONDS)
	_sequence.tween_callback(_go_to_main_menu)


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
	if _sequence != null and _sequence.is_valid():
		_sequence.kill()
	# Skip: jump the logo to full opacity and fade to black quickly.
	_content.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 1.0, SKIP_FADE_SECONDS)
	tween.tween_callback(_go_to_main_menu)


func _go_to_main_menu() -> void:
	if not is_inside_tree():
		return
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
