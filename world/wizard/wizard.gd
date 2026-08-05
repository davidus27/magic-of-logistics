class_name Wizard
extends Node2D
## The wizard controller. Specification section 14.
##
## The wizard is not a unit. It stays at the centre of the cargo unit, has no
## health of its own, and never moves independently (section 14.1), so it is a
## controller with a position rather than a body. Cargo health represents cargo
## and wizard survival together.
##
## This node also draws the two range aids of sections 14.3 and 14.4. They belong
## with the cast rules that decide what is in range, not in the head-up display,
## which draws in screen space and would have to convert every frame.

signal mana_changed(mana: float, maximum: float)
signal spell_selected(index: int)
signal cooldowns_changed

## The wizard has 100 maximum mana and starts with 100. Section 14.2.
const MANA_MAX := 100.0
## Mana increases by 8 points each second. Section 14.2.
const MANA_REGEN := 8.0

## Size the spell symbol is drawn at when it becomes the mouse cursor.
const CURSOR_SIZE := 30

const SPELL_PATHS: PackedStringArray = [
	"res://data/spells/spell_arc_bolt.tres",
	"res://data/spells/spell_mend.tres",
	"res://data/spells/spell_ward.tres",
]
const SPELL_ICONS: PackedStringArray = [
	"res://assets/ui/icons/spell_arc_bolt.svg",
	"res://assets/ui/icons/spell_mend.svg",
	"res://assets/ui/icons/spell_ward.svg",
]
const SELECT_ACTIONS: PackedStringArray = ["spell_1", "spell_2", "spell_3"]

## Wired as NodePath rather than as node exports. See [NodeRef] for why.
@export var cargo_path: NodePath
@export var projectile_container_path: NodePath
@export var enemy_spawner_path: NodePath
## Mend heals the cargo unit or a defender, so the wizard reads the squad to find
## a target under the pointer. Section 14.6.
@export var squad_path: NodePath
## Ward is parented here rather than under the wizard, so it stays put where it
## was cast instead of riding the cargo. Section 14.7.
@export var effect_container_path: NodePath

@export var arc_bolt_scene: PackedScene
@export var ward_scene: PackedScene

var cargo: CargoUnit
var projectiles: Node2D
var enemies: EnemySpawner
var squad: Squad
var effects: Node2D

var mana: float = MANA_MAX
## Index into [constant SPELL_PATHS] of the active spell. The selected spell
## stays active until the player selects another. Section 14.3.
var selected_index: int = 0

var _spells: Array[SpellData] = []
var _cooldowns: PackedFloat32Array = PackedFloat32Array()
var _cursors: Array[Texture2D] = []
var _pointer := Vector2.ZERO
## Set for one frame after a rejected cast, to draw the aid of section 14.4.
var _reject_seconds: float = 0.0

## False outside the active run, so no range circle is drawn over a screen.
var active: bool = false:
	set(value):
		active = value
		visible = value
		_apply_cursor()
		queue_redraw()


func _ready() -> void:
	cargo = NodeRef.get_required(self, cargo_path, "cargo")
	projectiles = NodeRef.get_required(self, projectile_container_path, "projectile container")
	enemies = NodeRef.get_required(self, enemy_spawner_path, "enemy spawner")
	squad = NodeRef.get_required(self, squad_path, "squad")
	effects = NodeRef.get_required(self, effect_container_path, "effect container")

	for path in SPELL_PATHS:
		var spell: SpellData = load(path)
		if spell == null:
			push_error("Wizard could not load %s." % path)
			continue
		_spells.append(spell)
	for path in SPELL_ICONS:
		_cursors.append(_make_cursor(load(path)))

	_cooldowns.resize(_spells.size())
	_cooldowns.fill(0.0)
	active = false


## Reset for a new run.
func build() -> void:
	# A Ward from an earlier run does not carry into this one. Section 14.7.
	if Ward.active != null and is_instance_valid(Ward.active):
		Ward.active.dismiss()
	mana = MANA_MAX
	_cooldowns.fill(0.0)
	selected_index = _first_implemented()
	mana_changed.emit(mana, MANA_MAX)
	spell_selected.emit(selected_index)
	cooldowns_changed.emit()


func _process(delta: float) -> void:
	if cargo != null:
		# The wizard stays at the centre of the cargo unit. Section 14.1.
		global_position = cargo.global_position

	# Mana cannot increase above 100. Section 14.2.
	var before := mana
	mana = minf(MANA_MAX, mana + MANA_REGEN * delta)
	if not is_equal_approx(before, mana):
		mana_changed.emit(mana, MANA_MAX)

	var ticked := false
	for index in _cooldowns.size():
		if _cooldowns[index] > 0.0:
			_cooldowns[index] = maxf(0.0, _cooldowns[index] - delta)
			ticked = true
	if ticked:
		cooldowns_changed.emit()

	_reject_seconds = maxf(0.0, _reject_seconds - delta)
	_pointer = get_global_mouse_position()

	# The player can hold the left mouse button for repeated casts. Section 14.5.
	var spell := current_spell()
	if spell != null and spell.allow_hold_repeat \
			and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
			and _cooldowns[selected_index] <= 0.0:
		try_cast(_pointer)

	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	for index in SELECT_ACTIONS.size():
		if event.is_action_pressed(SELECT_ACTIONS[index]):
			select_spell(index)
			get_viewport().set_input_as_handled()
			return

	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
		return
	# The left mouse button always casts the selected spell. Section 22.
	try_cast(get_global_mouse_position())
	get_viewport().set_input_as_handled()


# --- Spells -------------------------------------------------------------------


func get_spells() -> Array[SpellData]:
	return _spells


func current_spell() -> SpellData:
	if selected_index < 0 or selected_index >= _spells.size():
		return null
	return _spells[selected_index]


func cooldown_left(index: int) -> float:
	if index < 0 or index >= _cooldowns.size():
		return 0.0
	return _cooldowns[index]


## Choose the active spell. Section 14.3.
func select_spell(index: int) -> void:
	if index < 0 or index >= _spells.size():
		return
	if not _spells[index].implemented:
		# Mend and Ward land with the milestone that adds them. Offering a cast
		# that silently does nothing would read as a broken control.
		return
	if index == selected_index:
		return
	selected_index = index
	_apply_cursor()
	spell_selected.emit(index)


## Cast the selected spell at a world point. Sections 14.4 and 14.5.
##
## Returns true when a spell was cast, false when it was rejected for cooldown,
## mana or range.
func try_cast(world_point: Vector2) -> bool:
	if not active:
		return false
	# The game does not cast a spell when the pointer is above the user
	# interface. Sections 14.4 and 22.
	if get_viewport().gui_get_hovered_control() != null:
		return false

	var spell := current_spell()
	if spell == null:
		return false

	if _cooldowns[selected_index] > 0.0 or mana < float(spell.mana_cost):
		_reject()
		return false
	# The game rejects a target outside the spell range. Section 14.4.
	if global_position.distance_to(world_point) > spell.cast_range:
		_reject()
		return false

	var cast := false
	match spell.kind:
		SpellData.Kind.PROJECTILE:
			cast = _cast_arc_bolt(spell, world_point)
		SpellData.Kind.HEAL:
			cast = _cast_mend(spell, world_point)
		SpellData.Kind.AREA:
			cast = _cast_ward(spell, world_point)
		_:
			# Only a spell marked implemented can be selected, so reaching this
			# means a spell resource was marked too early.
			push_error("Spell kind %d has no cast yet." % spell.kind)
			return false

	if not cast:
		# A cast that found nothing to act on, such as Mend with no target under
		# the pointer, spends no mana and starts no cooldown. Section 14.6.
		_reject()
		return false

	mana -= float(spell.mana_cost)
	_cooldowns[selected_index] = spell.cooldown
	# A spell cast uses one ink stroke sound. Section 31.
	SoundBank.play(SoundBank.SPELL_CAST)
	mana_changed.emit(mana, MANA_MAX)
	cooldowns_changed.emit()
	return true


## Arc Bolt creates one projectile from the wizard to the pointer position.
## Section 14.5.
func _cast_arc_bolt(spell: SpellData, world_point: Vector2) -> bool:
	if arc_bolt_scene == null:
		push_error("Wizard has no Arc Bolt scene assigned.")
		return false
	var bolt: ArcBolt = arc_bolt_scene.instantiate()
	projectiles.add_child(bolt)
	bolt.launch(spell, global_position, world_point)
	return true


## Mend restores health to the cargo unit or one defender under the pointer, and
## revives a downed defender. Returns false when nothing menable is in reach, so
## the cast costs nothing. Section 14.6.
func _cast_mend(spell: SpellData, world_point: Vector2) -> bool:
	var target := _mend_target(world_point, float(spell.target_pick_radius))
	if target == null:
		return false
	var cargo_target := target as CargoUnit
	if cargo_target != null:
		cargo_target.heal(spell.heal_cargo)
		return true
	var defender := target as Defender
	if defender == null:
		return false
	if defender.is_downed():
		# Mend can revive a downed defender, which receives 20 health. Section 14.6.
		defender.revive(spell.revive_health)
	else:
		defender.heal(spell.heal_defender)
	return true


## The nearest thing Mend can act on within [param radius] of the pointer: the
## cargo unit or a defender that is wounded, or a downed defender to revive.
## Section 14.6 selects the nearest valid target inside the pick radius.
func _mend_target(point: Vector2, radius: float) -> Node2D:
	var best: Node2D = null
	var best_distance := radius

	if cargo != null and cargo.health > 0 and cargo.health < cargo.data.max_health:
		var distance := CombatTarget.surface_distance(cargo, point)
		if distance <= best_distance:
			best_distance = distance
			best = cargo

	if squad != null:
		for defender in squad.get_defenders():
			# A downed defender is not alive but Mend can still reach it. A full
			# living defender is not worth a cast, so it is not a valid target.
			var mendable := defender.is_downed() \
				or (defender.is_alive() and defender.health < defender.max_health)
			if not mendable:
				continue
			var distance := CombatTarget.surface_distance(defender, point)
			if distance <= best_distance:
				best_distance = distance
				best = defender

	return best


## Ward drops a protection area at the pointer. Only one Ward is active at a
## time, so a new cast dismisses the old one. Section 14.7.
func _cast_ward(spell: SpellData, world_point: Vector2) -> bool:
	if ward_scene == null:
		push_error("Wizard has no Ward scene assigned.")
		return false
	if Ward.active != null and is_instance_valid(Ward.active):
		Ward.active.dismiss()
	var ward: Ward = ward_scene.instantiate()
	effects.add_child(ward)
	ward.setup(spell, world_point)
	return true


func _reject() -> void:
	_reject_seconds = 0.35


func _first_implemented() -> int:
	for index in _spells.size():
		if _spells[index].implemented:
			return index
	return 0


# --- Range aids ---------------------------------------------------------------


func _draw() -> void:
	var spell := current_spell()
	if not active or spell == null:
		return

	# The game shows the spell range around the cargo unit. Section 14.3.
	_draw_dashed_circle(spell.cast_range, InkPalette.GRAY_MEDIUM)

	# Ward is an area spell, so show where its protection would land at the
	# pointer, clamped to the edge of the cast range. Section 14.7.
	if spell.kind == SpellData.Kind.AREA:
		var aim := _clamp_to_range(_pointer, spell.cast_range)
		_draw_dashed_ring(to_local(aim), spell.effect_radius, InkPalette.GRAY_MEDIUM)

	# A short line shows the maximum permitted target point. Section 14.4.
	var offset := _pointer - global_position
	if offset.length() <= spell.cast_range or offset.length_squared() < 1.0:
		return
	var direction := offset.normalized()
	var edge := direction * spell.cast_range
	var colour := InkPalette.INK if _reject_seconds > 0.0 else InkPalette.GRAY_MEDIUM
	draw_line(edge - direction * 22.0, edge + direction * 22.0, colour, 2.0, true)


## An ink circle drawn as dashes, which reads as a guide rather than as a world
## object in the paper-and-ink style of section 10.
##
## The Arc Bolt range of 500 pixels is taller than the 720 pixel viewport, so
## only the left and right arcs are ever on screen. Long dashes in the medium
## grey are what makes those two arcs read as one boundary; the light line colour
## of the road edges disappears against the paper at this width.
func _draw_dashed_circle(radius: float, colour: Color) -> void:
	_draw_dashed_ring(Vector2.ZERO, radius, colour)


## A dashed circle centred on a local point, for a range aid that is not around
## the wizard, such as the Ward effect preview.
func _draw_dashed_ring(centre: Vector2, radius: float, colour: Color) -> void:
	const SEGMENTS := 48
	var step := TAU / float(SEGMENTS)
	for i in range(0, SEGMENTS, 2):
		var from := centre + Vector2.RIGHT.rotated(i * step) * radius
		var to := centre + Vector2.RIGHT.rotated((i + 1) * step) * radius
		draw_line(from, to, colour, 2.0, true)


## A world point pulled in to the edge of a radius around the wizard when it lies
## beyond it, so the Ward preview never floats outside the cast range.
func _clamp_to_range(point: Vector2, radius: float) -> Vector2:
	var offset := point - global_position
	if offset.length() <= radius:
		return point
	return global_position + offset.normalized() * radius


func _apply_cursor() -> void:
	if not active:
		Input.set_custom_mouse_cursor(null)
		return
	if selected_index < 0 or selected_index >= _cursors.size():
		return
	# The cursor shows the selected spell symbol. Section 14.3.
	Input.set_custom_mouse_cursor(
		_cursors[selected_index], Input.CURSOR_ARROW, Vector2.ONE * (CURSOR_SIZE * 0.5)
	)


## The spell icons are drawn on the pack's 96 pixel canvas, which is far too
## large for a pointer. Resizing once at load beats importing a second copy of
## the same drawing at a different scale.
func _make_cursor(source: Texture2D) -> Texture2D:
	if source == null:
		return null
	var image := source.get_image()
	if image == null:
		return null
	image.resize(CURSOR_SIZE, CURSOR_SIZE, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)
