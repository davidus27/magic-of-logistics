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

	var before_deaths := int(Telemetry.get_record().get("defender_deaths", 0))
	await _seconds(tuning.downed_seconds + 0.5)

	_expect(victim.is_dead(), "the downed timer ended in %s, expected dead" % victim.state_id())
	_expect(victim.is_dead_mark(), "a dead defender still has its collision shape")
	var after_deaths := int(Telemetry.get_record().get("defender_deaths", 0))
	_expect(after_deaths == before_deaths + 1,
		"the death was counted %d times" % (after_deaths - before_deaths))
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


## Cargo repair works at Stop or Slow speed and not above it. Section 15.8.
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
	var recorded := float(Telemetry.get_record().get("cargo_repair_amount", 0.0))
	_expect(recorded > 0.0, "cargo repair was not recorded in the telemetry")
	_notes.append("repair added %d health at Stop and none at Fast" % (_cargo.health - wounded))


## The wizard rejects a cast it cannot pay for or reach. Section 14.4.
func _check_spell_limits() -> void:
	var before := int(Telemetry.get_record().get("invalid_spell_casts", 0))
	var spell := _wizard.current_spell()

	# Out of range.
	_wizard.try_cast(_wizard.global_position + Vector2.RIGHT * (spell.cast_range + 50.0))
	# Out of mana.
	_wizard.mana = 0.0
	_wizard.try_cast(_wizard.global_position + Vector2.RIGHT * 40.0)

	var after := int(Telemetry.get_record().get("invalid_spell_casts", 0))
	_expect(after == before + 2,
		"%d invalid casts counted, expected 2" % (after - before))

	# Mend and Ward are not in this build and must not become selectable.
	_wizard.select_spell(1)
	_expect(_wizard.selected_index == 0,
		"an unimplemented spell was selected (index %d)" % _wizard.selected_index)
	_notes.append("out of range, out of mana and unimplemented casts are all refused")


## The player fails the run when the cargo health becomes zero. Section 6.
func _check_failure() -> void:
	_cargo.apply_damage(_cargo.health)
	await _frames(3)
	_expect(_controller.state == GameController.State.RESULT,
		"cargo destruction left the game in %s" % _controller.state_name())
	var record := Telemetry.get_record()
	_expect(not bool(record.get("success", true)), "a destroyed cargo recorded a success")
	_expect(String(record.get("end_reason", "")) == "cargo_destroyed",
		"the end reason was '%s'" % record.get("end_reason", ""))
	_notes.append("cargo destruction fails the run and opens the result screen")


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
