class_name StateMachine
extends Node
## Explicit finite state machine for one unit. Specification section 33.
##
## The machine emits [signal state_changed] after each change, which is how the
## telemetry recorder counts defender state changes without any unit knowing that
## telemetry exists.
##
## A state may ask for another change from inside its own enter or update. That
## is queued rather than recursed, so exit and enter always run in pairs and the
## signal order matches the order the states really ran in.

signal state_changed(from: StringName, to: StringName)

var _states: Dictionary = {}
var _current: UnitState = null
var _changing: bool = false
var _pending: StringName = &""


func add_state(state: UnitState) -> void:
	state.machine = self
	_states[state.id] = state


## Enter the first state. Use this instead of [method change_to] at setup, so the
## initial enter runs even when the machine is already in that state after a
## previous run.
func start(state_id: StringName) -> void:
	_current = null
	change_to(state_id)


func change_to(next_id: StringName) -> void:
	if not _states.has(next_id):
		push_error("%s has no state named '%s'." % [get_path(), next_id])
		return
	if _current != null and _current.id == next_id:
		return
	if _changing:
		_pending = next_id
		return

	_changing = true
	var from := current_id()
	if _current != null:
		_current.exit()
	_current = _states[next_id]
	_current.enter()
	_changing = false
	state_changed.emit(from, _current.id)

	if _pending != &"":
		var queued := _pending
		_pending = &""
		change_to(queued)


## Advance the current state. The unit calls this from its physics step, so the
## simulation rate and the state rate are the same thing.
func update(delta: float) -> void:
	if _current != null:
		_current.update(delta)


func current_id() -> StringName:
	return _current.id if _current != null else &""


func has_state(state_id: StringName) -> bool:
	return _states.has(state_id)
