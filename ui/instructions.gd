extends Control
## Instruction screen and pause screen. Specification sections 8.2 and 8.4.
##
## Both states show the same control list, so one screen serves both. Section 38
## says to explain only the input controls and the objective, and never the hidden
## artificial intelligence rules, so this screen lists keys and the goal only.

var _title: Label = null
var _hint: Label = null
var _controls: VBoxContainer = null


func _ready() -> void:
	_build()


func _build() -> void:
	var column := InkUi.build_overlay(self, 700.0, true)

	_title = InkUi.label("Controls", InkUi.FONT_SIZE_TITLE)
	column.add_child(_title)

	column.add_child(InkUi.label(
		"Bring the cargo to the portal at the end of the road. Keep its health above zero.",
		InkUi.FONT_SIZE_BODY,
		InkPalette.GRAY_MEDIUM
	))
	column.add_child(InkUi.rule())

	_controls = VBoxContainer.new()
	_controls.add_theme_constant_override("separation", 6)
	column.add_child(_controls)

	column.add_child(InkUi.rule())
	_hint = InkUi.label("Press Enter to start.", InkUi.FONT_SIZE_HEADING)
	column.add_child(_hint)


func show_as_briefing() -> void:
	_title.text = "Controls"
	_hint.text = "Press Enter to start."
	_rebuild_controls()


func show_as_pause() -> void:
	_title.text = "Paused"
	_hint.text = "Press Escape or Enter to continue."
	_rebuild_controls()


func _rebuild_controls() -> void:
	for child in _controls.get_children():
		child.queue_free()
		_controls.remove_child(child)

	_add_group("Cargo", [
		# Section 19.
		["W", "Faster: Stop, Slow, Normal, Fast"],
		["S", "Slower"],
		["Space", "Stop at once"],
	])
	_add_group("Wizard", [
		["1  2  3", "Choose a spell"],
		["Left mouse", "Cast the chosen spell"],
	])
	_add_group("Defenders", [
		["F1 to F4", "Select one defender"],
		["Q", "Select all defenders"],
		["Shift + F key", "Add to the selection"],
		# Section 17.
		["Z", "Attack"],
		["X", "Defend the cargo"],
		["C", "Repair"],
	])
	_add_group("View", [
		["Mouse wheel", "Zoom"],
		["Escape", "Pause"],
	])


func _add_group(heading: String, rows: Array) -> void:
	_controls.add_child(InkUi.label(heading, InkUi.FONT_SIZE_HEADING))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 3)
	_controls.add_child(grid)
	for row in rows:
		var key := InkUi.label(row[0], InkUi.FONT_SIZE_BODY)
		key.custom_minimum_size = Vector2(220.0, 0.0)
		grid.add_child(key)
		grid.add_child(InkUi.label(row[1], InkUi.FONT_SIZE_BODY, InkPalette.GRAY_MEDIUM))
