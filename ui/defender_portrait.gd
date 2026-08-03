class_name DefenderPortrait
extends Control
## One defender portrait in the bottom-left area. Specification sections 30.3
## and 10.5.
##
## Each portrait shows health, state and selection, and a downed portrait shows
## the remaining downed time. A click selects the defender, which section 16
## allows and a world click does not, because the left mouse button belongs to
## the wizard.
##
## The border and the bar are drawn rather than assembled from the portrait art
## in the pack. A portrait has to show a live health fraction and a selection
## state, and drawing both keeps them in the same coordinate space as the frame
## around them.

signal portrait_pressed(index: int)

const SIZE := Vector2(126.0, 78.0)
const BAR_HEIGHT := 5.0
const PADDING := 8.0

var index: int = 0
var defender: Defender = null

var _name: Label = null
var _state: Label = null
var _ratio: float = 1.0
var _selected: bool = false
var _alive: bool = true


func _init(slot_index: int) -> void:
	index = slot_index
	custom_minimum_size = SIZE
	# Section 16: a click on a portrait selects, and must not cast a spell.
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	_name = InkUi.label("-", InkUi.FONT_SIZE_BODY)
	_name.position = Vector2(PADDING, 5.0)
	_name.size = Vector2(SIZE.x - PADDING * 2.0, 22.0)
	add_child(_name)

	_state = InkUi.label("", InkUi.FONT_SIZE_SMALL, InkPalette.GRAY_MEDIUM)
	_state.position = Vector2(PADDING, 27.0)
	_state.size = Vector2(SIZE.x - PADDING * 2.0, 18.0)
	add_child(_state)


func bind(unit: Defender) -> void:
	defender = unit
	if defender != null:
		_name.text = "%s  %s" % [_hotkey(), defender.data.display_name]
	queue_redraw()


func refresh() -> void:
	if defender == null:
		return
	var ratio := float(defender.health) / float(maxi(1, defender.max_health))
	var alive := defender.is_alive()
	var label := defender.state_label()
	# A downed portrait shows the remaining downed time. Section 30.3.
	if defender.is_downed():
		label = "Downed  %0.0fs" % ceilf(defender.downed_left)

	if is_equal_approx(ratio, _ratio) and alive == _alive \
			and _selected == defender.selected and _state.text == label:
		return

	_ratio = ratio
	_alive = alive
	_selected = defender.selected
	_state.text = label
	_name.add_theme_color_override(
		"font_color", InkPalette.INK if alive else InkPalette.LINE_LIGHT
	)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
		return
	portrait_pressed.emit(index)
	accept_event()


func _draw() -> void:
	var frame := Rect2(Vector2.ZERO, size)
	draw_rect(frame, Color(InkPalette.PAPER, 0.75), true)
	draw_rect(frame, InkPalette.LINE_LIGHT if not _selected else InkPalette.INK, false, 2.0)
	# A selected defender portrait has a double border. Section 10.5.
	if _selected:
		draw_rect(frame.grow(-4.0), InkPalette.INK, false, 1.0)

	var bar := Rect2(
		PADDING, size.y - BAR_HEIGHT - PADDING, size.x - PADDING * 2.0, BAR_HEIGHT
	)
	draw_rect(bar, InkPalette.PAPER, true)
	var fill := Rect2(bar.position, Vector2(bar.size.x * _ratio, bar.size.y))
	draw_rect(fill, InkPalette.INK if _alive else InkPalette.LINE_LIGHT, true)
	draw_rect(bar, InkPalette.GRAY_MEDIUM, false, 1.0)


func _hotkey() -> String:
	return "F%d" % (index + 1)
