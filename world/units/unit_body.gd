class_name UnitBody
extends CharacterBody2D
## Shared body for defenders and enemies. Specification sections 15.3, 25, 29
## and 34.
##
## Everything a moving, damageable unit needs and neither the cargo unit nor a
## projectile has: health with defense, terrain sensing, navigation with local
## avoidance, a separation nudge, and the blocked-unit recovery of section 34.
##
## Movement is requested, not commanded. A state calls [method move_toward] or
## [method hold_still] once per physics step and this script decides what that
## means after terrain, avoidance and separation. A state that asks for nothing
## gets a unit that stands still, so a forgotten branch stops a unit instead of
## letting it drift on last frame's velocity.

signal health_changed(health: int, maximum: int)
signal died(unit: UnitBody)

## Fraction of the intended speed a unit must cover to count as moving. Below
## this for [member blocked_timeout] seconds, section 34 calls it blocked.
const BLOCKED_SPEED_FRACTION := 0.15
## Distance a blocked unit steps aside to find its way around. Section 34.
const FALLBACK_RADIUS := 130.0
## Seconds a fallback position overrides the state's own target.
const FALLBACK_SECONDS := 1.0
## Turn between one fallback attempt and the next. A whole number of degrees
## that does not divide 360 spreads repeated attempts around the unit instead of
## retrying the same two directions.
const FALLBACK_TURN := deg_to_rad(137.0)
## How near a unit has to be to its target before it counts as arrived. A unit
## that has arrived is standing still on purpose and is not blocked.
const ARRIVE_DISTANCE := 10.0

@export var body_radius: float = 13.0
## A small separation force prevents exact visual overlap. Section 15.3.
@export var separation_radius: float = 26.0
@export var separation_strength: float = 0.6
## A unit blocked for longer than this picks a fallback position. Section 34.
@export var blocked_timeout: float = 2.0
## Path recalculation period. Sections 15.3 and 25.1.
@export var path_interval: float = 0.25

var max_health: int = 1
var health: int = 0
## Reduces each received damage value. Final damage is never below 1. Section 29.
var defense: int = 0
## Pixels per second before terrain.
var base_speed: float = 80.0
## Terrain speed factor for this unit kind. Section 12.2.
var terrain_factor: float = 1.0

var machine: StateMachine = null

## Set by the state each physics step through [method move_toward].
var _want_move: bool = false
var _move_point := Vector2.ZERO
var _move_scale: float = 1.0

var _zones: Array[TerrainZone] = []
var _path_timer: float = 0.0
var _blocked_seconds: float = 0.0
var _fallback_left: float = 0.0
var _fallback_point := Vector2.ZERO
var _fallback_angle: float = 0.0
var _last_position := Vector2.ZERO
var _dead: bool = false

@onready var _agent: NavigationAgent2D = $Agent
@onready var _collision: CollisionShape2D = $Collision
@onready var _terrain_sensor: Area2D = $TerrainSensor
@onready var ink: InkSprite = $Ink
@onready var health_bar: UnitHealthBar = $HealthBar


func _ready() -> void:
	var shape := _collision.shape as CircleShape2D
	if shape != null:
		shape.radius = body_radius

	_terrain_sensor.collision_layer = 0
	_terrain_sensor.collision_mask = Layers.TERRAIN
	_terrain_sensor.monitorable = false
	_terrain_sensor.area_entered.connect(_on_zone_entered)
	_terrain_sensor.area_exited.connect(_on_zone_exited)
	var sensor_shape := (_terrain_sensor.get_node("Collision") as CollisionShape2D).shape as CircleShape2D
	if sensor_shape != null:
		sensor_shape.radius = 6.0

	# Defenders and enemies use local avoidance. The cargo unit does not.
	# Section 34.
	_agent.radius = body_radius
	_agent.avoidance_enabled = true
	_agent.path_desired_distance = 14.0
	_agent.target_desired_distance = 8.0
	_agent.velocity_computed.connect(_on_velocity_computed)

	machine = StateMachine.new()
	machine.name = "StateMachine"
	add_child(machine)

	_last_position = global_position
	health_bar.hide_bar()


func _physics_process(delta: float) -> void:
	if machine != null:
		machine.update(delta)

	var speed := 0.0
	var desired := Vector2.ZERO
	if _want_move and not _dead:
		speed = base_speed * terrain_factor * _move_scale
		desired = _steer(delta, speed)

	_track_blocked(delta, speed)

	# The avoidance solver clamps the velocity it returns to this cap, so the cap
	# has to include the speed scale of the current request. Leaving the scale out
	# looks harmless and quietly throws away every request to move faster than the
	# unit's own speed, which is how a defender catching up ends up not catching up.
	# The cap is also set on a frame the unit holds still, or the solver keeps the
	# cap from the last frame that did move.
	_agent.max_speed = maxf(base_speed * terrain_factor * maxf(1.0, _move_scale), 1.0)
	_agent.velocity = desired

	# Asked for again every step. See the note at the top of the file.
	_want_move = false
	_move_scale = 1.0


# --- Movement requests --------------------------------------------------------


## Move toward a world point this physics step. [param speed_scale] slows the
## unit without changing its statistics.
func move_toward(point: Vector2, speed_scale: float = 1.0) -> void:
	if _dead:
		return
	_want_move = true
	_move_point = point
	_move_scale = speed_scale


## Stand still this physics step.
func hold_still() -> void:
	_want_move = false


## True when the unit is close enough to a point to count as standing on it.
func has_arrived(point: Vector2, tolerance: float = ARRIVE_DISTANCE) -> bool:
	return global_position.distance_to(point) <= tolerance


# --- Health -------------------------------------------------------------------


func is_alive() -> bool:
	return health > 0 and not _dead


## Apply damage after defense and return the value that landed. Section 29.
func apply_damage(amount: int) -> int:
	if not is_alive():
		return 0
	var final_damage := maxi(1, amount - defense)
	health = maxi(0, health - final_damage)
	# Health bars appear only after damage. Section 30.6.
	health_bar.show_ratio(float(health) / float(max_health))
	health_changed.emit(health, max_health)
	_on_damaged(final_damage)
	if health == 0:
		_on_zero_health()
	return final_damage


func heal(amount: int) -> int:
	if not is_alive() or amount <= 0:
		return 0
	var before := health
	health = mini(max_health, health + amount)
	if health == before:
		return 0
	health_bar.show_ratio(float(health) / float(max_health))
	health_changed.emit(health, max_health)
	return health - before


## Turn the unit into a paper mark: no collision, no avoidance, grey art.
## Sections 15.11 and 29.
func mark_dead() -> void:
	if _dead:
		return
	_dead = true
	_want_move = false
	velocity = Vector2.ZERO
	# A dead unit has no collision shape. Section 15.11.
	_collision.set_deferred("disabled", true)
	_agent.avoidance_enabled = false
	_terrain_sensor.set_deferred("monitoring", false)
	health_bar.hide_bar()
	died.emit(self)


func is_dead_mark() -> bool:
	return _dead


# --- Overridable --------------------------------------------------------------


## Speed factor this unit kind reads from a terrain zone. Section 12.2.
func _zone_factor(zone: TerrainZone) -> float:
	return zone.defender_factor


## Called after damage lands, before the zero health check.
func _on_damaged(_final_damage: int) -> void:
	pass


## Called once when health reaches zero. An enemy dies, a defender goes down.
func _on_zero_health() -> void:
	mark_dead()


## Units this one keeps its distance from. Section 15.3.
func _neighbours() -> Array:
	return []


# --- Movement -----------------------------------------------------------------


func _steer(delta: float, speed: float) -> Vector2:
	var goal := _move_point
	if _fallback_left > 0.0:
		_fallback_left -= delta
		goal = _fallback_point

	# A defender recalculates its path every 0.25 seconds. Section 15.3.
	_path_timer -= delta
	if _path_timer <= 0.0:
		_path_timer = path_interval
		_agent.target_position = goal

	var direction := _agent.get_next_path_position() - global_position
	if _agent.is_navigation_finished() or direction.length_squared() < 1.0:
		# Off the mesh, or already at the last path point. Head straight at the
		# goal rather than stopping: an open battlefield has almost nothing to
		# path around, and a unit that refuses to move reads as a broken unit.
		direction = goal - global_position
	if direction.length_squared() < 1.0:
		return Vector2.ZERO

	var steer := direction.normalized() + _separation() * separation_strength
	if steer.length_squared() < 0.0001:
		return Vector2.ZERO
	return steer.normalized() * speed


func _separation() -> Vector2:
	var push := Vector2.ZERO
	for other: UnitBody in _neighbours():
		if other == self or other == null or not other.is_alive():
			continue
		var offset := global_position - other.global_position
		var distance := offset.length()
		if distance >= separation_radius:
			continue
		if distance < 0.01:
			# Exactly coincident. Push apart along a fixed axis so the pair does
			# not sit in a stable overlap forever.
			push += Vector2.RIGHT.rotated(float(get_instance_id() % 360))
			continue
		push += offset / distance * (1.0 - distance / separation_radius)
	return push


## A unit must not stay blocked for more than two seconds. Section 34.
func _track_blocked(delta: float, speed: float) -> void:
	var travelled := global_position.distance_to(_last_position)
	_last_position = global_position

	var trying := _want_move and speed > 0.0 and not has_arrived(_move_point)
	if not trying or travelled >= speed * delta * BLOCKED_SPEED_FRACTION:
		_blocked_seconds = 0.0
		return

	_blocked_seconds += delta
	if _blocked_seconds < blocked_timeout:
		return
	_blocked_seconds = 0.0
	_choose_fallback()


## Step aside to a position that is inside the navigation area. Section 34.
func _choose_fallback() -> void:
	_fallback_angle += FALLBACK_TURN
	var probe := global_position + Vector2.RIGHT.rotated(_fallback_angle) * FALLBACK_RADIUS
	var navigation_map := get_world_2d().navigation_map
	_fallback_point = NavigationServer2D.map_get_closest_point(navigation_map, probe)
	_fallback_left = FALLBACK_SECONDS
	# Re-path at once rather than waiting out the interval.
	_path_timer = 0.0


func _on_velocity_computed(safe_velocity: Vector2) -> void:
	# With avoidance enabled the solver returns the velocity to use, so this is
	# the only place the unit may move.
	velocity = safe_velocity
	move_and_slide()


# --- Terrain ------------------------------------------------------------------


func _on_zone_entered(area: Area2D) -> void:
	var zone := area as TerrainZone
	if zone == null or _zones.has(zone):
		return
	_zones.append(zone)
	_refresh_terrain()


func _on_zone_exited(area: Area2D) -> void:
	var zone := area as TerrainZone
	if zone == null:
		return
	_zones.erase(zone)
	_refresh_terrain()


## Overlapping zones resolve to the slowest, so terrain cannot be escaped by
## standing on a seam.
func _refresh_terrain() -> void:
	var factor := 1.0
	for zone in _zones:
		factor = minf(factor, _zone_factor(zone))
	terrain_factor = factor
