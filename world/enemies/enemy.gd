class_name Enemy
extends UnitBody
## An attacker. Specification section 25.
##
## One script serves both enemy types. The behaviour they share is all of it
## except how far away the enemy stops and what it does there, and section 25 is
## explicit that both move toward the cargo unit and change target on a fixed
## period. The long-range variant of section 25.2 arrives with its projectile.

const States := preload("res://world/enemies/enemy_states.gd")

const FRAMES := {
	EnemyData.Kind.SHORT_RANGE: [
		"res://assets/world/enemy_short_a.svg", "res://assets/world/enemy_short_b.svg",
	],
	EnemyData.Kind.LONG_RANGE: [
		"res://assets/world/enemy_long_a.svg", "res://assets/world/enemy_long_b.svg",
	],
}

const DEAD_MARK := preload("res://assets/world/dead_paper_mark.svg")

@export var data: EnemyData

var cargo: CargoUnit = null
var squad: Squad = null

## What this enemy is moving at or hitting. The cargo unit, or a defender that
## blocks its route. Section 25.1.
var target: Node2D = null

var _attack_cooldown: float = 0.0
var _retarget_cooldown: float = 0.0


func _ready() -> void:
	super()
	collision_layer = Layers.ENEMY
	collision_mask = Layers.UNIT_MASK

	machine.add_state(States.Approach.new())
	machine.add_state(States.Strike.new())
	machine.add_state(States.Dead.new())


func setup(enemy_data: EnemyData, world_cargo: CargoUnit, world_squad: Squad) -> void:
	data = enemy_data
	cargo = world_cargo
	squad = world_squad

	max_health = data.max_health
	health = data.max_health
	defense = data.defense
	base_speed = data.speed
	body_radius = data.body_radius
	path_interval = data.retarget_interval

	var shape := _collision.shape as CircleShape2D
	if shape != null:
		shape.radius = body_radius
	_agent.radius = body_radius

	var frames: Array[Texture2D] = []
	for path: String in FRAMES[data.kind]:
		frames.append(load(path))
	ink.set_frames(frames)

	machine.start(States.APPROACH)


func _physics_process(delta: float) -> void:
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_retarget_cooldown = maxf(0.0, _retarget_cooldown - delta)
	super(delta)


# --- Targeting ----------------------------------------------------------------


## True when it is time to look for a different target. The short-range enemy
## changes target every 0.50 seconds. Section 25.1.
func may_retarget() -> bool:
	if _retarget_cooldown > 0.0:
		return false
	_retarget_cooldown = data.retarget_interval
	return true


## Choose what to move at. The enemy attacks a defender that blocks its route,
## and the cargo unit when no defender blocks it. Section 25.1.
func choose_target() -> Node2D:
	var blocker := _blocking_defender()
	return blocker if blocker != null else cargo


## True when this enemy is hitting the cargo unit. Reads as target priority 2 in
## the defender target list of section 15.7.
func is_attacking_cargo() -> bool:
	return target is CargoUnit and machine.current_id() == States.STRIKE


## The defender in the way, if any.
##
## Section 25.1 says a defender can block the enemy's route without saying how
## wide that route is. A defender blocks when it stands within
## [member EnemyData.block_corridor] of the straight line to the cargo unit and
## is nearer than the cargo, or when it is already inside melee reach. That makes
## a defender standing between the enemy and the wagon a target and a defender
## running past it not one.
func _blocking_defender() -> Defender:
	if squad == null or cargo == null:
		return null

	var to_cargo := cargo.global_position - global_position
	var cargo_distance := to_cargo.length()
	if cargo_distance < 0.01:
		return null
	var route := to_cargo / cargo_distance

	var best: Defender = null
	var best_distance := INF
	for defender in squad.get_living():
		var offset := defender.global_position - global_position
		var along := offset.dot(route)
		var distance := offset.length()
		var in_reach := distance - defender.body_radius <= data.attack_range
		var in_corridor := along > 0.0 \
			and along < cargo_distance \
			and absf(offset.cross(route)) <= data.block_corridor
		if not in_reach and not in_corridor:
			continue
		if distance < best_distance:
			best_distance = distance
			best = defender
	return best


# --- Combat -------------------------------------------------------------------


func can_attack() -> bool:
	return _attack_cooldown <= 0.0


## Hit the current target. A unit cannot attack during its attack cooldown.
## Section 29.
func strike(victim: Node2D) -> void:
	if not can_attack() or not CombatTarget.is_valid(victim):
		return
	_attack_cooldown = data.attack_interval
	CombatTarget.damage(victim, data.attack_damage)


func in_attack_range(victim: Node2D) -> bool:
	if not CombatTarget.is_valid(victim):
		return false
	return CombatTarget.surface_distance(victim, global_position) <= data.attack_range


func _on_zero_health() -> void:
	target = null
	machine.change_to(States.DEAD)


func _zone_factor(zone: TerrainZone) -> float:
	return zone.enemy_factor


func _neighbours() -> Array:
	return get_parent().get_children()


## A dead enemy changes to a light grey paper mark. Section 29.
func show_dead_mark() -> void:
	var frames: Array[Texture2D] = [DEAD_MARK]
	ink.extra_scale = 0.20
	ink.set_frames(frames)
