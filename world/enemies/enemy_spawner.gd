class_name EnemySpawner
extends Node
## The enemy trigger areas and the enemies they create.
## Specification sections 26 and 35.
##
## A trigger fires on route offset rather than on an Area2D overlap. The cargo
## unit already knows how far along the route it is, and section 26 places the
## triggers at fixed points on that route, so a comparison is both exact and
## immune to a cargo unit that leaves the road in profile P4.
##
## Every spawn position comes from [member RunContext.rng], which is seeded from
## the selected test seed. Section 35 requires the same seed to give the same
## positions for every control profile, so nothing here may call a global random
## function.

signal group_spawned(index: int, count: int)

## Wired as NodePath rather than as node exports. See [NodeRef] for why.
@export var container_path: NodePath
@export var cargo_path: NodePath
@export var map_path: NodePath
@export var squad_path: NodePath

@export var schedule: EnemyScheduleData
@export var short_range_scene: PackedScene
## Assigned when the long-range enemy of section 25.2 lands. Until then the
## long-range half of each group is reported as deferred rather than dropped in
## silence.
@export var long_range_scene: PackedScene

@export var short_range_data: EnemyData
@export var long_range_data: EnemyData

var container: Node2D
var cargo: CargoUnit
var map: Map
var squad: Squad

var _fired: PackedByteArray = PackedByteArray()
var _living: Array[Enemy] = []
var _deferred_long_range: int = 0


func _ready() -> void:
	container = NodeRef.get_required(self, container_path, "enemy container")
	cargo = NodeRef.get_required(self, cargo_path, "cargo")
	map = NodeRef.get_required(self, map_path, "map")
	squad = NodeRef.get_required(self, squad_path, "squad")


## Clear the field and arm every trigger. Safe to call again for a second run.
func build() -> void:
	for enemy in _living:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_living.clear()
	for child in container.get_children():
		child.queue_free()
		container.remove_child(child)

	_deferred_long_range = 0
	_fired.resize(map.route.trigger_offsets.size())
	_fired.fill(0)

	if schedule == null:
		push_error("EnemySpawner has no schedule assigned.")
		return
	if schedule.groups.size() < map.route.trigger_offsets.size():
		push_warning("The enemy schedule has %d groups for %d trigger areas." % [
			schedule.groups.size(), map.route.trigger_offsets.size(),
		])


func _physics_process(_delta: float) -> void:
	_prune()
	_check_triggers()


## Enemies that can still be targeted, for the defenders and the wizard.
##
## A dead enemy stays in the scene as a paper mark for two seconds (section 29),
## so the tracked list is not the same as the list worth attacking.
func get_living() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for enemy in _living:
		if is_instance_valid(enemy) and enemy.is_alive():
			out.append(enemy)
	return out


func living_count() -> int:
	return get_living().size()


## Long-range enemies the schedule asked for that this build cannot create.
func deferred_long_range() -> int:
	return _deferred_long_range


# --- Triggers -----------------------------------------------------------------


## The cargo unit activates a trigger area when it enters that area. Section 26.
func _check_triggers() -> void:
	var offsets := map.route.trigger_offsets
	# Nothing is armed until a profile is chosen and the map is built, and the
	# route data can be edited between two runs, so the arming record is the
	# authority on how many triggers exist rather than the route.
	if _fired.size() != offsets.size():
		return
	var reached := cargo.get_route_offset()
	for index in offsets.size():
		if _fired[index] == 1 or reached < offsets[index]:
			continue
		_fired[index] = 1
		_spawn_group(index, offsets[index])


func _spawn_group(index: int, route_offset: float) -> void:
	if index >= schedule.groups.size():
		return
	var group := schedule.groups[index]
	var spawned := 0

	for _i in group.x:
		if _spawn_one(short_range_scene, short_range_data, route_offset):
			spawned += 1
	for _i in group.y:
		if _spawn_one(long_range_scene, long_range_data, route_offset):
			spawned += 1
		else:
			_deferred_long_range += 1

	var note := ""
	if group.y > 0 and long_range_scene == null:
		note = ", %d long-range deferred to the milestone that adds them" % group.y
	print("[Enemies] group %d at offset %.0f: %d spawned%s" % [
		index + 1, route_offset, spawned, note,
	])
	group_spawned.emit(index, spawned)


func _spawn_one(scene: PackedScene, data: EnemyData, route_offset: float) -> bool:
	if scene == null or data == null:
		return false
	var enemy: Enemy = scene.instantiate()
	container.add_child(enemy)
	enemy.global_position = _spawn_position(route_offset)
	enemy.setup(data, cargo, squad)
	_living.append(enemy)
	return true


## A position ahead of the trigger point and off to one side, from the seeded
## generator. Section 35.
func _spawn_position(route_offset: float) -> Vector2:
	var rng := RunContext.rng
	var ahead := rng.randf_range(schedule.spawn_ahead_min, schedule.spawn_ahead_max)
	var lateral := rng.randf_range(-schedule.spawn_lateral_max, schedule.spawn_lateral_max)
	var placement := map.sample_route(minf(route_offset + ahead, map.route_length))
	var forward := Vector2.RIGHT.rotated(placement.get_rotation())
	var side := Vector2(-forward.y, forward.x)
	var point := placement.get_origin() + side * lateral
	# Keep the spawn on the navigation mesh whatever the route data says, so an
	# enemy never appears somewhere it cannot walk out of. Section 34.
	var navigation_map := container.get_world_2d().navigation_map
	return NavigationServer2D.map_get_closest_point(navigation_map, point)


func _prune() -> void:
	var index := _living.size() - 1
	while index >= 0:
		if not is_instance_valid(_living[index]):
			_living.remove_at(index)
		index -= 1
