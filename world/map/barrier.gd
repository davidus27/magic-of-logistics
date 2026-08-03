class_name Barrier
extends StaticBody2D
## A barrier across the road. Specification section 28.
##
## Each barrier blocks the full road width and has 100 work points. Repair
## defenders reduce the work points, and the barrier opens at zero. Attack
## defenders cannot reduce them.

signal opened
signal work_changed(remaining: float, maximum: float)

## Thickness of the barrier across the travel direction, matching the art.
const THICKNESS := 24.0

@export var work_points_max: float = 100.0

## Set by [Map] when the barrier is placed, so the cargo motor can stop short of
## it without a physics query.
var route_offset: float = 0.0
var road_width: float = 420.0:
	set(value):
		road_width = value
		_resize()

var _work_points: float = 100.0

@onready var _collision: CollisionShape2D = $Collision
@onready var _ink: InkSprite = $Ink


func _ready() -> void:
	collision_layer = Layers.BARRIER
	collision_mask = 0
	_work_points = work_points_max
	_resize()


func is_open() -> bool:
	return _work_points <= 0.0


func get_remaining_work() -> float:
	return _work_points


## Apply one defender's repair rate. Only the Repair state may call this: attack
## defenders cannot reduce barrier work points. Section 28.
func apply_work(amount: float) -> void:
	if is_open() or amount <= 0.0:
		return
	_work_points = maxf(0.0, _work_points - amount)
	Telemetry.accumulate("barrier_work_amount", amount)
	work_changed.emit(_work_points, work_points_max)
	if is_open():
		_open()


## Corners of the barrier in world space, for carving the navigation mesh.
func get_obstruction_outline() -> PackedVector2Array:
	var half_length := road_width * 0.5
	var half_thickness := THICKNESS * 0.5
	var corners := PackedVector2Array([
		Vector2(-half_length, -half_thickness),
		Vector2(half_length, -half_thickness),
		Vector2(half_length, half_thickness),
		Vector2(-half_length, half_thickness),
	])
	var out := PackedVector2Array()
	for corner in corners:
		out.append(global_transform * corner)
	return out


func _open() -> void:
	# The barrier removes its collision shape. Section 28.
	_collision.disabled = true
	_ink.set_ink(InkPalette.LINE_LIGHT)
	opened.emit()


func _resize() -> void:
	if _collision == null:
		return
	var shape := _collision.shape as RectangleShape2D
	if shape != null:
		shape.size = Vector2(road_width, THICKNESS)
