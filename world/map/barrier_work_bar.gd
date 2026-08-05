class_name BarrierWorkBar
extends Node2D
## Work-progress bar above a barrier. Specification section 28.
##
## Barriers are rotated a quarter turn from the travel direction (and further
## still on a bend), so this stays screen-up regardless of that rotation:
## `top_level` makes `position` a world position instead of one relative to
## the barrier, and it is kept synced to the barrier's origin every frame
## rather than once, since [Map] assigns `global_position` after this node's
## `_ready()` already ran.

const WIDTH := 60.0
const HEIGHT := 5.0
## Distance above the barrier centre, in world space.
const RISE := -34.0

var _ratio: float = 1.0

@onready var _anchor: Node2D = get_parent()


func _ready() -> void:
	top_level = true
	visible = false


func _process(_delta: float) -> void:
	if _anchor != null:
		global_position = _anchor.global_position + Vector2(0.0, RISE)


## Show the bar at a fraction of work remaining.
func show_ratio(ratio: float) -> void:
	_ratio = clampf(ratio, 0.0, 1.0)
	visible = true
	queue_redraw()


func hide_bar() -> void:
	visible = false


func _draw() -> void:
	var frame := Rect2(-WIDTH * 0.5, -HEIGHT * 0.5, WIDTH, HEIGHT)
	draw_rect(frame, InkPalette.PAPER, true)
	draw_rect(Rect2(frame.position, Vector2(WIDTH * _ratio, HEIGHT)), InkPalette.INK, true)
	draw_rect(frame, InkPalette.GRAY_MEDIUM, false, 1.0)
