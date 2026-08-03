class_name CameraRig
extends Camera2D
## Top-down camera that follows the cargo unit. Specification section 9.
##
## The camera looks ahead: the cargo sits 15 percent behind the screen centre, so
## the space in front of it is larger. That is done by following a point ahead of
## the cargo rather than the cargo itself.

## Section 9 fixes the response time at 0.20 seconds.
const RESPONSE_SECONDS := 0.20
## The cargo stays this fraction of the screen behind the centre. Section 9.
const LEAD_FRACTION := 0.15
const ZOOM_MIN := 0.85
const ZOOM_MAX := 1.20
const ZOOM_DEFAULT := 1.00
const ZOOM_STEP := 0.05

@export var target: Node2D

var _lead_direction := Vector2.RIGHT


func _ready() -> void:
	# Godot smooths toward the position each frame at this rate. A rate of one
	# over the response time reaches about 63 percent of the gap in that time,
	# which is what a 0.20 second response means.
	position_smoothing_enabled = true
	position_smoothing_speed = 1.0 / RESPONSE_SECONDS
	rotation_smoothing_enabled = false
	# The player cannot rotate the camera. Section 9.
	ignore_rotation = true
	zoom = Vector2.ONE * ZOOM_DEFAULT
	make_current()


func snap_to_target() -> void:
	if target == null:
		return
	_lead_direction = Vector2.RIGHT.rotated(target.rotation)
	global_position = _lead_target()
	reset_smoothing()


func _process(delta: float) -> void:
	if target == null:
		return
	# Ease the lead direction rather than taking the cargo heading raw, so a sharp
	# steering correction in profiles P3 and P4 does not throw the view sideways.
	var heading := Vector2.RIGHT.rotated(target.rotation)
	var weight := 1.0 - exp(-delta / RESPONSE_SECONDS)
	_lead_direction = _lead_direction.slerp(heading, weight)
	global_position = _lead_target()


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	if button.button_index == MOUSE_BUTTON_WHEEL_UP:
		_apply_zoom(ZOOM_STEP)
	elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_apply_zoom(-ZOOM_STEP)
	else:
		return
	get_viewport().set_input_as_handled()


func _lead_target() -> Vector2:
	# Visible world height shrinks as zoom rises, so the lead distance has to be
	# measured in world units at the current zoom, not in screen pixels.
	var view_height := get_viewport_rect().size.y / zoom.y
	return target.global_position + _lead_direction * (LEAD_FRACTION * view_height)


func _apply_zoom(step: float) -> void:
	var next := clampf(zoom.x + step, ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(next, next)
