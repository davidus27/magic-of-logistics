class_name Enemy
extends UnitBody
## An attacker. Specification section 25.
##
## One script serves both enemy types. The behaviour they share is all of it
## except how far away the enemy stops and what it does there. The short-range
## enemy of section 25.1 closes to melee and strikes; the long-range enemy of
## section 25.2 stands off at its preferred range from the cargo and fires a
## projectile. Which pair of states a body carries is chosen from its kind, so a
## short-range enemy never carries the firing states and the reverse.

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

## Where a long-range enemy sends its projectiles, and the scene it makes them
## from. Both stay null on a short-range enemy, which never fires. Section 25.2.
var projectiles: Node2D = null
var bolt_scene: PackedScene = null

## What this enemy is moving at or hitting. The cargo unit, or a defender that
## blocks its route or has closed on a long-range enemy. Sections 25.1 and 25.2.
var target: Node2D = null

var _attack_cooldown: float = 0.0
var _retarget_cooldown: float = 0.0


func _ready() -> void:
	super()
	collision_layer = Layers.ENEMY
	collision_mask = Layers.UNIT_MASK

	machine.add_state(States.Dead.new())
	# Each kind carries only its own states, so a forgotten branch cannot leave a
	# short-range enemy standing off or a long-range enemy walking into melee.
	if _is_long_range():
		machine.add_state(States.Standoff.new())
		machine.add_state(States.Fire.new())
	else:
		machine.add_state(States.Approach.new())
		machine.add_state(States.Strike.new())


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

	machine.start(States.STANDOFF if _is_long_range() else States.APPROACH)


## Where a long-range enemy puts its projectiles. The spawner sets this after
## the body is in the tree, so a bolt is parented alongside the wizard's rather
## than to the enemy that fired it and dying with it. Section 25.2.
func set_ranged_fire(projectile_container: Node2D, enemy_bolt_scene: PackedScene) -> void:
	projectiles = projectile_container
	bolt_scene = enemy_bolt_scene


func _is_long_range() -> bool:
	return data != null and data.kind == EnemyData.Kind.LONG_RANGE


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


## True when this enemy is hitting the cargo unit, in melee or with a bolt. Reads
## as target priority 2 in the defender target list of section 15.7.
func is_attacking_cargo() -> bool:
	if not target is CargoUnit:
		return false
	var id := machine.current_id()
	return id == States.STRIKE or id == States.FIRE


# --- Long range, section 25.2 -------------------------------------------------


## The point on the ring of [member EnemyData.preferred_range] around the cargo,
## on the line from the cargo to this enemy. The Standoff state steers at it.
func standoff_point() -> Vector2:
	var to_self := global_position - cargo.global_position
	var direction := to_self.normalized() if to_self.length_squared() > 0.01 else Vector2.RIGHT
	return cargo.global_position + direction * data.preferred_range


## True while the enemy is close enough to fire and not so close it should kite
## back out. The lower bound stops a bolt-thrower firing point blank; the upper
## bound is the maximum range of section 25.2.
func in_firing_band() -> bool:
	var distance := global_position.distance_to(cargo.global_position)
	return distance <= data.maximum_range and distance >= data.preferred_range * 0.6


## What a long-range enemy fires at: the nearest defender within its aggro
## radius, or the cargo unit when none is that close. Section 25.2.
func choose_ranged_target() -> Node2D:
	var best: Defender = null
	var best_distance := data.defender_aggro_radius
	if squad != null:
		for defender in squad.get_living():
			var distance := global_position.distance_to(defender.global_position)
			if distance <= best_distance:
				best_distance = distance
				best = defender
	return best if best != null else cargo


## Loose one projectile at the target. A unit cannot attack during its attack
## cooldown. Sections 25.2 and 29.
func fire_at(victim: Node2D) -> void:
	if not can_attack() or not CombatTarget.is_valid(victim):
		return
	if bolt_scene == null or projectiles == null:
		# The build cannot make a bolt. Stand disarmed rather than melee, so the
		# missing piece is visible rather than faked. Section 8 of the invariants.
		return
	_attack_cooldown = data.attack_interval
	var bolt: EnemyBolt = bolt_scene.instantiate()
	projectiles.add_child(bolt)
	bolt.launch(
		global_position, victim.global_position,
		data.projectile_speed, float(data.attack_damage), data.maximum_range,
	)


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


## Shield slows an enemy standing in its area. A defender never reads this, so the
## slow reaches only the enemy side. Section 14.7.
func _status_speed_scale() -> float:
	return Shield.speed_scale(global_position)


func _neighbours() -> Array:
	return get_parent().get_children()


## A dead enemy changes to a light grey paper mark. Section 29.
func show_dead_mark() -> void:
	var frames: Array[Texture2D] = [DEAD_MARK]
	ink.extra_scale = 0.20
	ink.set_frames(frames)
