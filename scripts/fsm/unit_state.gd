class_name UnitState
extends RefCounted
## One state of a unit state machine. Specification section 33.
##
## Each state has enter, update and exit functions. None of them may wait for an
## animation: section 33 requires the simulation to drive the state logic, so a
## state ends when the simulation says it ends and never when a visual finishes.

## Identifier of this state. It is the key the machine is asked to change to, and
## the name shown on a defender portrait.
var id: StringName = &""

var machine: StateMachine = null


func _init(state_id: StringName) -> void:
	id = state_id


func enter() -> void:
	pass


func update(_delta: float) -> void:
	pass


func exit() -> void:
	pass
