class_name Defender
extends UnitBody
## An autonomous crew unit near the cargo unit. Specification section 15.
##
## The player never moves a defender. The player selects defenders and gives an
## order, the order sets [member ordered_state], and the state machine executes
## it. That is the main design decision of section 2, so nothing here reads a
## movement key.
##
## The states live in [DefenderStates]. This script owns what every state shares:
## the statistics, the assigned formation slot, the attack cooldown, and the
## queries a state asks about the battlefield.

const States := preload("res://world/defenders/defender_states.gd")

## Line frames for each role. Section 10.4 draws a defender as a circle with a
## shield mark; the role monogram inside it is the asset pack's addition.
const ROLE_FRAMES := {
	"guard": [
		"res://assets/world/defender_guard_a.svg", "res://assets/world/defender_guard_b.svg",
	],
	"striker": [
		"res://assets/world/defender_striker_a.svg", "res://assets/world/defender_striker_b.svg",
	],
	"engineer": [
		"res://assets/world/defender_engineer_a.svg", "res://assets/world/defender_engineer_b.svg",
	],
	"warden": [
		"res://assets/world/defender_warden_a.svg", "res://assets/world/defender_warden_b.svg",
	],
}

const ORDER_MARKS := {
	States.ATTACK: preload("res://assets/feedback/order_attack.svg"),
	States.DEFEND: preload("res://assets/feedback/order_defend.svg"),
	States.REPAIR: preload("res://assets/feedback/order_repair.svg"),
}

const DEAD_MARK := preload("res://assets/world/dead_paper_mark.svg")

signal state_changed(defender: Defender, state: StringName)
signal selection_changed(defender: Defender, selected: bool)
signal downed(defender: Defender)

@export var data: DefenderData
@export var tuning: DefenderTuning

## Index in the squad, 0 to 3. Fixes the function key and the formation slot.
var slot_index: int = 0

## The state an order put this defender in. Follow, Defend, Attack or Repair.
## Return and the two death states are transient and never stored here.
var ordered_state: StringName = States.FOLLOW

var squad: Squad = null
var enemies: EnemySpawner = null
var cargo: CargoUnit = null
var map: Map = null

var selected: bool = false:
	set(value):
		if selected == value:
			return
		selected = value
		_selection_ring.visible = value
		selection_changed.emit(self, value)

## Current attack target, or null. Read by the user interface for the target
## line of section 30.6.
var target: Node2D = null
## Seconds left of the downed timer. Section 15.10.
var downed_left: float = 0.0

var _attack_cooldown: float = 0.0
var _retarget_cooldown: float = 0.0

@onready var _selection_ring: InkSprite = $SelectionRing
@onready var _order_mark: InkSprite = $OrderMark
@onready var _downed_ring: InkSprite = $DownedRing


func _ready() -> void:
	super()
	collision_layer = Layers.DEFENDER
	# Defenders can move through other defenders and through the cargo.
	# Sections 13.3 and 15.3.
	collision_mask = Layers.UNIT_MASK

	_selection_ring.visible = false
	_order_mark.visible = false
	_downed_ring.visible = false

	machine.add_state(States.Follow.new())
	machine.add_state(States.Defend.new())
	machine.add_state(States.Attack.new())
	machine.add_state(States.Repair.new())
	machine.add_state(States.Return.new())
	machine.add_state(States.Downed.new())
	machine.add_state(States.Dead.new())
	machine.state_changed.connect(_on_state_changed)


## Place a defender on the battlefield with its statistics and its links to the
## rest of the world. Called by [Squad] when a run starts.
func setup(
	defender_data: DefenderData,
	defender_tuning: DefenderTuning,
	index: int,
	world_squad: Squad,
	world_cargo: CargoUnit,
	world_enemies: EnemySpawner,
	world_map: Map
) -> void:
	data = defender_data
	tuning = defender_tuning
	slot_index = index
	squad = world_squad
	cargo = world_cargo
	enemies = world_enemies
	map = world_map

	max_health = data.max_health
	health = data.max_health
	defense = data.defense
	base_speed = data.speed
	separation_radius = tuning.separation_radius
	blocked_timeout = tuning.blocked_timeout
	path_interval = tuning.path_interval

	var frames: Array[Texture2D] = []
	for path: String in ROLE_FRAMES.get(data.id, ROLE_FRAMES["guard"]):
		frames.append(load(path))
	ink.set_frames(frames)

	global_position = slot_position()
	ordered_state = States.FOLLOW
	# The defender uses Follow after the start of the run. Section 15.5.
	machine.start(States.FOLLOW)


func _physics_process(delta: float) -> void:
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_retarget_cooldown = maxf(0.0, _retarget_cooldown - delta)
	super(delta)


# --- Orders -------------------------------------------------------------------


## Give this defender a role order. Sections 17 and 18.
func give_order(order: StringName) -> void:
	if not is_alive():
		return
	ordered_state = order
	_show_order_mark(order)
	# A defender on its way home finishes returning first. Section 15.9 says the
	# Return state changes to the ordered state inside the defense radius, so a
	# new order changes where it is going, not what it is doing now.
	if machine.current_id() != States.RETURN:
		machine.change_to(order)


# --- Formation ----------------------------------------------------------------


## World position of this defender's assigned slot around the cargo unit.
## The slots sit between 90 and 130 pixels from the cargo centre. Section 15.6.
func slot_position() -> Vector2:
	if cargo == null:
		return global_position
	return cargo.to_global(squad.slot_offset(slot_index))


## World position of this defender's rear cargo work point. Section 15.8.
func work_point() -> Vector2:
	if cargo == null:
		return global_position
	return cargo.to_global(squad.work_point_offset(slot_index))


func distance_to_cargo() -> float:
	if cargo == null:
		return 0.0
	return global_position.distance_to(cargo.global_position)


## Speed multiplier for a defender walking back to its slot.
##
## One where the defender is already fast enough. See
## [member DefenderTuning.catch_up_margin] for why the rest is needed.
func catch_up_scale() -> float:
	if cargo == null:
		return 1.0
	var own := base_speed * terrain_factor
	if own <= 0.0:
		return 1.0
	return maxf(1.0, (cargo.get_current_speed() + tuning.catch_up_margin) / own)


# --- Combat -------------------------------------------------------------------


func can_attack() -> bool:
	return _attack_cooldown <= 0.0


## Strike the current target. Attack damage applies once each second. Section 15.2.
func strike(victim: Node2D) -> void:
	if not can_attack() or not CombatTarget.is_valid(victim):
		return
	_attack_cooldown = tuning.attack_interval
	CombatTarget.damage(victim, data.attack_damage)


## True when it is time to look for a different target. Section 15.7.
func may_retarget() -> bool:
	if _retarget_cooldown > 0.0:
		return false
	_retarget_cooldown = tuning.retarget_interval
	return true


## The enemy a Defend state should intercept: the one nearest the cargo unit
## inside the defense radius. Section 15.6.
##
## An enemy another defender is already on is taken last. Section 15.6 describes
## one defender, and four defenders all reading it at once would all intercept
## the same enemy while the rest of a group walked into the wagon. Preferring a
## free enemy keeps the rule of that section for each defender and spreads the
## squad across the threat.
func nearest_enemy_to_cargo(radius: float) -> Node2D:
	if enemies == null or cargo == null:
		return null

	var free_pick: Node2D = null
	var free_distance := radius
	var any_pick: Node2D = null
	var any_distance := radius

	for enemy in enemies.get_living():
		var distance := enemy.global_position.distance_to(cargo.global_position)
		if distance < any_distance:
			any_distance = distance
			any_pick = enemy
		if distance < free_distance and not squad.is_claimed(enemy, self):
			free_distance = distance
			free_pick = enemy

	return free_pick if free_pick != null else any_pick


## The target an Attack state should take, by the priority of section 15.7.
##
## The first entry of that list, a direct target from the player, belongs to
## defender control method B and lands with profile P2.
func priority_target() -> Node2D:
	if enemies == null or cargo == null:
		return null

	var attacking_cargo: Node2D = null
	var attacking_distance := INF
	var long_range: Node2D = null
	var long_distance := INF
	var short_range: Node2D = null
	var short_distance := INF

	for enemy in enemies.get_living():
		var from_cargo := enemy.global_position.distance_to(cargo.global_position)
		if from_cargo > tuning.attack_radius:
			continue
		var from_self := global_position.distance_to(enemy.global_position)
		if enemy.is_attacking_cargo() and from_self < attacking_distance:
			attacking_distance = from_self
			attacking_cargo = enemy
		if enemy.data.kind == EnemyData.Kind.LONG_RANGE:
			if from_self < long_distance:
				long_distance = from_self
				long_range = enemy
		elif from_self < short_distance:
			short_distance = from_self
			short_range = enemy

	# 2. An enemy that attacks the cargo unit.
	if attacking_cargo != null:
		return attacking_cargo
	# 3. The nearest long-range enemy.
	if long_range != null:
		return long_range
	# 4. The nearest short-range enemy.
	return short_range


## Rank of an enemy in the target list of section 15.7. Lower is more urgent.
## Rank 1, a direct target from the player, arrives with defender control
## method B and profile P2.
func target_priority(enemy: Node2D) -> int:
	var unit := enemy as Enemy
	if unit == null:
		return 9
	if unit.is_attacking_cargo():
		return 2
	if unit.data.kind == EnemyData.Kind.LONG_RANGE:
		return 3
	return 4


# --- Repair -------------------------------------------------------------------


## The barrier this defender should work on, or null. Section 15.8.
func barrier_ahead() -> Barrier:
	if map == null or cargo == null:
		return null
	var forward := Vector2.RIGHT.rotated(cargo.rotation)
	var best: Barrier = null
	var best_distance := tuning.barrier_search_distance
	for barrier in map.get_barriers():
		if barrier.is_open():
			continue
		var offset := barrier.global_position - cargo.global_position
		if offset.dot(forward) <= 0.0:
			continue
		var distance := offset.length()
		if distance < best_distance:
			best_distance = distance
			best = barrier
	return best


## True when the cargo unit can be repaired now. Cargo repair works only at Stop
## speed. Section 15.8.
func cargo_repair_available() -> bool:
	if cargo == null or cargo.health >= cargo.data.max_health:
		return false
	return cargo.get_speed_level() <= CargoData.SpeedLevel.STOP


# --- Downed and dead ----------------------------------------------------------


func is_downed() -> bool:
	return machine.current_id() == States.DOWNED


func is_dead() -> bool:
	return machine.current_id() == States.DEAD


## Bring a downed defender back with Mend. Section 14.6.
func revive(with_health: int) -> bool:
	if not is_downed():
		return false
	health = clampi(with_health, 1, max_health)
	downed_left = 0.0
	health_bar.show_ratio(float(health) / float(max_health))
	health_changed.emit(health, max_health)
	machine.change_to(ordered_state)
	return true


func _on_zero_health() -> void:
	# A defender enters the Downed state at zero health. Section 15.10.
	target = null
	downed.emit(self)
	machine.change_to(States.DOWNED)


func _zone_factor(zone: TerrainZone) -> float:
	return zone.defender_factor


func _neighbours() -> Array:
	return squad.get_defenders() if squad != null else []


# --- Presentation -------------------------------------------------------------


func state_id() -> StringName:
	return machine.current_id()


## Player-facing state name for a portrait. Section 30.3.
func state_label() -> String:
	return String(machine.current_id()).capitalize()


func _on_state_changed(_from: StringName, to: StringName) -> void:
	state_changed.emit(self, to)


func _show_order_mark(order: StringName) -> void:
	# An ordered defender shows a small order symbol above its body. Section 10.5.
	# Follow is the state a defender starts in rather than one an order chooses,
	# so it has no mark.
	var texture: Texture2D = ORDER_MARKS.get(order)
	if texture == null:
		_order_mark.visible = false
		return
	_order_mark.set_frames([texture] as Array[Texture2D])
	_order_mark.visible = true


## Show or hide the ring that counts down the downed timer. Section 15.10.
func set_downed_visual(value: bool) -> void:
	_downed_ring.visible = value
	_order_mark.visible = not value and ORDER_MARKS.has(ordered_state)


## Turn the defender into the light grey paper mark of section 15.11.
func show_dead_mark() -> void:
	selected = false
	_selection_ring.visible = false
	_order_mark.visible = false
	_downed_ring.visible = false
	var frames: Array[Texture2D] = [DEAD_MARK]
	ink.extra_scale = 0.22
	ink.set_frames(frames)
