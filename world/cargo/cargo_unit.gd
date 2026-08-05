class_name CargoUnit
extends CharacterBody2D
## The wagon, the rider prop and the wizard platform. Specification section 13.
##
## The cargo unit has one collision shape and one health value. Cargo health
## represents cargo and wizard survival together, so the wizard has no health of
## its own in the MVP. Section 14.1.
##
## Movement belongs to the motor, not here. This script owns health, the terrain
## it stands on, and the visuals.

signal health_changed(health: int, maximum: int)
signal destroyed
## Emitted when the cargo enters new terrain. Drives the label of section 12.4.
signal terrain_changed(display_name: String, factor: float)
signal speed_level_changed(level: int)

@export var data: CargoData

var map: Map = null
var motor: CargoMotor = null

var health: int = 100

## Terrain state. Refreshed from the terrain sensor, and from the distance to the
## route centre line when the motor lets the cargo leave the road.
var terrain_name: String = "Road"
var terrain_key: String = "road"
var terrain_factor: float = TerrainZone.ROAD_CARGO_FACTOR
var terrain_turn_factor: float = 1.0

## False outside the active run, so the cargo holds still on the instruction
## screen and after the run ends.
var simulating: bool = false

## Total distance moved this run.
var distance_travelled: float = 0.0

## Last nearest route sample, handed back to [method Map.nearest_sample_index] so
## progress cannot snap to a different bend of the route.
var route_hint: int = -1

var _zones: Array[TerrainZone] = []
var _off_road: bool = false
var _can_leave_road: bool = false
var _flash_left: float = 0.0
var _last_position := Vector2.ZERO
## Fraction of a repair point carried between frames. See [method repair].
var _repair_carry: float = 0.0

@onready var _collision: CollisionShape2D = $Collision
@onready var _body_ink: InkSprite = $Body
@onready var _rider_ink: InkSprite = $Rider
@onready var _wizard_ink: InkSprite = $Wizard
@onready var _crack_1: Sprite2D = $Crack1
@onready var _crack_2: Sprite2D = $Crack2
@onready var _terrain_sensor: Area2D = $TerrainSensor
@onready var _push_area: Area2D = $PushArea


func _ready() -> void:
	collision_layer = Layers.CARGO
	collision_mask = Layers.CARGO_MASK

	# The sensor finds terrain zones. The push area is what enemies are pushed out
	# of in section 13.3; it is empty until enemies exist.
	_terrain_sensor.collision_layer = 0
	_terrain_sensor.collision_mask = Layers.TERRAIN
	_push_area.collision_layer = 0
	_push_area.collision_mask = Layers.ENEMY

	_terrain_sensor.area_entered.connect(_on_zone_entered)
	_terrain_sensor.area_exited.connect(_on_zone_exited)

	if data != null:
		health = data.initial_health
		var shape := _collision.shape as RectangleShape2D
		if shape != null:
			shape.size = data.body_size

	_crack_1.visible = false
	_crack_2.visible = false
	_last_position = global_position


## Attach the motor and place the cargo at the start of the route.
func setup(world_map: Map, cargo_motor: CargoMotor) -> void:
	map = world_map
	_can_leave_road = cargo_motor.can_leave_road()

	if motor != null:
		motor.queue_free()
	motor = cargo_motor
	add_child(motor)
	motor.setup(self, map)
	motor.place_at_start()

	health = data.initial_health
	distance_travelled = 0.0
	route_hint = -1
	_last_position = global_position
	_update_cracks()
	health_changed.emit(health, data.max_health)


func _physics_process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_body_ink.set_ink(InkPalette.INK)

	if not simulating or motor == null or map == null:
		return

	route_hint = map.nearest_sample_index(global_position, route_hint)
	_update_off_road()
	motor.step(delta)
	_push_enemies()

	distance_travelled += global_position.distance_to(_last_position)
	_last_position = global_position


## Reduce cargo health. The cargo has zero defense in the MVP, so the damage
## formula of section 29 leaves the attack value unchanged.
func apply_damage(amount: int) -> void:
	if health <= 0:
		return
	var final_damage := maxi(1, amount)
	health = maxi(0, health - final_damage)
	# Cargo damage uses one paper tear sound. Section 31.
	SoundBank.play(SoundBank.CARGO_DAMAGE)
	_flash()
	_update_cracks()
	health_changed.emit(health, data.max_health)
	if health == 0:
		destroyed.emit()


## Restore cargo health. Health cannot rise above the maximum. Section 13.2.
func heal(amount: int) -> void:
	if health <= 0 or amount <= 0:
		return
	var before := health
	health = mini(data.max_health, health + amount)
	if health == before:
		return
	_update_cracks()
	health_changed.emit(health, data.max_health)


## Apply a defender's repair rate for one step. Section 15.8.
##
## The rate is a value each second and health is a whole number, so the fraction
## carries over rather than rounding away. A repair rate of 2 per second applied
## 60 times a second would otherwise round to nothing every frame and repair
## nothing at all.
func repair(amount: float) -> void:
	if amount <= 0.0 or health <= 0 or health >= data.max_health:
		_repair_carry = 0.0
		return
	_repair_carry += amount
	var whole := floori(_repair_carry)
	if whole <= 0:
		return
	_repair_carry -= float(whole)
	var applied := mini(whole, data.max_health - health)
	heal(applied)


func get_speed_level() -> int:
	return motor.get_speed_level() if motor != null else CargoData.SpeedLevel.STOP


func get_current_speed() -> float:
	return motor.get_current_speed() if motor != null else 0.0


func get_route_offset() -> float:
	return motor.get_route_offset() if motor != null else 0.0


## Hold the cargo still during the portal cast. Section 8.5.
func set_motor_locked(value: bool) -> void:
	if motor != null:
		motor.locked = value


## Push enemies out of the cargo collision shape. Section 13.3.
##
## The cargo unit does not cause collision damage, and it never collides with a
## defender, so this only moves an enemy far enough that the wagon does not drive
## through it. It moves the enemy over the shortest edge, which is what a wagon
## shoving something aside looks like.
func _push_enemies() -> void:
	for body in _push_area.get_overlapping_bodies():
		var enemy := body as Enemy
		if enemy == null or not enemy.is_alive():
			continue
		var local := to_local(enemy.global_position)
		var half := data.body_size * 0.5 + Vector2.ONE * enemy.body_radius
		var out_x := half.x - absf(local.x)
		var out_y := half.y - absf(local.y)
		if out_x <= 0.0 or out_y <= 0.0:
			continue
		if out_x < out_y:
			local.x += out_x * (1.0 if local.x >= 0.0 else -1.0)
		else:
			local.y += out_y * (1.0 if local.y >= 0.0 else -1.0)
		enemy.global_position = to_global(local)


func _update_off_road() -> void:
	if not _can_leave_road:
		return
	var off := map.distance_from_centerline(global_position, route_hint) > map.route.road_width * 0.5
	if off != _off_road:
		_off_road = off
		_refresh_terrain()


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


## Pick the terrain that applies now. Overlapping zones resolve to the slowest,
## so terrain can never be escaped by standing on a seam.
func _refresh_terrain() -> void:
	var slowest: TerrainZone = null
	for zone in _zones:
		if slowest == null or zone.cargo_factor < slowest.cargo_factor:
			slowest = zone

	var next_name := "Road"
	var next_key := "road"
	var next_factor := TerrainZone.ROAD_CARGO_FACTOR
	var next_turn := 1.0

	if slowest != null:
		next_name = slowest.display_name
		next_key = slowest.terrain_key()
		next_factor = slowest.cargo_factor
		next_turn = slowest.turn_factor
	elif _off_road:
		next_name = "Off road"
		next_key = "off_road"
		next_factor = TerrainZone.OFF_ROAD_CARGO_FACTOR
		next_turn = TerrainZone.OFF_ROAD_TURN_FACTOR

	if next_key == terrain_key:
		return

	terrain_name = next_name
	terrain_key = next_key
	terrain_factor = next_factor
	terrain_turn_factor = next_turn
	terrain_changed.emit(terrain_name, terrain_factor)


func _flash() -> void:
	# The cargo flashes for 0.10 seconds after damage. Section 13.2.
	_flash_left = data.damage_flash_seconds
	_body_ink.set_ink(InkPalette.LINE_LIGHT)


func _update_cracks() -> void:
	# A crack mark appears below 60 health, a second below 30. Section 13.2.
	_crack_1.visible = health < data.first_crack_health
	_crack_2.visible = health < data.second_crack_health
