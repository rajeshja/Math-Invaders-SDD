## Brief overlay shown between waves using wave_complete_banner.png
## (Phase 3 FR3.9). Main.gd calls show_banner(); this node hides itself
## again after a short timer.
class_name WaveBanner
extends CanvasLayer

signal finished

@export var display_seconds: float = 1.2

@onready var _timer: Timer = $Timer


func _ready() -> void:
	visible = false
	_timer.wait_time = display_seconds
	_timer.one_shot = true
	_timer.timeout.connect(_on_timeout)


func show_banner() -> void:
	visible = true
	_timer.start()


func _on_timeout() -> void:
	visible = false
	finished.emit()
