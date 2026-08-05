extends Node
## Headless check that a whole run works end to end.
##
## Loads the real Main scene, starts the default session with the fixed run
## seed, plays it, and asserts that the cargo reaches the final portal. Run it
## with:
##
##     Godot --headless --fixed-fps 60 res://tools/smoke_run.tscn
##
## The exit code is 0 when every check passes and 1 otherwise, so this can gate a
## commit. It runs inside a normal scene tree rather than as a --script main loop,
## because a custom main loop does not get the autoloads the game depends on.
##
## It plays badly on purpose. It holds one speed, gives one order at the start,
## and casts Arc Bolt at whatever is nearest. That is close to the worst a real
## tester will do, so a run that fails here is a run a first-time player cannot
## finish, which is what section 40 asks the build to support.

const MAIN_SCENE := "res://main/main.tscn"
const States := preload("res://world/defenders/defender_states.gd")

## Route length the map data is meant to produce. Section 11.
const EXPECTED_ROUTE_LENGTH := 9000.0
const ROUTE_LENGTH_TOLERANCE := 0.05

## Simulated seconds before the test gives up. The engine caps a run at 480
## seconds, so anything beyond that means the state machine is stuck.
const GIVE_UP_SECONDS := 520.0

## Section 7 asks for three to six minutes. At the Normal speed of section 13.1
## the 9000 pixel route is 100 seconds of driving, and mud, fights and the portal
## cast add the rest, so this build reaches the floor only at Slow. The band below
## is what a Normal-speed run should produce; section 7 is checked by playing,
## not here.
const MIN_RUN_SECONDS := 90.0
const MAX_RUN_SECONDS := 360.0

## Seconds between the scripted Arc Bolt casts.
const CAST_PERIOD := 0.6
## Seconds between the scripted defender order decisions.
const ORDER_PERIOD := 1.5
## Attack when at least this many enemies are alive, otherwise Defend. Below it
## the squad guards the wagon; at or above it the squad sorties to clear the
## field, which is the designed counter to the long-range standoff of §25.2.
const ATTACK_THRESHOLD := 2

## Route offset ahead of the cargo, in pixels, at which a closed barrier pulls
## the squad onto Repair instead of Attack or Defend. Comfortably past
## DefenderTuning.barrier_search_distance so the squad is already walking to
## the work points once the cargo motor clamps to a stop short of it. §19, §28.
const BARRIER_REPAIR_RANGE := 400.0

var _main: Node = null
var _controller: GameController = null
var _cargo: CargoUnit = null
var _map: Map = null
var _squad: Squad = null
var _spawner: EnemySpawner = null
var _wizard: Wizard = null

var _failures: PackedStringArray = PackedStringArray()
var _notes: PackedStringArray = PackedStringArray()
var _terrain_events: Array[String] = []
var _elapsed: float = 0.0
var _cast_timer: float = 0.0
var _spawned_total: int = 0
var _reinforcement_total: int = 0
var _peak_enemies: int = 0
var _groups_fired: int = 0
var _furthest: float = 0.0
var _formation_time: float = 0.0
var _in_leash_time: float = 0.0
var _successful_casts: int = 0
var _order_timer: float = 0.0
var _attacking: bool = false
var _repairing: bool = false
var _defender_states_seen: Dictionary = {}
## Lowest cargo health and lowest defender health-to-maximum ratio seen this
## run. Both stay at their starting value only if no enemy ever landed a hit.
var _min_cargo_health: int = 999999
var _min_defender_ratio: float = 1.0
var _finished: bool = false


func _ready() -> void:
	# Main pauses the tree between states, so this node has to keep processing.
	process_mode = Node.PROCESS_MODE_ALWAYS
	SoundBank.enabled = false

	var scene: PackedScene = load(MAIN_SCENE)
	if scene == null:
		_fail("could not load %s" % MAIN_SCENE)
		_report()
		return

	_main = scene.instantiate()
	# This node processes while paused so that it can drive the paused screens.
	# Without this line the game would inherit that from it and never really
	# pause, because a child with the default mode follows its parent.
	_main.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_main)

	_controller = _main.get_node("GameController")
	_cargo = _main.get_node("World/CargoUnit")
	_map = _main.get_node("World/Map")
	_squad = _main.get_node("World/Squad")
	_spawner = _main.get_node("World/EnemySpawner")
	_wizard = _main.get_node("World/Wizard")

	_cargo.terrain_changed.connect(_on_terrain_changed)
	_spawner.group_spawned.connect(_on_group_spawned)
	_spawner.reinforcements_spawned.connect(_on_reinforcements_spawned)

	_controller.begin_default_session()

	_check_route()
	_check_start_state()
	_check_squad()

	var motor := _cargo.motor as AutoPathMotor
	if motor == null:
		_fail("the default session did not produce an AutoPathMotor")
		_report()
		return
	motor.set_speed_level(CargoData.SpeedLevel.NORMAL)

	# Select all defenders and tell them to defend the cargo. Sections 16 and 17.
	_squad.select_all_living()
	_squad.order(Defender.States.DEFEND)


func _process(delta: float) -> void:
	if _finished:
		return
	_elapsed += delta
	_peak_enemies = maxi(_peak_enemies, _spawner.living_count())
	_manage_orders(delta)
	_fire_arc_bolt(delta)
	_sample_formation(delta)
	_track_health()

	if _controller.state == GameController.State.SUCCESS \
			or _controller.state == GameController.State.FAILURE:
		_check_outcome()
		_check_combat()
		_report()
		return

	if _elapsed > GIVE_UP_SECONDS:
		_fail("run did not reach an outcome within %.0f simulated seconds (state %s, offset %.0f of %.0f)" % [
			GIVE_UP_SECONDS, _controller.state_name(), _cargo.get_route_offset(), _map.route_length,
		])
		_report()


## Watch how far the defenders drift from the cargo unit.
##
## Section 15.2 gives three of the four defenders a speed below the Normal cargo
## speed of section 13.1, so without the catch-up of
## [member DefenderTuning.catch_up_margin] the squad falls behind for the whole
## run and never defends anything. This measures whether that is still true.
func _sample_formation(delta: float) -> void:
	if _controller.state != GameController.State.RUN:
		return
	for defender in _squad.get_living():
		_defender_states_seen[defender.state_id()] = true
		var distance := defender.distance_to_cargo()
		_furthest = maxf(_furthest, distance)
		_formation_time += delta
		if distance <= _squad.tuning.attack_leash:
			_in_leash_time += delta


## Lowest health values seen this run, so a whole run without a single enemy
## attack landing can still be detected once telemetry counters are gone.
func _track_health() -> void:
	if _controller.state != GameController.State.RUN \
			and _controller.state != GameController.State.PORTAL_CAST:
		return
	_min_cargo_health = mini(_min_cargo_health, _cargo.health)
	for defender in _squad.get_defenders():
		_min_defender_ratio = minf(_min_defender_ratio, float(defender.health) / float(defender.max_health))


## Send the squad out to fight when enemies gather and pull it back to guard the
## wagon when the field is clear. Sections 15.7 and 17. A single standing Defend
## order never lets the defenders reach the long-range enemies standing off at
## their preferred range, which is the counter section 15.7 gives them.
##
## A closed barrier ahead overrides both once the field is clear: the squad has
## no way through it other than Repair, so a run left on Attack or Defend would
## stall at the barrier and never reach the portal. Section 28. Repair gives
## barrier work total priority over combat, so switching to it while enemies are
## still alive would leave the cargo motor's hard stop at the barrier holding a
## stationary, undefended target — the cargo unit stops there regardless of the
## squad's order, so fighting on until the field clears costs nothing.
func _manage_orders(delta: float) -> void:
	_order_timer -= delta
	if _order_timer > 0.0:
		return
	_order_timer = ORDER_PERIOD

	if _barrier_ahead() != null and _spawner.living_count() == 0:
		if not _repairing:
			_repairing = true
			_attacking = false
			_squad.select_all_living()
			_squad.order(States.REPAIR)
		return
	_repairing = false

	var want_attack := _spawner.living_count() >= ATTACK_THRESHOLD
	if want_attack == _attacking:
		return
	_attacking = want_attack
	_squad.select_all_living()
	_squad.order(States.ATTACK if want_attack else States.DEFEND)


## The nearest closed barrier within [constant BARRIER_REPAIR_RANGE] ahead of
## the cargo on the route, or null if none blocks the way yet. Section 28.
func _barrier_ahead() -> Barrier:
	var reached := _cargo.get_route_offset()
	var closest: Barrier = null
	var closest_ahead := BARRIER_REPAIR_RANGE
	for barrier in _map.get_barriers():
		if barrier.is_open():
			continue
		var ahead := barrier.route_offset - reached
		if ahead >= 0.0 and ahead <= closest_ahead:
			closest_ahead = ahead
			closest = barrier
	return closest


## Cast Arc Bolt at the most dangerous enemy in range. Section 14.5.
##
## A first-time tester still aims at what is hurting the wagon rather than only
## at what is nearest: an enemy firing or striking the cargo first, then a
## long-range plinker standing off, then the nearest of the rest. Targeting
## nothing but the nearest lets the long-range enemy of section 25.2 shoot the
## cargo unopposed, which is a worse player than the one section 40 must support.
func _fire_arc_bolt(delta: float) -> void:
	if _controller.state != GameController.State.RUN:
		return
	_cast_timer -= delta
	if _cast_timer > 0.0:
		return
	_cast_timer = CAST_PERIOD

	var cast_range := _wizard.current_spell().cast_range
	var chosen: Enemy = null
	var best_score := -INF
	for enemy in _spawner.get_living():
		var distance := enemy.global_position.distance_to(_wizard.global_position)
		if distance > cast_range:
			continue
		var score := -distance
		if enemy.is_attacking_cargo():
			score += 4000.0
		elif enemy.data.kind == EnemyData.Kind.LONG_RANGE:
			score += 2000.0
		if score > best_score:
			best_score = score
			chosen = enemy
	if chosen != null and _wizard.try_cast(chosen.global_position):
		_successful_casts += 1


# --- Checks -------------------------------------------------------------------


func _check_route() -> void:
	var length := _map.route_length
	_notes.append("route length %.0fpx" % length)
	var drift := absf(length - EXPECTED_ROUTE_LENGTH) / EXPECTED_ROUTE_LENGTH
	if drift > ROUTE_LENGTH_TOLERANCE:
		_fail("route length %.0f is %.1f%% from the intended %.0f" % [
			length, drift * 100.0, EXPECTED_ROUTE_LENGTH,
		])
	if _map.route.portal_offset > length:
		_fail("the portal at %.0f is beyond the end of the route at %.0f" % [
			_map.route.portal_offset, length,
		])


func _check_start_state() -> void:
	if _controller.state != GameController.State.RUN:
		_fail("begin_default_session left the game in %s" % _controller.state_name())
	if _cargo.health != _cargo.data.initial_health:
		_fail("cargo started with %d health, expected %d" % [
			_cargo.health, _cargo.data.initial_health,
		])


## The player starts with four defenders. Section 15.1.
func _check_squad() -> void:
	var defenders := _squad.get_defenders()
	if defenders.size() != 4:
		_fail("the squad has %d defenders, expected 4" % defenders.size())
		return
	for defender in defenders:
		if defender.health != defender.data.max_health:
			_fail("%s started with %d of %d health" % [
				defender.data.id, defender.health, defender.data.max_health,
			])
		# The defender uses Follow after the start of the run. Section 15.5.
		if defender.state_id() != Defender.States.FOLLOW:
			_fail("%s started in %s, expected follow" % [
				defender.data.id, defender.state_id(),
			])
		if defender.distance_to_cargo() > _squad.tuning.defend_slot_max:
			_fail("%s started %.0fpx from the cargo, beyond the %.0fpx slot band" % [
				defender.data.id, defender.distance_to_cargo(), _squad.tuning.defend_slot_max,
			])


func _check_outcome() -> void:
	var success := _controller.state == GameController.State.SUCCESS
	if not success:
		_fail("run failed, reason %s" % _controller._end_reason)

	var duration := _controller.run_seconds
	_notes.append("run duration %.1fs" % duration)
	if duration < MIN_RUN_SECONDS or duration > MAX_RUN_SECONDS:
		_fail("run took %.1fs, outside the %.0f to %.0f band this build should produce" % [
			duration, MIN_RUN_SECONDS, MAX_RUN_SECONDS,
		])

	# Both mud areas must be crossed, so terrain detection is exercised in both
	# directions. Section 12.2 and 12.4.
	var mud_entries := 0
	for event in _terrain_events:
		if event == "Mud":
			mud_entries += 1
	_notes.append("terrain events %s" % ", ".join(_terrain_events))
	if mud_entries < _map.route.mud_zones.size():
		_fail("entered mud %d times, expected %d" % [mud_entries, _map.route.mud_zones.size()])

	var distance := _cargo.distance_travelled
	_notes.append("distance travelled %.0fpx" % distance)
	if distance < EXPECTED_ROUTE_LENGTH * 0.9:
		_fail("travelled only %.0fpx of a %.0fpx route" % [distance, _map.route.portal_offset])


## Everything the first combat loop has to prove. Sections 25, 26, 29 and 40.
func _check_combat() -> void:
	var triggers := _map.route.trigger_offsets.size()
	_notes.append("enemy groups fired, %d of %d spawning %d enemies, peak %d alive" % [
		_groups_fired, triggers, _spawned_total, _peak_enemies,
	])
	if _groups_fired < triggers:
		_fail("only %d of %d enemy trigger areas fired" % [_groups_fired, triggers])
	if _spawned_total <= 0:
		_fail("no enemies were spawned")

	# Both enemy types now exist, so the long-range half of the four groups that
	# call for it must actually be created rather than deferred. Sections 25.2
	# and 40.
	_notes.append("long-range deferred %d, threat reinforcement enemies %d" % [
		_spawner.deferred_long_range(), _reinforcement_total,
	])
	if _spawner.deferred_long_range() > 0:
		_fail("%d long-range enemies were deferred; the long-range scene is not wired" % [
			_spawner.deferred_long_range(),
		])
	# The threat value rises one point a second, so a run past 45 seconds must
	# have earned at least one reinforcement group. Section 27.
	if _controller.run_seconds > 45.0 and _reinforcement_total <= 0:
		_fail("run reached %.0fs of threat but no reinforcements spawned" % _controller.run_seconds)

	# Both enemy types can attack the cargo unit. Section 40.
	_notes.append("lowest cargo health %d of %d, lowest defender health ratio %.0f%%" % [
		_min_cargo_health, _cargo.data.initial_health, _min_defender_ratio * 100.0,
	])
	if _min_cargo_health >= _cargo.data.initial_health and _min_defender_ratio >= 1.0:
		_fail("no enemy landed a single attack in a whole run")

	# Defenders must fight, not follow. Sections 15.6 and 15.7.
	if not _defender_states_seen.has(States.DEFEND):
		_fail("no defender ever entered the Defend state")

	# The wizard can cast Arc Bolt. Section 40.
	_notes.append("spell casts %d" % _successful_casts)
	if _successful_casts <= 0:
		_fail("Arc Bolt was never cast")

	# Enemies must die, or nothing the defenders and the wizard did mattered.
	var living := _spawner.living_count()
	var killed := _spawned_total - living
	_notes.append("enemies killed %d, still alive at the portal %d" % [killed, living])
	if killed <= 0:
		_fail("not one enemy died in a whole run")

	# The escort has to stay an escort. A defender that spends the run outside
	# the attack leash of section 15.7 can never intercept anything.
	var in_leash := 0.0
	if _formation_time > 0.0:
		in_leash = _in_leash_time / _formation_time
	_notes.append("defenders within the %.0fpx leash %.0f%% of the time, furthest %.0fpx" % [
		_squad.tuning.attack_leash, in_leash * 100.0, _furthest,
	])
	if in_leash < 0.9:
		_fail("defenders were outside the attack leash %.0f%% of the run" % [
			(1.0 - in_leash) * 100.0,
		])

	# Every barrier must have opened, or the cargo could only have reached the
	# portal by never actually meeting one. Section 28.
	var barriers := _map.get_barriers()
	var barriers_open := 0
	for barrier in barriers:
		if barrier.is_open():
			barriers_open += 1
	_notes.append("barriers opened %d of %d" % [barriers_open, barriers.size()])
	if barriers_open < barriers.size():
		_fail("%d of %d barriers were never opened by the Repair order" % [
			barriers.size() - barriers_open, barriers.size(),
		])


# --- Plumbing -----------------------------------------------------------------


func _on_group_spawned(_index: int, count: int) -> void:
	_groups_fired += 1
	_spawned_total += count


## Reinforcements are counted into the spawn total so the killed tally stays a
## true difference against the living count. Section 27.
func _on_reinforcements_spawned(count: int) -> void:
	_reinforcement_total += count
	_spawned_total += count


func _on_terrain_changed(display_name: String, _factor: float) -> void:
	_terrain_events.append(display_name)


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	if _finished:
		return
	_finished = true

	print("")
	print("=== smoke run ===")
	for note in _notes:
		print("  %s" % note)

	if _failures.is_empty():
		print("  PASS: all checks succeeded")
		print("=================")
		quit_with(0)
		return

	for failure in _failures:
		printerr("  FAIL: %s" % failure)
	print("  %d check(s) failed" % _failures.size())
	print("=================")
	quit_with(1)


func quit_with(code: int) -> void:
	# Let the print buffer flush before the process ends.
	await get_tree().process_frame
	get_tree().quit(code)
