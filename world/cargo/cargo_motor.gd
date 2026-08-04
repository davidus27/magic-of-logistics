class_name CargoMotor
extends Node
## Base for the cargo control method of specification section 19.
##
## The motor owns how the cargo moves, including whether it can leave the road.
## Keeping that decision inside the motor is why [CargoUnit] itself never has to
## branch on the active motor.

var cargo: CargoUnit = null
var map: Map = null

## True while the portal cast holds the cargo still. Section 8.5.
var locked: bool = false


func setup(cargo_unit: CargoUnit, world_map: Map) -> void:
	cargo = cargo_unit
	map = world_map


## Put the cargo at the start of the route.
func place_at_start() -> void:
	pass


## Move the cargo to an arc offset along the route at once, without driving there.
func jump_to(_route_offset: float) -> void:
	pass


## Advance the cargo by one physics step.
func step(_delta: float) -> void:
	pass


## Whether the cargo can leave the road under this motor. The base motor rides
## the route centre line and never does.
func can_leave_road() -> bool:
	return false


## Current speed level, or Stop for the motors that have no levels.
func get_speed_level() -> int:
	return CargoData.SpeedLevel.STOP


## Current speed in pixels per second.
func get_current_speed() -> float:
	return 0.0


## How far along the route the cargo is, in pixels.
func get_route_offset() -> float:
	if map == null:
		return 0.0
	return map.offset_at(cargo.global_position, cargo.route_hint)
