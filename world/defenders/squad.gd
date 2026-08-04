class_name Squad
extends Node
## The four defenders, their formation, and the player's control of them.
## Specification sections 15.1, 16, 17 and 18.
##
## Selection and orders live here rather than on a defender, because both are
## about the group: `Q` selects everything alive, `X` orders everything selected.
##
## Section 16 forbids selecting a defender with a world click, so that the left
## mouse button can always cast a spell. Nothing here reads a mouse position.

const States := preload("res://world/defenders/defender_states.gd")

signal roster_changed
signal selection_changed

## Distance of a formation slot from the cargo centre. Section 15.6 permits 90
## to 130 pixels; the middle of that band keeps a defender clear of the 120 by 64
## pixel wagon on every heading.
const SLOT_RADIUS := 110.0
## Slot angles from the cargo forward direction. Two ahead and two behind, so the
## formation reads as an escort and covers the wagon from both ends.
const SLOT_ANGLES: PackedFloat32Array = [-45.0, 45.0, -135.0, 135.0]

## Function key actions, in slot order. Section 16.
const SELECT_ACTIONS: PackedStringArray = [
	"select_defender_1", "select_defender_2", "select_defender_3", "select_defender_4",
]

## The four defenders of section 15.2, in portrait and function key order.
const ROSTER: PackedStringArray = [
	"res://data/defenders/guard.tres",
	"res://data/defenders/striker.tres",
	"res://data/defenders/engineer.tres",
	"res://data/defenders/warden.tres",
]

## Wired as NodePath rather than as node exports. See [NodeRef] for why.
@export var container_path: NodePath
@export var cargo_path: NodePath
@export var map_path: NodePath
@export var spawner_path: NodePath

@export var defender_scene: PackedScene
@export var tuning: DefenderTuning

var container: Node2D
var cargo: CargoUnit
var map: Map
var spawner: EnemySpawner

var _defenders: Array[Defender] = []


func _ready() -> void:
	container = NodeRef.get_required(self, container_path, "defender container")
	cargo = NodeRef.get_required(self, cargo_path, "cargo")
	map = NodeRef.get_required(self, map_path, "map")
	spawner = NodeRef.get_required(self, spawner_path, "enemy spawner")


## Create the four defenders for a run. Safe to call again for a second run.
func build() -> void:
	for defender in _defenders:
		defender.queue_free()
		container.remove_child(defender)
	_defenders.clear()

	if defender_scene == null:
		push_error("Squad has no defender scene assigned.")
		return

	for index in ROSTER.size():
		var data: DefenderData = load(ROSTER[index])
		if data == null:
			push_error("Squad could not load %s." % ROSTER[index])
			continue
		var defender: Defender = defender_scene.instantiate()
		container.add_child(defender)
		defender.setup(data, tuning, index, self, cargo, spawner, map)
		_defenders.append(defender)

	print("[Squad] %d defenders on the field" % _defenders.size())
	roster_changed.emit()
	selection_changed.emit()


# --- Queries ------------------------------------------------------------------


func get_defenders() -> Array[Defender]:
	return _defenders


func get_living() -> Array[Defender]:
	var out: Array[Defender] = []
	for defender in _defenders:
		if defender.is_alive():
			out.append(defender)
	return out


## Defenders that are neither downed nor dead. Section 37 shows this as the
## survivor count.
func survivor_count() -> int:
	return get_living().size()


## True when another living defender is already attacking this enemy.
## See [method Defender.nearest_enemy_to_cargo] for why that matters.
func is_claimed(enemy: Node2D, except_defender: Defender) -> bool:
	for defender in _defenders:
		if defender == except_defender or not defender.is_alive():
			continue
		if defender.target == enemy:
			return true
	return false


func get_selected() -> Array[Defender]:
	var out: Array[Defender] = []
	for defender in _defenders:
		if defender.selected:
			out.append(defender)
	return out


# --- Formation ----------------------------------------------------------------


## Formation slot for a defender, in cargo-local coordinates. Section 15.6.
func slot_offset(index: int) -> Vector2:
	var angle := deg_to_rad(SLOT_ANGLES[index % SLOT_ANGLES.size()])
	return Vector2.RIGHT.rotated(angle) * SLOT_RADIUS


## Rear cargo work point for a defender, in cargo-local coordinates.
## Section 15.8.
func work_point_offset(index: int) -> Vector2:
	var count := ROSTER.size()
	var lateral := (float(index) - (count - 1) * 0.5) * tuning.repair_work_spacing
	return Vector2(-tuning.repair_work_distance, lateral)


## Work point on a barrier for a defender. Section 15.8 asks for the nearest free
## work point; giving each slot its own place along the barrier makes every point
## free by construction, which no arbitration can improve on for four defenders.
func barrier_work_point(barrier: Barrier, index: int) -> Vector2:
	var count := ROSTER.size()
	var spacing := barrier.road_width * 0.2
	var lateral := (float(index) - (count - 1) * 0.5) * spacing
	# The barrier art lies across the road along its own x axis, so its local y
	# points along the route. Negative y is the side the cargo comes from.
	return barrier.to_global(Vector2(lateral, -(Barrier.THICKNESS * 0.5 + 20.0)))


# --- Player control -----------------------------------------------------------


func _unhandled_input(event: InputEvent) -> void:
	if _defenders.is_empty():
		return

	for index in SELECT_ACTIONS.size():
		if event.is_action_pressed(SELECT_ACTIONS[index]):
			# Shift and a function key change a group selection. Section 16.
			if event.is_pressed() and Input.is_key_pressed(KEY_SHIFT):
				toggle_selection(index)
			else:
				select_only(index)
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("select_all"):
		select_all_living()
	elif event.is_action_pressed("order_attack"):
		order(States.ATTACK)
	elif event.is_action_pressed("order_defend"):
		order(States.DEFEND)
	elif event.is_action_pressed("order_repair"):
		order(States.REPAIR)
	else:
		return
	get_viewport().set_input_as_handled()


## Select one defender and nothing else. Section 16.
func select_only(index: int) -> void:
	if index < 0 or index >= _defenders.size():
		return
	if not _defenders[index].is_alive():
		return
	for defender in _defenders:
		defender.selected = defender == _defenders[index]
	_after_selection()


## Add a defender to the selection or take it out again. Section 16.
func toggle_selection(index: int) -> void:
	if index < 0 or index >= _defenders.size():
		return
	var defender := _defenders[index]
	if not defender.is_alive():
		return
	defender.selected = not defender.selected
	_after_selection()


## Select all living defenders. Section 16.
func select_all_living() -> void:
	for defender in _defenders:
		defender.selected = defender.is_alive()
	_after_selection()


## Give every selected defender a role order. Section 17.
func order(state_id: StringName) -> void:
	var selected := get_selected()
	if selected.is_empty():
		return
	for defender in selected:
		defender.give_order(state_id)
	# A defender order uses one paper tap. Section 31.
	SoundBank.play(SoundBank.DEFENDER_ORDER)


func _after_selection() -> void:
	SoundBank.play(SoundBank.UI_CONFIRM)
	selection_changed.emit()
