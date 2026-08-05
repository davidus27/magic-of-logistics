class_name SpellButton
extends Control
## One spell control in the bottom-right area. Specification section 30.5.
##
## Each control shows the mana cost and the cooldown. The cooldown is a shade
## that empties downward rather than a number: the player is reading it during a
## fight, and a shrinking block can be read without focusing on it.
##
## A spell the build does not have yet is drawn as unavailable. Section 14.3 says
## the number keys select a spell, and a control that looks live but rejects
## every cast is worse than one that says so.

signal spell_pressed(index: int)

const SIZE := Vector2(100.0, 66.0)
const PADDING := 6.0

var index: int = 0
var spell: SpellData = null

var _name: Label = null
var _cost: Label = null
var _cooldown_ratio: float = 0.0
var _selected: bool = false
var _affordable: bool = true


func _init(spell_index: int, spell_data: SpellData) -> void:
	index = spell_index
	spell = spell_data
	custom_minimum_size = SIZE
	# A user interface click cannot cast a spell. Section 22.
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	var available := spell.implemented
	_name = InkUi.label(
		"%d  %s" % [spell.hotkey_index, spell.display_name],
		InkUi.FONT_SIZE_BODY,
		InkPalette.INK if available else InkPalette.LINE_LIGHT
	)
	_name.position = Vector2(PADDING, 5.0)
	add_child(_name)

	var cost_text := "%d mana" % spell.mana_cost
	if not available:
		cost_text = "not in this build"
	_cost = InkUi.label(cost_text, InkUi.FONT_SIZE_SMALL, InkPalette.GRAY_MEDIUM)
	_cost.position = Vector2(PADDING, 26.0)
	add_child(_cost)


func refresh(selected: bool, cooldown_left: float, mana: float) -> void:
	var ratio := 0.0
	if spell.cooldown > 0.0:
		ratio = clampf(cooldown_left / spell.cooldown, 0.0, 1.0)
	var affordable := mana >= float(spell.mana_cost)

	if is_equal_approx(ratio, _cooldown_ratio) and selected == _selected \
			and affordable == _affordable:
		return
	_cooldown_ratio = ratio
	_selected = selected
	_affordable = affordable
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
		return
	spell_pressed.emit(index)
	accept_event()


func _draw() -> void:
	var frame := Rect2(Vector2.ZERO, size)
	draw_rect(frame, Color(InkPalette.PAPER, 0.75), true)

	# The cooldown shade fills from the bottom and empties as the spell returns.
	if _cooldown_ratio > 0.0:
		var height := size.y * _cooldown_ratio
		draw_rect(
			Rect2(0.0, size.y - height, size.x, height), Color(InkPalette.INK, 0.14), true
		)

	var border := InkPalette.LINE_LIGHT
	if not spell.implemented:
		border = Color(InkPalette.LINE_LIGHT, 0.5)
	elif _selected:
		border = InkPalette.INK
	elif not _affordable:
		border = InkPalette.GRAY_MEDIUM
	draw_rect(frame, border, false, 2.0)
	if _selected:
		draw_rect(frame.grow(-4.0), InkPalette.INK, false, 1.0)
