extends Control
## Developer readout. Not part of the specification.
##
## Toggled with F9. F1 to F4 select defenders and F3 is one of them, so the
## overlay cannot use the usual F3.

## Wired as NodePath rather than as node exports. See [NodeRef] for why.
@export var controller_path: NodePath
@export var cargo_path: NodePath
@export var map_path: NodePath
@export var camera_path: NodePath

@export var start_visible: bool = false

var controller: GameController
var cargo: CargoUnit
var map: Map
var camera: CameraRig

var _text: Label = null


func _ready() -> void:
	InkUi.fill_parent(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = start_visible

	controller = NodeRef.get_required(self, controller_path, "controller")
	cargo = NodeRef.get_required(self, cargo_path, "cargo")
	map = NodeRef.get_required(self, map_path, "map")
	camera = NodeRef.get_required(self, camera_path, "camera")

	var panel := InkUi.panel()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	# Pinned to the top right corner at a fixed size, so it follows a resize.
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -292.0
	panel.offset_right = -12.0
	panel.offset_top = 12.0
	panel.offset_bottom = 300.0

	_text = InkUi.label("", InkUi.FONT_SIZE_SMALL)
	panel.add_child(_text)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		visible = not visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not visible or controller == null or cargo == null or map == null:
		return
	_text.text = "\n".join([
		"fps            %d" % Engine.get_frames_per_second(),
		"state          %s" % controller.state_name(),
		"profile        %s" % (RunContext.profile.id if RunContext.profile else "-"),
		"seed           %d" % (RunContext.seed_data.seed_value if RunContext.seed_data else 0),
		"route length   %.0f" % map.route_length,
		"route offset   %.0f" % cargo.get_route_offset(),
		"sample hint    %d" % cargo.route_hint,
		"off centre     %.0f" % map.distance_from_centerline(cargo.global_position, cargo.route_hint),
		"terrain        %s x%.2f" % [cargo.terrain_key, cargo.terrain_factor],
		"speed          %.1f" % cargo.get_current_speed(),
		"distance       %.0f" % cargo.distance_travelled,
		"zoom           %.2f" % (camera.zoom.x if camera else 0.0),
		"threat         %d" % int(controller.threat),
	])
