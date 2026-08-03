extends RefCounted
## The seven defender states of specification section 15.4.
##
## They are inner classes of one script because they are one machine: Defend,
## Attack and Repair all share the same interception step, and Return exists only
## to hand control back to whichever of them the player ordered. Splitting them
## across seven files would hide that.
##
## The identifiers below are the whole public surface. [Defender.give_order]
## takes one, a portrait shows one, and the telemetry record counts them.

const FOLLOW := &"follow"
const DEFEND := &"defend"
const ATTACK := &"attack"
const REPAIR := &"repair"
const RETURN := &"return"
const DOWNED := &"downed"
const DEAD := &"dead"

## The four states an order can select. Return, Downed and Dead are reached by
## the simulation only.
const ORDERABLE: Array[StringName] = [FOLLOW, DEFEND, ATTACK, REPAIR]

## How near a work point a defender has to be before it starts work.
const WORK_REACH := 18.0


## Base for every defender state. The state machine is a child of the defender,
## so a state can find its unit without being handed one.
class Base:
	extends UnitState

	func defender() -> Defender:
		return machine.get_parent() as Defender

	## Walk to the assigned cargo slot and stand on it. Sections 15.5 and 15.6.
	func hold_slot(unit: Defender) -> void:
		var slot := unit.slot_position()
		if unit.has_arrived(slot, 12.0):
			unit.hold_still()
		else:
			unit.move_toward(slot)

	## Close on the current target and strike it when it is in reach. Returns
	## false when there is no target worth chasing.
	func engage(unit: Defender) -> bool:
		if not CombatTarget.is_valid(unit.target):
			unit.target = null
			return false
		var reach := unit.tuning.attack_range
		if CombatTarget.surface_distance(unit.target, unit.global_position) <= reach:
			unit.hold_still()
			unit.strike(unit.target)
		else:
			unit.move_toward(CombatTarget.approach_point(unit.target, unit.global_position))
		return true

	## The behaviour of section 15.6: intercept the enemy nearest the cargo unit
	## inside the defense radius, otherwise hold the slot.
	##
	## Repair borrows this, because section 15.8 says a defender with no repair
	## work available uses Defend behaviour.
	func defend_step(unit: Defender) -> void:
		if unit.may_retarget() or not CombatTarget.is_valid(unit.target):
			unit.target = unit.nearest_enemy_to_cargo(unit.tuning.defend_radius)
		if not engage(unit):
			hold_slot(unit)


## Move to the assigned cargo slot. Section 15.5.
##
## Section 15.5 also says a defender uses Follow when no other state applies, and
## section 15.6 gives Defend an automatic interception inside the defense radius.
## Read together, Defend applies once an enemy is that close, so Follow hands over
## rather than escorting the cargo past a fight. Without that a player who has not
## yet pressed X watches four defenders walk beside a wagon being eaten.
class Follow:
	extends Base

	func _init() -> void:
		super(FOLLOW)

	func update(_delta: float) -> void:
		var unit := defender()
		if unit.nearest_enemy_to_cargo(unit.tuning.defend_radius) != null:
			unit.machine.change_to(DEFEND)
			return
		unit.target = null
		hold_slot(unit)


## Keep the defender near the cargo unit and intercept what comes close.
## Section 15.6.
class Defend:
	extends Base

	func _init() -> void:
		super(DEFEND)

	func update(_delta: float) -> void:
		var unit := defender()
		# The defender stops pursuit outside the leash radius. Section 15.6.
		if unit.distance_to_cargo() > unit.tuning.defend_leash:
			unit.machine.change_to(RETURN)
			return
		defend_step(unit)


## Pursue further and pick targets by priority. Section 15.7.
class Attack:
	extends Base

	func _init() -> void:
		super(ATTACK)

	func update(_delta: float) -> void:
		var unit := defender()
		if unit.distance_to_cargo() > unit.tuning.attack_leash:
			unit.machine.change_to(RETURN)
			return

		if not CombatTarget.is_valid(unit.target):
			unit.target = null
		elif unit.target.global_position.distance_to(unit.cargo.global_position) \
				> unit.tuning.attack_leash:
			# The defender returns when the target leaves the leash radius.
			# Section 15.7.
			unit.target = null
			unit.machine.change_to(RETURN)
			return

		if unit.may_retarget():
			var candidate := unit.priority_target()
			# The defender keeps its current target until a higher priority
			# target appears. Section 15.7.
			if candidate != null and (
				unit.target == null
				or unit.target_priority(candidate) < unit.target_priority(unit.target)
			):
				unit.target = candidate

		if not engage(unit):
			hold_slot(unit)


## Barrier work first, then cargo repair, then Defend behaviour. Section 15.8.
class Repair:
	extends Base

	func _init() -> void:
		super(REPAIR)

	func update(delta: float) -> void:
		var unit := defender()
		unit.target = null

		# The Repair state gives priority to barrier work. Section 15.8.
		var barrier := unit.barrier_ahead()
		if barrier != null:
			var point := unit.squad.barrier_work_point(barrier, unit.slot_index)
			if unit.has_arrived(point, WORK_REACH):
				unit.hold_still()
				barrier.apply_work(unit.data.repair_rate * delta)
			else:
				unit.move_toward(point)
			return

		# The defender repairs the cargo unit when no barrier needs work.
		if unit.cargo.health < unit.cargo.data.max_health:
			var work := unit.work_point()
			if not unit.has_arrived(work, WORK_REACH):
				unit.move_toward(work)
				return
			unit.hold_still()
			# Cargo repair works only at Stop or Slow speed. At Normal or Fast
			# the defender waits at the rear slot. Section 15.8.
			if unit.cargo_repair_available():
				unit.cargo.repair(unit.data.repair_rate * delta)
			return

		# The defender uses Defend behaviour when no repair work is available.
		defend_step(unit)


## Walk home without picking a target. Section 15.9.
class Return:
	extends Base

	func _init() -> void:
		super(RETURN)

	func enter() -> void:
		defender().target = null

	func update(_delta: float) -> void:
		var unit := defender()
		# The defender changes to its ordered state inside the defense radius.
		if unit.distance_to_cargo() <= unit.tuning.defend_radius:
			unit.machine.change_to(unit.ordered_state)
			return
		unit.move_toward(unit.slot_position())


## Zero health. Fifteen seconds to be revived with Mend. Section 15.10.
class Downed:
	extends Base

	func _init() -> void:
		super(DOWNED)

	func enter() -> void:
		var unit := defender()
		unit.target = null
		unit.selected = false
		unit.downed_left = unit.tuning.downed_seconds
		unit.set_downed_visual(true)

	func update(delta: float) -> void:
		var unit := defender()
		# The defender cannot move, attack, or repair. Section 15.10.
		unit.hold_still()
		unit.downed_left = maxf(0.0, unit.downed_left - delta)
		if unit.downed_left <= 0.0:
			unit.machine.change_to(DEAD)

	func exit() -> void:
		defender().set_downed_visual(false)


## A light grey paper mark that cannot return during the run. Section 15.11.
class Dead:
	extends Base

	func _init() -> void:
		super(DEAD)

	func enter() -> void:
		var unit := defender()
		Telemetry.count("defender_deaths")
		unit.mark_dead()
		unit.show_dead_mark()

	func update(_delta: float) -> void:
		defender().hold_still()
