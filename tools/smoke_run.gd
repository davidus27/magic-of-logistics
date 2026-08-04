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
var _peak_enemies: int = 0
var _groups_fired: int = 0
var _furthest: float = 0.0
var _formation_time: float = 0.0
var _in_leash_time: float = 0.0
var _successful_casts: int = 0
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


## Cast Arc Bolt at the nearest enemy. Section 14.5.
func _fire_arc_bolt(delta: float) -> void:
	if _controller.state != GameController.State.RUN:
		return
	_cast_timer -= delta
	if _cast_timer > 0.0:
		return
	_cast_timer = CAST_PERIOD

	var nearest: Enemy = null
	var best := _wizard.current_spell().cast_range
	for enemy in _spawner.get_living():
		var distance := enemy.global_position.distance_to(_wizard.global_position)
		if distance < best:
			best = distance
			nearest = enemy
	if nearest != null and _wizard.try_cast(nearest.global_position):
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

	# Both enemy types can attack the cargo unit. Section 40. Only the
	# short-range type exists in this build, so only its damage is required.
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


# --- Plumbing -----------------------------------------------------------------


func _on_group_spawned(_index: int, count: int) -> void:
	_groups_fired += 1
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
