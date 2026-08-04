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
## A threat reinforcement group of section 27, separate from the scheduled
## trigger groups so the head-up display and the tools can tell the two apart.
signal reinforcements_spawned(count: int)

## Wired as NodePath rather than as node exports. See [NodeRef] for why.
@export var container_path: NodePath
@export var cargo_path: NodePath
@export var map_path: NodePath
@export var squad_path: NodePath
## Long-range bolts are parented here, alongside the wizard's, so a bolt outlives
## the enemy that fired it. Section 25.2.
@export var projectile_container_path: NodePath

@export var schedule: EnemyScheduleData
@export var short_range_scene: PackedScene
@export var long_range_scene: PackedScene
## The projectile the long-range enemy fires. Section 25.2.
@export var enemy_bolt_scene: PackedScene

@export var short_range_data: EnemyData
@export var long_range_data: EnemyData

var container: Node2D
var cargo: CargoUnit
var map: Map
var squad: Squad
var projectiles: Node2D

var _fired: PackedByteArray = PackedByteArray()
var _living: Array[Enemy] = []
var _deferred_long_range: int = 0
## Reinforcement groups already created this run. Section 27 creates one each
## time the threat value passes another multiple of its interval.
var _reinforcements_sent: int = 0


func _ready() -> void:
	container = NodeRef.get_required(self, container_path, "enemy container")
	cargo = NodeRef.get_required(self, cargo_path, "cargo")
	map = NodeRef.get_required(self, map_path, "map")
	squad = NodeRef.get_required(self, squad_path, "squad")
	projectiles = NodeRef.get_required(self, projectile_container_path, "projectile container")


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
	_reinforcements_sent = 0
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
	return _spawn_at(scene, data, _spawn_position(route_offset))


## Create one enemy at a world point. Both the scheduled groups and the threat
## reinforcements route through here, so a long-range enemy is armed with its
## projectile the same way wherever it comes from. Section 25.2.
func _spawn_at(scene: PackedScene, data: EnemyData, point: Vector2) -> bool:
	if scene == null or data == null:
		return false
	var enemy: Enemy = scene.instantiate()
	container.add_child(enemy)
	enemy.global_position = point
	enemy.setup(data, cargo, squad)
	if data.kind == EnemyData.Kind.LONG_RANGE:
		enemy.set_ranged_fire(projectiles, enemy_bolt_scene)
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
	return _navmesh_point(placement.get_origin() + side * lateral)


# --- Threat reinforcements, section 27 ----------------------------------------


## Create the reinforcement groups the threat value has earned but not yet been
## given. The controller calls this every run tick with the running threat.
## Returns how many groups were created this call. Section 27.
func update_threat(threat: float) -> int:
	if schedule == null or schedule.reinforcement_threat_interval <= 0.0:
		return 0
	var due := int(floor(threat / schedule.reinforcement_threat_interval))
	var made := 0
	while _reinforcements_sent < due:
		_reinforcements_sent += 1
		if spawn_reinforcements():
			made += 1
	return made


## One reinforcement group: two short-range and one long-range enemy, behind and
## beside the cargo unit and off the visible screen. Section 27.
func spawn_reinforcements() -> bool:
	if cargo == null or schedule == null:
		return false
	var origin := _reinforcement_origin()
	var total := schedule.reinforcement_size()
	var spawned := 0
	var slot := 0
	for _i in schedule.reinforcement_short_range:
		if _spawn_at(short_range_scene, short_range_data, _reinforcement_point(origin, slot, total)):
			spawned += 1
		slot += 1
	for _i in schedule.reinforcement_long_range:
		if _spawn_at(long_range_scene, long_range_data, _reinforcement_point(origin, slot, total)):
			spawned += 1
		slot += 1
	print("[Enemies] reinforcement group %d: %d enemies behind the cargo (threat interval %d)" % [
		_reinforcements_sent, spawned, int(schedule.reinforcement_threat_interval),
	])
	reinforcements_spawned.emit(spawned)
	return spawned > 0


func reinforcements_sent() -> int:
	return _reinforcements_sent


## The centre of a reinforcement group: behind and a little to one side of the
## cargo, walked out until it clears the screen. Section 27.
func _reinforcement_origin() -> Vector2:
	var heading := Vector2.RIGHT.rotated(cargo.rotation)
	var side := Vector2(-heading.y, heading.x)
	var direction := (-heading + side * 0.35).normalized()
	var camera := _camera()
	var centre := camera.global_position if camera != null else cargo.global_position
	var radius := _screen_radius(camera)
	# The camera leads ahead of the cargo, so a point behind the cargo is already
	# most of the way off screen; step out until it clears the screen circle.
	var point := cargo.global_position
	var guard := 0
	while point.distance_to(centre) < radius and guard < 48:
		point += direction * 48.0
		guard += 1
	return point


## A group member's point, spaced sideways from the group centre and snapped to
## the navigation mesh so it can walk out. Sections 27 and 34.
func _reinforcement_point(origin: Vector2, slot: int, total: int) -> Vector2:
	var heading := Vector2.RIGHT.rotated(cargo.rotation)
	var side := Vector2(-heading.y, heading.x)
	var lateral := (float(slot) - float(total - 1) * 0.5) * schedule.reinforcement_spacing
	return _navmesh_point(origin + side * lateral)


## Half the visible diagonal in world units plus the off-screen margin, so a
## point farther than this from the camera centre is off screen on every side.
func _screen_radius(camera: Camera2D) -> float:
	var view := container.get_viewport()
	var size := view.get_visible_rect().size if view != null else Vector2(1280.0, 720.0)
	var zoom := camera.zoom if camera != null else Vector2.ONE
	var extent := Vector2(size.x / zoom.x, size.y / zoom.y) * 0.5
	return extent.length() + schedule.reinforcement_screen_margin


func _camera() -> Camera2D:
	var view := container.get_viewport()
	return view.get_camera_2d() if view != null else null


## Nearest point on the navigation mesh, so a spawn is never somewhere a unit
## cannot walk out of. Section 34.
func _navmesh_point(point: Vector2) -> Vector2:
	var navigation_map := container.get_world_2d().navigation_map
	return NavigationServer2D.map_get_closest_point(navigation_map, point)


func _prune() -> void:
	var index := _living.size() - 1
	while index >= 0:
		if not is_instance_valid(_living[index]):
			_living.remove_at(index)
		index -= 1
