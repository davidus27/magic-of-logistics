class_name UnitHealthBar
extends Node2D
## A health bar above a unit. Specification section 30.6.
##
## Health bars appear only after damage, so this starts hidden and shows itself
## the first time a ratio below one arrives. It is drawn rather than built from
## the bar art in the asset pack: the pack draws its bar on the common 256 pixel
## canvas, and scaling that down to 26 pixels would leave a one pixel outline
## that the 0.85 to 1.20 zoom of section 9 turns into a flicker.

const WIDTH := 26.0
const HEIGHT := 4.0
## Distance above the unit centre.
const RISE := -22.0

var _ratio: float = 1.0


func _ready() -> void:
	position = Vector2(0.0, RISE)
	visible = false


## Show the bar at a fraction of full health.
func show_ratio(ratio: float) -> void:
	_ratio = clampf(ratio, 0.0, 1.0)
	visible = true
	queue_redraw()


func hide_bar() -> void:
	visible = false


func _draw() -> void:
	var frame := Rect2(-WIDTH * 0.5, -HEIGHT * 0.5, WIDTH, HEIGHT)
	draw_rect(frame, InkPalette.PAPER, true)
	draw_rect(Rect2(frame.position, Vector2(WIDTH * _ratio, HEIGHT)), InkPalette.INK, true)
	draw_rect(frame, InkPalette.GRAY_MEDIUM, false, 1.0)
