## Safe-area helpers (Phase 11 FR10.4).
##
## Converts the platform display safe area (notches, rounded corners,
## home indicator) into canvas coordinates so the HUD (top) and question
## panel (bottom) can pull themselves out of obscured regions on notched
## portrait phones (Spec section 3 layout).
##
## Deliberately a no-op on desktop platforms: `DisplayServer
## .get_display_safe_area()` is only meaningful on handheld devices, and
## gameplay/presentation behavior must stay identical in the editor and
## in GUT runs (NFR10.2). Packaging/device concerns only.
class_name SafeArea
extends RefCounted


## Returns this node's canvas-space safe rectangle, or an empty Rect2
## when the platform has no applicable safe area.
static func get_canvas_safe_rect(node: Node) -> Rect2:
	if node == null or not OS.has_feature("mobile"):
		return Rect2()
	var viewport := node.get_viewport()
	if viewport == null:
		return Rect2()
	var raw := Rect2(DisplayServer.get_display_safe_area())
	if raw.size.x <= 0.0 or raw.size.y <= 0.0:
		return Rect2()
	return viewport.get_final_transform().affine_inverse() * raw


## Returns {"left", "top", "right", "bottom"} margins, in canvas units,
## that content must keep clear of. All zeros when there is no safe-area
## restriction (e.g., desktop editor/testing).
static func get_canvas_insets(node: Node) -> Dictionary:
	var insets := {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
	var viewport := node.get_viewport() if node != null else null
	if viewport == null:
		return insets
	var safe := get_canvas_safe_rect(node)
	if safe.size == Vector2.ZERO:
		return insets
	var canvas := Rect2(Vector2.ZERO, viewport.get_visible_rect().size)
	insets.left = maxf(0.0, safe.position.x - canvas.position.x)
	insets.top = maxf(0.0, safe.position.y - canvas.position.y)
	insets.right = maxf(0.0, canvas.end.x - safe.end.x)
	insets.bottom = maxf(0.0, canvas.end.y - safe.end.y)
	return insets
