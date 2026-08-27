## Phase 20 fraction question & answer layout tests (FR20.1/FR20.2):
## the stacked-fraction control added to each answer button fills the
## button (PRESET_FULL_RECT) so its ALIGNMENT_CENTER takes effect, and the
## code-built question stack host spans the panel width (SIZE_EXPAND_FILL)
## so fraction questions read centered.
extends GutTest

const QuestionPanelScene := preload("res://scenes/question_panel.tscn")

var panel: Node


func before_each() -> void:
	panel = QuestionPanelScene.instantiate()
	add_child_autofree(panel)


func test_button_stack_fills_the_button() -> void:
	var layout := {"numerator": 3, "denominator": 4}
	var control: Control = panel._build_button_stack(layout)

	assert_eq(control.anchor_left, 0.0, "fills left edge")
	assert_eq(control.anchor_top, 0.0, "fills top edge")
	assert_eq(control.anchor_right, 1.0, "fills right edge")
	assert_eq(control.anchor_bottom, 1.0, "fills bottom edge")


func test_question_stack_host_spans_and_centers() -> void:
	var host: Control = panel._question_stack_host
	var hbox: Control = panel._question_stack_hbox

	assert_eq(host.anchor_left, 0.0, "host spans the panel width")
	assert_eq(host.anchor_right, 1.0, "host spans the panel width")
	assert_eq(hbox.anchor_left, 0.5, "inner stack is anchored to the center")
	assert_eq(hbox.anchor_right, 0.5, "inner stack is anchored to the center")
