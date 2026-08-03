class_name CombatTarget
extends RefCounted
## One way to ask a question of anything that can be attacked or healed.
##
## A defender attacks enemies, an enemy attacks defenders and the cargo unit, and
## the wizard heals the cargo unit and defenders. Those are two unrelated types:
## [UnitBody] and [CargoUnit]. Rather than give them a shared base class, which
## would put navigation and a state machine on the cargo unit for no reason, the
## few questions combat needs to ask are collected here.
##
## Distance is measured to the surface of a target, not to its centre. An attack
## range of 28 pixels in section 25.1 is a reach, and a 120 by 64 pixel wagon
## would otherwise have to be entered before it could be hit.


## True when the target exists and can still be attacked or healed.
static func is_valid(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var unit := target as UnitBody
	if unit != null:
		return unit.is_alive()
	var cargo := target as CargoUnit
	if cargo != null:
		return cargo.health > 0
	return false


## Distance from a world point to the surface of a target. Zero inside it.
static func surface_distance(target: Node2D, from: Vector2) -> float:
	var unit := target as UnitBody
	if unit != null:
		return maxf(0.0, from.distance_to(unit.global_position) - unit.body_radius)
	var cargo := target as CargoUnit
	if cargo != null:
		return _rectangle_distance(cargo, from)
	return from.distance_to(target.global_position)


## The point an attacker should stand next to: the point on the target surface
## nearest the attacker, so a unit approaches the near side of the wagon rather
## than trying to reach its centre.
static func approach_point(target: Node2D, from: Vector2) -> Vector2:
	var unit := target as UnitBody
	if unit != null:
		var offset := from - unit.global_position
		if offset.length_squared() < 0.01:
			return unit.global_position
		return unit.global_position + offset.normalized() * unit.body_radius
	var cargo := target as CargoUnit
	if cargo != null:
		var local := cargo.to_local(from)
		var half := cargo.data.body_size * 0.5
		local.x = clampf(local.x, -half.x, half.x)
		local.y = clampf(local.y, -half.y, half.y)
		return cargo.to_global(local)
	return target.global_position


## Apply damage and return the value that landed after defense. Section 29.
static func damage(target: Node2D, amount: int) -> int:
	var unit := target as UnitBody
	if unit != null:
		return unit.apply_damage(amount)
	var cargo := target as CargoUnit
	if cargo != null:
		# The cargo unit has zero defense in the MVP. Section 29.
		var final_damage := maxi(1, amount)
		cargo.apply_damage(final_damage)
		return final_damage
	return 0


## Shortest distance from a point to the rotated cargo rectangle.
static func _rectangle_distance(cargo: CargoUnit, from: Vector2) -> float:
	var local := cargo.to_local(from)
	var half := cargo.data.body_size * 0.5
	var outside := Vector2(
		maxf(absf(local.x) - half.x, 0.0),
		maxf(absf(local.y) - half.y, 0.0)
	)
	return outside.length()
