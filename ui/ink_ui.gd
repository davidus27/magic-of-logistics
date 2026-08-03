class_name InkUi
extends RefCounted
## Builders for the paper-and-ink user interface. Specification section 10.
##
## The MVP screens are built in code rather than authored as scenes. The style is
## uniform enough that one builder keeps every screen consistent, and the test
## screens are expected to change often while the control profiles are compared.
## The full section 30 interface arrives with the test instrumentation milestone.

const FONT_SIZE_TITLE := 32
const FONT_SIZE_HEADING := 21
const FONT_SIZE_BODY := 16
const FONT_SIZE_SMALL := 13

const PANEL_PADDING := 22.0
const BORDER_WIDTH := 2.0


static func label(
	text: String,
	font_size: int = FONT_SIZE_BODY,
	color: Color = InkPalette.INK
) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	return node


## A button that never takes keyboard focus.
##
## This matters for more than tidiness. A focused Button consumes Enter and Space,
## and those are the run start key of section 8.2 and the full brake of section
## 19. A focused button would quietly steal them.
static func button(text: String, font_size: int = FONT_SIZE_BODY) -> Button:
	var node := Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", InkPalette.INK)
	node.add_theme_color_override("font_hover_color", InkPalette.INK)
	node.add_theme_color_override("font_pressed_color", InkPalette.GRAY_MEDIUM)
	node.add_theme_color_override("font_disabled_color", InkPalette.LINE_LIGHT)
	node.add_theme_stylebox_override("normal", box(InkPalette.LINE_LIGHT))
	node.add_theme_stylebox_override("hover", box(InkPalette.INK))
	node.add_theme_stylebox_override("pressed", box(InkPalette.INK, 0.10))
	node.add_theme_stylebox_override("disabled", box(InkPalette.LINE_LIGHT, 0.0, 1.0))
	node.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return node


## An ink outline on paper, optionally with a light fill.
static func box(
	border: Color,
	fill_alpha: float = 0.0,
	border_width: float = BORDER_WIDTH
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(InkPalette.INK, fill_alpha)
	style.border_color = border
	style.set_border_width_all(int(border_width))
	style.set_content_margin_all(10.0)
	style.corner_detail = 1
	return style


## A panel of paper with an ink border, used for every full screen overlay.
static func panel() -> PanelContainer:
	var node := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = InkPalette.PAPER
	style.border_color = InkPalette.INK
	style.set_border_width_all(int(BORDER_WIDTH))
	style.set_content_margin_all(PANEL_PADDING)
	node.add_theme_stylebox_override("panel", style)
	return node


## A thin ink rule used to separate blocks of text.
static func rule() -> Panel:
	var node := Panel.new()
	node.custom_minimum_size = Vector2(0.0, 1.0)
	var style := StyleBoxFlat.new()
	style.bg_color = InkPalette.LINE_LIGHT
	node.add_theme_stylebox_override("panel", style)
	return node


## A full screen dim over the world, so an overlay screen stays readable.
static func screen_veil() -> ColorRect:
	var node := ColorRect.new()
	node.color = Color(InkPalette.PAPER, 0.85)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill_parent(node)
	return node


## Make a control fill its parent.
##
## Use this and never [method Control.set_anchors_preset] on its own. That method
## sets the anchors and then adjusts the offsets so the rectangle does not move,
## and a freshly created control has a zero sized rectangle, so it stays zero
## sized. It is worse than it looks for a screen whose parent is a CanvasLayer
## rather than another Control: a plain Control does not clip, so the contents
## still draw and appear to work while every anchor inside collapses onto the
## origin, but a ScrollContainer does clip and shows nothing at all.
static func fill_parent(node: Control) -> void:
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Build the standard full screen overlay on [param host]: a veil over the world
## and a column of fixed width centred at any window size. Returns the column.
static func build_overlay(
	host: Control,
	max_width: float = 720.0,
	scrollable: bool = false
) -> VBoxContainer:
	fill_parent(host)
	host.add_child(screen_veil())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 26)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)

	if scrollable:
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		fill_parent(scroll)
		host.add_child(scroll)
		margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(margin)
	else:
		fill_parent(margin)
		host.add_child(margin)

	# Two expanding spacers either side keep the column centred whatever the
	# window width, which a size flag alone cannot do inside a MarginContainer.
	var row := HBoxContainer.new()
	margin.add_child(row)
	row.add_child(spacer())

	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(max_width, 0.0)
	column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	column.add_theme_constant_override("separation", 8)
	row.add_child(column)

	row.add_child(spacer())
	return column


## An invisible control that soaks up leftover space in a box container.
static func spacer() -> Control:
	var node := Control.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node
