class_name FinalPortal
extends Node2D
## The final portal at the end of the route. Specification sections 8.5 and 10.4.
##
## The portal has no Area2D. Section 8.5 starts the cast when the cargo *centre*
## enters the portal, and an overlap test between two shapes would instead trigger
## as soon as a corner of the cargo touched the edge. A distance test against the
## centre is both simpler and exactly what the specification asks for.

## Trigger radius. The cargo centre must come within this distance.
@export var radius: float = 70.0
## Gap between the portal art and the cast progress ring.
const RING_GAP := 18.0

var _cast_ratio: float = 0.0


## True when a world point is inside the portal.
func contains_point(point: Vector2) -> bool:
	return global_position.distance_to(point) <= radius


## Show cast progress from 0 to 1. Section 8.5.
func set_cast_ratio(ratio: float) -> void:
	var clamped := clampf(ratio, 0.0, 1.0)
	if is_equal_approx(clamped, _cast_ratio):
		return
	_cast_ratio = clamped
	queue_redraw()


func _draw() -> void:
	if _cast_ratio <= 0.0:
		return
	# An ink ring that closes as the four second cast completes.
	var start := -PI * 0.5
	draw_arc(
		Vector2.ZERO,
		radius + RING_GAP,
		start,
		start + TAU * _cast_ratio,
		64,
		InkPalette.INK,
		5.0,
		true
	)
