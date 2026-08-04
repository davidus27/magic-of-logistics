extends RefCounted
## The enemy states of specification section 25.
##
## The short-range enemy of section 25.1 closes on whatever is in its way and
## hits it: Approach then Strike. The long-range enemy of section 25.2 keeps its
## distance instead, standing off at its preferred range from the cargo unit and
## firing: Standoff then Fire. Both share Dead, and neither needs the second
## death state a defender has, because an enemy has no downed timer.

const APPROACH := &"approach"
const STRIKE := &"strike"
const STANDOFF := &"standoff"
const FIRE := &"fire"
const DEAD := &"dead"

## A dead enemy stays as a paper mark for two seconds, then the game removes it.
## Section 29.
const DEAD_MARK_SECONDS := 2.0


class Base:
	extends UnitState

	func enemy() -> Enemy:
		return machine.get_parent() as Enemy


## Move toward the target. Section 25.1.
class Approach:
	extends Base

	func _init() -> void:
		super(APPROACH)

	func update(_delta: float) -> void:
		var unit := enemy()
		if unit.may_retarget() or not CombatTarget.is_valid(unit.target):
			unit.target = unit.choose_target()
		if not CombatTarget.is_valid(unit.target):
			unit.hold_still()
			return
		if unit.in_attack_range(unit.target):
			unit.machine.change_to(STRIKE)
			return
		unit.move_toward(CombatTarget.approach_point(unit.target, unit.global_position))


## In reach. Hit the target once each attack interval. Section 25.1.
class Strike:
	extends Base

	func _init() -> void:
		super(STRIKE)

	func update(_delta: float) -> void:
		var unit := enemy()
		unit.hold_still()

		# Retarget on the same period as Approach, so a defender that steps in
		# front of an enemy hitting the wagon takes the blow. Section 25.1.
		if unit.may_retarget():
			var next := unit.choose_target()
			if next != unit.target and unit.in_attack_range(next):
				unit.target = next

		if not unit.in_attack_range(unit.target):
			unit.machine.change_to(APPROACH)
			return
		unit.strike(unit.target)


## Move to the preferred range from the cargo unit. Section 25.2.
##
## The goal is a point on the ring of [member EnemyData.preferred_range] around
## the cargo, on the line from the cargo to this enemy. Steering at it closes the
## gap when the enemy is too far and opens it when the enemy is too near, so one
## goal serves both the approach and the kite away from a cargo that drove up to
## it. When the enemy reaches the ring it starts firing.
class Standoff:
	extends Base

	func _init() -> void:
		super(STANDOFF)

	func update(_delta: float) -> void:
		var unit := enemy()
		if not CombatTarget.is_valid(unit.cargo):
			unit.hold_still()
			return
		var goal := unit.standoff_point()
		if unit.has_arrived(goal, unit.data.body_radius + 8.0):
			unit.machine.change_to(FIRE)
			return
		unit.move_toward(goal)


## In the firing band. Hold position and fire once each attack interval.
## Section 25.2.
class Fire:
	extends Base

	func _init() -> void:
		super(FIRE)

	func update(_delta: float) -> void:
		var unit := enemy()
		unit.hold_still()
		if not CombatTarget.is_valid(unit.cargo):
			return

		# The enemy fires at the cargo unit, or at a defender that has closed to
		# within its aggro radius. Section 25.2.
		if unit.may_retarget() or not CombatTarget.is_valid(unit.target):
			unit.target = unit.choose_ranged_target()

		# Left the band: the cargo drove out of range or right up to the enemy.
		# Reposition before firing again. Section 25.2.
		if not unit.in_firing_band():
			unit.machine.change_to(STANDOFF)
			return

		unit.fire_at(unit.target)


## A paper mark for two seconds, then gone. Section 29.
class Dead:
	extends Base

	var _left: float = DEAD_MARK_SECONDS

	func _init() -> void:
		super(DEAD)

	func enter() -> void:
		var unit := enemy()
		_left = DEAD_MARK_SECONDS
		unit.mark_dead()
		unit.show_dead_mark()

	func update(delta: float) -> void:
		_left -= delta
		if _left <= 0.0:
			enemy().queue_free()
