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

	# The wizard spells, also while the squad is whole. Heal heals and revives,
	# Shield slows and shields, and each returns its target to full afterwards.
	await _check_heal()
	await _check_shield()

	await _check_barriers()

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


## Heal heals a wounded defender and the cargo unit, and revives a downed one.
## Section 14.6. Cast through the real [method Wizard.try_cast] so the range,
## mana and target-pick path is what the game uses.
func _check_heal() -> void:
	var heal := _wizard.get_spells()[1]
	_wizard.select_spell(1)
	_expect(_wizard.selected_index == 1, "Heal could not be selected once implemented")

	# Heal a wounded but living defender. Heal heals synchronously inside the
	# cast, so health is read with no physics frame between: a stray bolt in
	# flight cannot land in the gap and make the amount read wrong.
	var hurt := _squad.get_defenders()[2]
	hurt.apply_damage(40)
	var before := hurt.health
	_heal_ready()
	var healed := _wizard.try_cast(hurt.global_position)
	_expect(healed, "Heal on a wounded defender was refused")
	_expect(hurt.health == mini(hurt.max_health, before + heal.heal_defender),
		"Heal took a defender from %d to %d, expected +%d" % [before, hurt.health, heal.heal_defender])

	# Revive a downed defender.
	var fallen := _squad.get_defenders()[3]
	fallen.apply_damage(fallen.max_health + fallen.defense)
	await _frames(2)
	_expect(fallen.is_downed(), "the fourth defender did not go down for the revive test")
	_heal_ready()
	var revived := _wizard.try_cast(fallen.global_position)
	_expect(revived, "Heal on a downed defender was refused")
	_expect(fallen.is_alive() and fallen.health == heal.revive_health,
		"Heal-revive left the defender at %d health in %s" % [fallen.health, fallen.state_id()])

	# Heal the cargo unit.
	_cargo.apply_damage(30)
	var cargo_before := _cargo.health
	_heal_ready()
	var cargo_healed := _wizard.try_cast(_cargo.global_position)
	_expect(cargo_healed, "Heal on the cargo unit was refused")
	_expect(_cargo.health == mini(_cargo.data.max_health, cargo_before + heal.heal_cargo),
		"Heal took the cargo from %d to %d, expected +%d" % [
			cargo_before, _cargo.health, heal.heal_cargo,
		])

	# Nothing menable under the pointer: no target, and the cast spends nothing.
	_heal_ready()
	var mana_before := _wizard.mana
	var empty := _wizard.try_cast(_wizard.global_position + Vector2.RIGHT * 300.0)
	_expect(not empty, "Heal cast on empty ground was accepted")
	_expect(is_equal_approx(_wizard.mana, mana_before),
		"a refused Heal still spent mana, %.0f to %.0f" % [mana_before, _wizard.mana])

	# Put the squad back to full so the later checks start clean.
	hurt.heal(hurt.max_health)
	fallen.heal(fallen.max_health)
	_notes.append("Heal healed a defender and the cargo, revived a downed defender, refused empty ground")


## Shield drops one protection area that slows enemies and softens their bolts
## inside it, replaces itself on a second cast, and expires. Section 14.7.
func _check_shield() -> void:
	var shield := _wizard.get_spells()[2]
	_wizard.select_spell(2)
	_expect(_wizard.selected_index == 2, "Shield could not be selected once implemented")

	var effect_container := _main.get_node("World/EffectContainer") as Node2D
	var at := _wizard.global_position + Vector2.RIGHT * 150.0
	_shield_ready()
	var cast := _wizard.try_cast(at)
	await _frames(2)
	_expect(cast, "Shield was refused inside its cast range")
	_expect(Shield.active != null and Shield.active.contains_point(at),
		"no active Shield covers the cast point after a Shield cast")
	_expect(effect_container.get_child_count() == 1,
		"a Shield cast left %d effect nodes, expected 1" % effect_container.get_child_count())

	# A bolt landing inside does far less than one landing outside. Section 14.7.
	var outside := at + Vector2.RIGHT * (shield.effect_radius + 60.0)
	var inside_damage := Shield.reduced_damage(at, 100)
	var outside_damage := Shield.reduced_damage(outside, 100)
	_expect(inside_damage < outside_damage,
		"Shield reduced a bolt to %d inside and %d outside" % [inside_damage, outside_damage])
	_expect(outside_damage == 100, "Shield changed damage outside its area, %d of 100" % outside_damage)

	# An enemy inside the area moves slower; outside it is untouched.
	_expect(Shield.speed_scale(at) < 1.0, "Shield did not slow an enemy inside its area")
	_expect(is_equal_approx(Shield.speed_scale(outside), 1.0),
		"Shield slowed an enemy outside its area, scale %.2f" % Shield.speed_scale(outside))

	# The enemy body reads that slow through its own hook, not only the helper.
	var probe := _place_probe_enemy(at)
	await _frames(2)
	_expect(probe._status_speed_scale() < 1.0,
		"an enemy body in a Shield did not read the slow, scale %.2f" % probe._status_speed_scale())
	if is_instance_valid(probe):
		probe.queue_free()

	# Only one Shield is active at a time: a second cast replaces the first.
	var first := Shield.active
	_shield_ready()
	_wizard.try_cast(_wizard.global_position + Vector2.UP * 150.0)
	await _frames(2)
	_expect(Shield.active != null and Shield.active != first,
		"a second Shield cast did not take over as the active one")
	_expect(not is_instance_valid(first), "the first Shield survived a second cast")

	# Shield stays active for its duration, then clears itself. Section 14.7.
	await _seconds(shield.duration + 0.3)
	_expect(Shield.active == null, "a Shield outlived its duration of %.0fs" % shield.duration)
	_notes.append("Shield slowed and shielded inside its area, replaced itself, and expired after %.0fs" % shield.duration)

	# Leave the wizard on Arc Bolt with mana and no cooldown for the next checks.
	_wizard.select_spell(0)
	_heal_ready()


## A closed barrier stops the cargo short of it, Repair opens it and rebakes
## the navigation mesh, and the cargo then passes through. Section 28.
func _check_barriers() -> void:
	var map := _main.get_node("World/Map") as Map
	var barriers := map.get_barriers()
	_expect(barriers.size() == 2, "the map has %d barriers, expected 2" % barriers.size())
	for barrier in barriers:
		_expect(not barrier.is_open(),
			"a barrier at route offset %.0f started open" % barrier.route_offset)
	var first := barriers[0]

	# A closed barrier stops the cargo short of it, not at it. Section 19.
	var motor := _cargo.motor as AutoPathMotor
	motor.jump_to(first.route_offset - 300.0)

	# The jump crosses several enemy trigger areas the cargo would otherwise
	# reach gradually, so the spawner fires all of them here at once (section
	# 26). They are not part of this check, so they are cleared before they can
	# attack a cargo that is about to stand still for Repair; left alive, an
	# unopposed swarm can destroy the cargo and pause the whole tree.
	await _frames(2)
	for enemy in _spawner.get_living():
		enemy.queue_free()
	await _frames(2)

	motor.set_speed_level(CargoData.SpeedLevel.NORMAL)
	await _seconds(4.0)
	var stop_offset := motor.get_route_offset()
	_expect(stop_offset < first.route_offset,
		"the cargo reached %.0f, at or past the closed barrier at %.0f" % [
			stop_offset, first.route_offset,
		])
	await _seconds(1.0)
	_expect(is_equal_approx(motor.get_route_offset(), stop_offset),
		"the cargo crept from %.1f to %.1f against a closed barrier" % [
			stop_offset, motor.get_route_offset(),
		])

	# Repair opens the barrier and disables its collision. Section 28. The
	# defenders are placed on the cargo's formation slots rather than walked
	# there, so the check does not spend real time on the approach.
	for defender in _squad.get_defenders():
		defender.global_position = _cargo.to_global(_squad.slot_offset(defender.slot_index))
	_squad.select_all_living()
	_squad.order(States.REPAIR)

	var opened := false
	for _i in int(20.0 * 60.0):
		await get_tree().process_frame
		if first.is_open():
			opened = true
			break
	_expect(opened, "the barrier under repair never reached is_open()")
	_expect(first._collision.disabled, "an open barrier still has an enabled collision shape")

	# The navigation mesh is rebaked once the barrier opens: the point it used
	# to obstruct is inside the traversable area again. Section 34.
	await _frames(2)
	var navigation_map := map.get_world_2d().navigation_map
	var closest := NavigationServer2D.map_get_closest_point(navigation_map, first.global_position)
	_expect(closest.distance_to(first.global_position) < 5.0,
		"the navigation mesh still excludes the opened barrier by %.1fpx" % closest.distance_to(first.global_position))

	# The cargo can now advance past the offset that used to stop it. Section 19.
	await _seconds(3.0)
	_expect(motor.get_route_offset() > first.route_offset,
		"the cargo stayed at %.0f, could not pass the opened barrier at %.0f" % [
			motor.get_route_offset(), first.route_offset,
		])

	# Stop rather than leave the cargo rolling: the later checks assume a still
	# field, and a moving cargo would keep crossing enemy trigger offsets with
	# nobody ordered to defend it.
	motor.set_speed_level(CargoData.SpeedLevel.STOP)
	for enemy in _spawner.get_living():
		enemy.queue_free()
	await _frames(2)
	_notes.append("a closed barrier stopped the cargo short, Repair opened it and rebaked navigation, and the cargo passed through")


## Reset the wizard so the next scripted cast is not blocked by mana or the
## cooldown of a spell that was just cast. Not a game action; a test convenience.
func _heal_ready() -> void:
	_wizard.mana = Wizard.MANA_MAX
	_wizard._cooldowns.fill(0.0)


func _shield_ready() -> void:
	_heal_ready()


## A short-range enemy dropped straight onto a point, for a check that only needs
## a body standing there. The caller frees it.
func _place_probe_enemy(at: Vector2) -> Enemy:
	var container := _main.get_node("World/EnemyContainer") as Node2D
	var scene := load("res://world/enemies/enemy_short_range.tscn") as PackedScene
	var data := load("res://data/enemies/enemy_short_range.tres") as EnemyData
	var enemy: Enemy = scene.instantiate()
	container.add_child(enemy)
	enemy.global_position = at
	enemy.setup(data, _cargo, _squad)
	return enemy


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


## Heal brings a downed defender back. Section 14.6.
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
	# Arc Bolt with full mana and no cooldown, so a rejection can only come from
	# the limit under test and not from a spell cast in an earlier check.
	_wizard.select_spell(0)
	_heal_ready()
	var spell := _wizard.current_spell()

	# Out of range.
	_expect(not _wizard.try_cast(_wizard.global_position + Vector2.RIGHT * (spell.cast_range + 50.0)),
		"a cast beyond spell range was accepted")

	# Out of mana.
	_wizard.mana = 0.0
	_expect(not _wizard.try_cast(_wizard.global_position + Vector2.RIGHT * 40.0),
		"a cast without enough mana was accepted")
	_notes.append("out of range and out of mana casts are refused")


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
