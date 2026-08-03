extends RefCounted
## The enemy states of specification section 25.
##
## An enemy has far less to decide than a defender: it closes on whatever is in
## its way and hits it. Three states cover that, and the second death state a
## defender needs does not exist here, because an enemy has no downed timer.

const APPROACH := &"approach"
const STRIKE := &"strike"
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
