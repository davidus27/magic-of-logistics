extends Control
## Head-up display. Specification section 30.
##
## Milestone one fills the regions that have data: cargo health, speed and terrain
## in the top left, and distance, threat and the run timer in the top centre. The
## three bottom regions exist as empty containers so that defender portraits,
## order controls and spell controls drop into place later without moving the
## layout that testers have already learned.

## Wired as NodePath rather than as node exports. See [NodeRef] for why.
@export var controller_path: NodePath
@export var cargo_path: NodePath
@export var map_path: NodePath

var controller: GameController
var cargo: CargoUnit
var map: Map

## The terrain label stays visible for one second. Section 12.4.
const TERRAIN_LABEL_SECONDS := 1.0

var _health: Label = null
var _speed: Label = null
var _terrain: Label = null
var _distance: Label = null
var _threat: Label = null
var _timer: Label = null
var _terrain_flash: Label = null
var _terrain_flash_left: float = 0.0

## Reserved for later milestones. Section 30.3, 30.4 and 30.5.
var portrait_area: HBoxContainer = null
var order_area: HBoxContainer = null
var spell_area: HBoxContainer = null


func _ready() -> void:
	InkUi.fill_parent(self)
	# The interface consumes pointer input above its controls, and nowhere else.
	# Section 22 and section 14.4 both depend on this.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	controller = NodeRef.get_required(self, controller_path, "controller")
	cargo = NodeRef.get_required(self, cargo_path, "cargo")
	map = NodeRef.get_required(self, map_path, "map")

	_build()
	if cargo != null:
		cargo.health_changed.connect(_on_health_changed)
		cargo.terrain_changed.connect(_on_terrain_changed)
		_on_health_changed(cargo.health, cargo.data.max_health)


func _build() -> void:
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

	# Reserved for later milestones. Sections 30.3, 30.4 and 30.5.
	portrait_area = _reserved_area(Vector2(0.0, 1.0), Rect2(18.0, -112.0, 540.0, 96.0))
	order_area = _reserved_area(Vector2(0.5, 1.0), Rect2(-190.0, -82.0, 380.0, 66.0))
	spell_area = _reserved_area(Vector2(1.0, 1.0), Rect2(-334.0, -94.0, 316.0, 78.0))


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


func _reserved_area(anchor: Vector2, rect: Rect2) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	_place(box, anchor, rect)
	return box


func _process(delta: float) -> void:
	if _terrain_flash_left > 0.0:
		_terrain_flash_left -= delta
		if _terrain_flash_left <= 0.0:
			_terrain_flash.visible = false

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


func _on_health_changed(health: int, maximum: int) -> void:
	_health.text = "Cargo %d / %d" % [health, maximum]


func _on_terrain_changed(display_name: String, factor: float) -> void:
	_terrain_flash.text = "%s   x%.2f" % [display_name, factor]
	_terrain_flash.visible = true
	_terrain_flash_left = TERRAIN_LABEL_SECONDS
