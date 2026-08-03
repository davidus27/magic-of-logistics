extends Control
## Head-up display. Specification section 30.
##
## Five regions, each fixed to a corner or an edge so that the layout a tester
## learns in one control profile is the layout in the next: cargo state top left,
## run state top centre, defender portraits bottom left, defender orders bottom
## centre, spells bottom right.
##
## The root ignores pointer input and only the controls inside it accept a click.
## Sections 14.4 and 22 both depend on that: the interface consumes pointer input
## above its controls and nowhere else, so a click on empty screen still casts.

const States := preload("res://world/defenders/defender_states.gd")

## The terrain label stays visible for one second. Section 12.4.
const TERRAIN_LABEL_SECONDS := 1.0
## How long a passing note stays on screen, such as an unavailable spell.
const NOTICE_SECONDS := 2.0

## Wired as NodePath rather than as node exports. See [NodeRef] for why.
@export var controller_path: NodePath
@export var cargo_path: NodePath
@export var map_path: NodePath
@export var squad_path: NodePath
@export var wizard_path: NodePath

var controller: GameController
var cargo: CargoUnit
var map: Map
var squad: Squad
var wizard: Wizard

var _health: Label = null
var _speed: Label = null
var _terrain: Label = null
var _distance: Label = null
var _threat: Label = null
var _timer: Label = null
var _terrain_flash: Label = null
var _terrain_flash_left: float = 0.0
var _notice: Label = null
var _notice_left: float = 0.0

var _portraits: Array[DefenderPortrait] = []
var _order_buttons: Array[Button] = []
var _spell_buttons: Array[SpellButton] = []
var _mana_bar: ManaBar = null


func _ready() -> void:
	InkUi.fill_parent(self)
	# The interface consumes pointer input above its controls, and nowhere else.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	controller = NodeRef.get_required(self, controller_path, "controller")
	cargo = NodeRef.get_required(self, cargo_path, "cargo")
	map = NodeRef.get_required(self, map_path, "map")
	squad = NodeRef.get_required(self, squad_path, "squad")
	wizard = NodeRef.get_required(self, wizard_path, "wizard")

	_build()

	if cargo != null:
		cargo.health_changed.connect(_on_health_changed)
		cargo.terrain_changed.connect(_on_terrain_changed)
		_on_health_changed(cargo.health, cargo.data.max_health)
	if squad != null:
		squad.roster_changed.connect(_on_roster_changed)
	if wizard != null:
		wizard.mana_changed.connect(_on_mana_changed)


func _build() -> void:
	_build_run_state()
	_build_portraits()
	_build_orders()
	_build_spells()


# --- Regions ------------------------------------------------------------------


func _build_run_state() -> void:
	# Top left. Section 30.1.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	_place(left, Vector2.ZERO, Rect2(18.0, 14.0, 340.0, 108.0))
	_health = InkUi.label("Cargo 100 / 100", InkUi.FONT_SIZE_HEADING)
	_speed = InkUi.label("Stop", InkUi.FONT_SIZE_BODY)
	_terrain = InkUi.label("Road  x1.00", InkUi.FONT_SIZE_SMALL, InkPalette.GRAY_MEDIUM)
	left.add_child(_health)
	left.add_child(_speed)
	left.add_child(_terrain)

	# Top centre. Section 30.2.
	var centre := VBoxContainer.new()
	centre.add_theme_constant_override("separation", 2)
	_place(centre, Vector2(0.5, 0.0), Rect2(-160.0, 14.0, 320.0, 108.0))
	_distance = InkUi.label("Portal 9000", InkUi.FONT_SIZE_HEADING)
	_timer = InkUi.label("0:00", InkUi.FONT_SIZE_BODY)
	_threat = InkUi.label("Threat 0", InkUi.FONT_SIZE_SMALL, InkPalette.GRAY_MEDIUM)
	for node in [_distance, _timer, _threat]:
		node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		centre.add_child(node)

	# Terrain change notice. Section 12.4.
	_terrain_flash = InkUi.label("", InkUi.FONT_SIZE_HEADING)
	_terrain_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_terrain_flash.visible = false
	_place(_terrain_flash, Vector2(0.5, 0.5), Rect2(-180.0, 118.0, 360.0, 34.0))

	_notice = InkUi.label("", InkUi.FONT_SIZE_BODY, InkPalette.GRAY_MEDIUM)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.visible = false
	_place(_notice, Vector2(0.5, 1.0), Rect2(-260.0, -146.0, 520.0, 26.0))


## Bottom left: four defender portraits. Section 30.3.
##
## The three bottom regions share one row and must not touch, so their widths
## are fixed rather than fitted: four portraits and three gaps reach x 462, the
## order controls are centred from 482 to 798, and the spell controls end at the
## right margin from 946. The window scales the whole 1280 pixel canvas, so those
## numbers hold at every window size.
func _build_portraits() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	_place(row, Vector2(0.0, 1.0), Rect2(12.0, -92.0, 450.0, 74.0))

	for index in Squad.ROSTER.size():
		var portrait := DefenderPortrait.new(index)
		portrait.portrait_pressed.connect(_on_portrait_pressed)
		row.add_child(portrait)
		_portraits.append(portrait)


## Bottom centre: the defender order controls. Section 30.4.
func _build_orders() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	_place(row, Vector2(0.5, 1.0), Rect2(-158.0, -76.0, 316.0, 58.0))

	# The control labels change for the active defender method. Section 30.4.
	for entry in _order_entries():
		var button := InkUi.button(entry[0], InkUi.FONT_SIZE_SMALL)
		button.custom_minimum_size = Vector2(100.0, 50.0)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_on_order_pressed.bind(entry[1]))
		row.add_child(button)
		_order_buttons.append(button)


## The three order controls for the active defender control method.
## Sections 17, 18 and 30.4.
func _order_entries() -> Array:
	RunContext.ensure_configured()
	if RunContext.profile.defender_mode == ControlProfileData.DefenderMode.DIRECT_TARGET:
		# Section 18. The Attack Target order is a right-click on an enemy, so
		# its control is a reminder rather than a button that can issue it.
		return [
			["Attack target\nright click", States.ATTACK],
			["Defend cargo\nX", States.DEFEND],
			["Repair cargo\nC", States.REPAIR],
		]
	# Section 17.
	return [
		["Attack\nZ", States.ATTACK],
		["Defend\nX", States.DEFEND],
		["Repair\nC", States.REPAIR],
	]


## Bottom right: three spell controls with a mana bar above them. Section 30.5.
func _build_spells() -> void:
	_mana_bar = ManaBar.new()
	_place(_mana_bar, Vector2(1.0, 1.0), Rect2(-334.0, -94.0, 316.0, 12.0))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	_place(row, Vector2(1.0, 1.0), Rect2(-334.0, -76.0, 316.0, 62.0))

	if wizard == null:
		return
	var spells := wizard.get_spells()
	var costs := PackedInt32Array()
	for index in spells.size():
		var button := SpellButton.new(index, spells[index])
		button.spell_pressed.connect(_on_spell_pressed)
		row.add_child(button)
		_spell_buttons.append(button)
		if spells[index].implemented:
			costs.append(spells[index].mana_cost)
	_mana_bar.set_costs(costs)


# --- Updates ------------------------------------------------------------------


func _process(delta: float) -> void:
	if _terrain_flash_left > 0.0:
		_terrain_flash_left -= delta
		if _terrain_flash_left <= 0.0:
			_terrain_flash.visible = false
	if _notice_left > 0.0:
		_notice_left -= delta
		if _notice_left <= 0.0:
			_notice.visible = false

	if cargo == null or controller == null or map == null:
		return

	var data := cargo.data
	_speed.text = "%s   %.0f px/s" % [
		data.name_for_level(cargo.get_speed_level()), cargo.get_current_speed(),
	]
	_terrain.text = "%s  x%.2f" % [cargo.terrain_name, cargo.terrain_factor]
	_distance.text = "Portal %.0f" % map.distance_to_portal(cargo.global_position, cargo.route_hint)
	_threat.text = "Threat %d" % int(controller.threat)

	var seconds := int(controller.run_seconds)
	_timer.text = "%d:%02d" % [seconds / 60.0, seconds % 60]

	for portrait in _portraits:
		portrait.refresh()

	if wizard != null:
		for button in _spell_buttons:
			button.refresh(
				button.index == wizard.selected_index,
				wizard.cooldown_left(button.index),
				wizard.mana
			)


func _on_roster_changed() -> void:
	var defenders := squad.get_defenders()
	for index in _portraits.size():
		if index < defenders.size():
			_portraits[index].bind(defenders[index])


func _on_health_changed(health: int, maximum: int) -> void:
	_health.text = "Cargo %d / %d" % [health, maximum]


func _on_terrain_changed(display_name: String, factor: float) -> void:
	_terrain_flash.text = "%s   x%.2f" % [display_name, factor]
	_terrain_flash.visible = true
	_terrain_flash_left = TERRAIN_LABEL_SECONDS


func _on_mana_changed(mana: float, maximum: float) -> void:
	if _mana_bar != null:
		_mana_bar.set_mana(mana, maximum)


func _on_portrait_pressed(index: int) -> void:
	# The player can also click a defender portrait. Section 16.
	if Input.is_key_pressed(KEY_SHIFT):
		squad.toggle_selection(index)
	else:
		squad.select_only(index)


func _on_order_pressed(state_id: StringName) -> void:
	squad.order(state_id)


func _on_spell_pressed(index: int) -> void:
	var spells := wizard.get_spells()
	if index < spells.size() and not spells[index].implemented:
		show_notice("%s is not in this build." % spells[index].display_name)
		return
	wizard.select_spell(index)


## Show a short message under the order controls.
func show_notice(text: String) -> void:
	_notice.text = text
	_notice.visible = true
	_notice_left = NOTICE_SECONDS


# --- Layout -------------------------------------------------------------------


## Anchor a control to one point of the screen and give it a fixed rectangle.
##
## [param anchor] is the same fraction for both corners, so the rectangle keeps
## its size and follows that point as the window resizes. [param rect] is measured
## from the anchor, so negative values run back from the right or bottom edge.
func _place(node: Control, anchor: Vector2, rect: Rect2) -> void:
	add_child(node)
	node.anchor_left = anchor.x
	node.anchor_right = anchor.x
	node.anchor_top = anchor.y
	node.anchor_bottom = anchor.y
	node.offset_left = rect.position.x
	node.offset_top = rect.position.y
	node.offset_right = rect.position.x + rect.size.x
	node.offset_bottom = rect.position.y + rect.size.y
