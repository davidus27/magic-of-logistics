class_name ManaBar
extends Control
## The mana bar above the spell controls. Specification section 30.5.
##
## Ticks at each spell cost, so the player can see at a glance which spell the
## current mana affords without reading three numbers. Section 14.2 refills 8
## points each second, which is slow enough that the next affordable cast is a
## real decision.

const HEIGHT := 10.0

var _ratio: float = 1.0
var _mana: float = 100.0
var _costs: PackedInt32Array = PackedInt32Array()
var _maximum: float = 100.0


func _init() -> void:
	custom_minimum_size = Vector2(0.0, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Mark the mana each spell costs. Section 30.5.
func set_costs(costs: PackedInt32Array) -> void:
	_costs = costs
	queue_redraw()


func set_mana(mana: float, maximum: float) -> void:
	_maximum = maxf(1.0, maximum)
	var ratio := clampf(mana / _maximum, 0.0, 1.0)
	# A pixel of a 316 pixel bar is a third of one mana point, so redrawing on
	# every regeneration frame would draw the same picture sixty times a second.
	if absf(ratio - _ratio) < 0.003:
		return
	_mana = mana
	_ratio = ratio
	queue_redraw()


func _draw() -> void:
	var frame := Rect2(0.0, 0.0, size.x, HEIGHT)
	draw_rect(frame, InkPalette.PAPER, true)
	draw_rect(Rect2(frame.position, Vector2(size.x * _ratio, HEIGHT)), InkPalette.INK, true)
	draw_rect(frame, InkPalette.GRAY_MEDIUM, false, 1.0)

	for cost in _costs:
		var x := size.x * (float(cost) / _maximum)
		draw_line(Vector2(x, 0.0), Vector2(x, HEIGHT), InkPalette.GRAY_MEDIUM, 1.0)
