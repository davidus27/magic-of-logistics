extends Node
## Headless checks for the states a straight run does not reach.
##
##     Godot --headless --fixed-fps 60 res://tools/behaviour_checks.tscn
##
## [code]smoke_run[/code] plays a whole run and proves the loop works. It cannot
## prove much about Downed, Dead, revive, Repair or the failure state, because a
## run that reaches those is a run that went badly. This drives each of them
## directly through the same public calls the game uses, and exits non-zero on
## the first broken one, so both tools together gate a commit.

const MAIN_SCENE := "res://main/main.tscn"
const States := preload("res://world/defenders/defender_states.gd")
const EnemyStates := preload("res://world/enemies/enemy_states.gd")

var _main: Node = null
var _controller: GameController = null
var _cargo: CargoUnit = null
var _squad: Squad = null
var _spawner: EnemySpawner = null
var _wizard: Wizard = null

var _failures: PackedStringArray = PackedStringArray()
var _notes: PackedStringArray = PackedStringArray()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SoundBank.enabled = false

	_main = (load(MAIN_SCENE) as PackedScene).instantiate()
	# This node processes while paused so that it can drive the paused screens.
	# Without this line the game would inherit that from it and never really
	# pause, because a child with the default mode follows its parent.
	_main.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_main)

	_controller = _main.get_node("GameController")
	_cargo = _main.get_node("World/CargoUnit")
	_squad = _main.get_node("World/Squad")
	_spawner = _main.get_node("World/EnemySpawner")
	_wizard = _main.get_node("World/Wizard")

	_controller.begin_default_session()
	await _frames(2)

	# The new combat pieces first, while all four defenders are alive and the
	# field is otherwise empty. Both spawn enemies, so both clean up after
	# themselves before the destructive checks below run.
	await _check_long_range()
	await _check_reinforcements()

	await _check_orders()
	await _check_downed_and_dead()
	await _check_revive()
	await _check_repair()
	await _check_spell_limits()
	await _check_failure()

	_report()


# --- Checks -------------------------------------------------------------------


## An order changes the state of every selected defender and nothing else.
## Sections 16 and 17.
func _check_orders() -> void:
	var defenders := _squad.get_defenders()
	_squad.select_only(1)
	_squad.order(States.ATTACK)
	await _frames(2)

	_expect(defenders[1].state_id() == States.ATTACK,
		"an Attack order left the selected defender in %s" % defenders[1].state_id())
	_expect(defenders[0].state_id() != States.ATTACK,
		"an Attack order reached an unselected defender")

	# Shift adds to the selection. Section 16.
	_squad.toggle_selection(2)
	_expect(_squad.get_selected().size() == 2,
		"shift-selecting gave %d selected defenders, expected 2" % _squad.get_selected().size())

	_squad.select_all_living()
	_squad.order(States.DEFEND)
	await _frames(2)
	for defender in defenders:
		_expect(defender.state_id() == States.DEFEND,
			"%s is in %s after a Defend order to all" % [defender.data.id, defender.state_id()])
	_notes.append("orders reach the selection and no one else")


## The long-range enemy stands off at its preferred range, fires a bolt, and the
## bolt lands. Section 25.2. Placed straight above the cargo, clear of the four
## formation slots, so its line to the wagon is open.
func _check_long_range() -> void:
	var world := _main.get_node("World")
	var container := world.get_node("EnemyContainer") as Node2D
	var projectiles := world.get_node("ProjectileContainer") as Node2D
	var scene := load("res://world/enemies/enemy_long_range.tscn") as PackedScene
	var data := load("res://data/enemies/enemy_long_range.tres") as EnemyData

	var enemy: Enemy = scene.instantiate()
	container.add_child(enemy)
	enemy.global_position = _cargo.global_position + Vector2.UP * data.preferred_range
	enemy.setup(data, _cargo, _squad)
	enemy.set_ranged_fire(projectiles, load("res://world/enemies/enemy_bolt.tscn"))

	var before := _party_health()
	var saw_fire := false
	var saw_bolt := false
	for _i in int(2.5 * 60.0):
		await get_tree().process_frame
		if is_instance_valid(enemy) and enemy.machine.current_id() == EnemyStates.FIRE:
			saw_fire = true
		for child in projectiles.get_children():
			if child is EnemyBolt:
				saw_bolt = true

	_expect(saw_fire, "the long-range enemy never reached its Fire state")
	_expect(saw_bolt, "the long-range enemy never fired a bolt")
	_expect(_party_health() < before,
		"a long-range bolt landed no damage, party health held at %d" % before)
	_notes.append("long-range enemy stood off, fired, and its bolt landed")

	if is_instance_valid(enemy):
		enemy.queue_free()
	await _frames(2)


## The threat system sends a reinforcement group when the value passes an
## interval, behind the cargo and off the visible screen. Section 27.
func _check_reinforcements() -> void:
	var schedule := _spawner.schedule
	var before := _spawner.living_count()

	var made := _spawner.update_threat(schedule.reinforcement_threat_interval + 0.5)
	await _frames(2)
	_expect(made >= 1, "threat passing the interval created no reinforcement group")

	var living := _spawner.get_living()
	var added := living.size() - before
	_expect(added >= schedule.reinforcement_size(),
		"a reinforcement group added %d enemies, expected %d" % [added, schedule.reinforcement_size()])

	# Every fresh enemy must be outside the visible screen. Section 27.
	var camera := _main.get_node("World/CameraRig") as Camera2D
	var view_size := get_viewport().get_visible_rect().size / camera.zoom
	var screen := Rect2(camera.global_position - view_size * 0.5, view_size)
	var offscreen := true
	var fresh: Array[Enemy] = []
	for index in range(before, living.size()):
		fresh.append(living[index])
		if screen.has_point(living[index].global_position):
			offscreen = false
	_expect(offscreen, "a reinforcement enemy spawned inside the visible screen")
	_notes.append("threat reinforcement group of %d spawned off screen behind the cargo" % added)

	# Clear them so they do not walk in and attack during the later checks.
	for enemy in fresh:
		enemy.queue_free()
	await _frames(2)


## Total health of the cargo unit and the four defenders, for a hit test that
## does not care which of them a bolt found.
func _party_health() -> int:
	var total := _cargo.health
	for defender in _squad.get_defenders():
		total += defender.health
	return total


## Zero health starts a 15 second downed timer, and the timer ends in Dead.
## Sections 15.10 and 15.11.
func _check_downed_and_dead() -> void:
	var victim := _squad.get_defenders()[0]
	var tuning := victim.tuning

	victim.apply_damage(victim.max_health + victim.defense)
	await _frames(2)

	_expect(victim.is_downed(), "a defender at zero health is in %s" % victim.state_id())
	_expect(not victim.is_alive(), "a downed defender still counts as alive")
	_expect(victim.selected == false, "a downed defender stayed selected")
	_expect(absf(victim.downed_left - tuning.downed_seconds) < 0.2,
		"the downed timer started at %.1fs, expected %.1fs" % [
			victim.downed_left, tuning.downed_seconds,
		])
	_expect(_squad.survivor_count() == 3,
		"%d survivors after one defender went down, expected 3" % _squad.survivor_count())

	await _seconds(tuning.downed_seconds + 0.5)

	_expect(victim.is_dead(), "the downed timer ended in %s, expected dead" % victim.state_id())
	_expect(victim.is_dead_mark(), "a dead defender still has its collision shape")
	_expect(_squad.survivor_count() == 3,
		"%d survivors after one defender died, expected 3" % _squad.survivor_count())
	_notes.append("downed for %.0fs, then dead with no collision shape" % tuning.downed_seconds)


## Mend brings a downed defender back. Section 14.6.
func _check_revive() -> void:
	var victim := _squad.get_defenders()[1]
	victim.apply_damage(victim.max_health + victim.defense)
	await _frames(2)
	_expect(victim.is_downed(), "the second defender did not go down")

	var revived := victim.revive(20)
	await _frames(2)
	_expect(revived, "revive refused a downed defender")
	_expect(victim.is_alive() and victim.health == 20,
		"a revived defender has %d health in state %s" % [victim.health, victim.state_id()])

	# A dead defender cannot return during the run. Section 15.11.
	_expect(not _squad.get_defenders()[0].revive(20),
		"revive brought a dead defender back")
	_notes.append("revive works on a downed defender and not on a dead one")


## Cargo repair works at Stop speed and not above it. Section 15.8.
func _check_repair() -> void:
	var motor := _cargo.motor as AutoPathMotor
	_cargo.apply_damage(40)
	var wounded := _cargo.health

	# Above Slow the defender waits at the rear slot and repairs nothing.
	motor.set_speed_level(CargoData.SpeedLevel.FAST)
	_squad.select_all_living()
	_squad.order(States.REPAIR)
	await _seconds(3.0)
	_expect(_cargo.health == wounded,
		"the cargo healed from %d to %d at Fast speed" % [wounded, _cargo.health])

	# At Stop the defenders walk to the rear work points and repair.
	motor.set_speed_level(CargoData.SpeedLevel.STOP)
	await _seconds(6.0)
	_expect(_cargo.health > wounded,
		"no cargo repair at Stop speed after 6 seconds, still %d" % _cargo.health)
	_notes.append("repair added %d health at Stop and none at Fast" % (_cargo.health - wounded))


## The wizard rejects a cast it cannot pay for or reach. Section 14.4.
func _check_spell_limits() -> void:
	var spell := _wizard.current_spell()

	# Out of range.
	_expect(not _wizard.try_cast(_wizard.global_position + Vector2.RIGHT * (spell.cast_range + 50.0)),
		"a cast beyond spell range was accepted")

	# Out of mana.
	_wizard.mana = 0.0
	_expect(not _wizard.try_cast(_wizard.global_position + Vector2.RIGHT * 40.0),
		"a cast without enough mana was accepted")

	# Mend and Ward are not in this build and must not become selectable.
	_wizard.select_spell(1)
	_expect(_wizard.selected_index == 0,
		"an unimplemented spell was selected (index %d)" % _wizard.selected_index)
	_notes.append("out of range, out of mana and unimplemented casts are all refused")


## The player fails the run when the cargo health becomes zero. Section 6.
func _check_failure() -> void:
	_cargo.apply_damage(_cargo.health)
	await _frames(3)
	_expect(_controller.state == GameController.State.FAILURE,
		"cargo destruction left the game in %s" % _controller.state_name())
	_expect(_controller._end_reason == "cargo_destroyed",
		"the end reason was '%s'" % _controller._end_reason)
	_notes.append("cargo destruction fails the run and shows the outcome banner")


# --- Plumbing -----------------------------------------------------------------


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _seconds(amount: float) -> void:
	await _frames(int(ceilf(amount * 60.0)))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _report() -> void:
	print("")
	print("=== behaviour checks ===")
	for note in _notes:
		print("  %s" % note)
	if _failures.is_empty():
		print("  PASS: all checks succeeded")
		print("========================")
		await get_tree().process_frame
		get_tree().quit(0)
		return
	for failure in _failures:
		printerr("  FAIL: %s" % failure)
	print("  %d check(s) failed" % _failures.size())
	print("========================")
	await get_tree().process_frame
	get_tree().quit(1)
