class_name InkSprite
extends Sprite2D
## A sprite that alternates between hand-drawn line frames. Specification 10.3.
##
## This is the only implementation of the line effect. Because it changes nothing
## except [member Sprite2D.texture], it can never change a collision shape, which
## section 10.3 requires.

## Line frames, in order. One frame is valid and disables the effect.
@export var frames: Array[Texture2D] = []

## The factor the art was rasterised at, from svg/scale in the .import file. The
## sprite is scaled down by this so a drawing authored at world size occupies its
## world size on screen.
@export var supersample: float = 2.0

## Extra scale on top of the supersample correction.
##
## Needed because the assets in assets/ are drawn on a common 256 pixel canvas
## rather than at world size, so each one needs its own factor to reach the size
## its object occupies.
@export var extra_scale: float = 1.0

## Colour multiplied over the art.
##
## Leave this white for art already drawn in its final ink colours, which is how
## the assets/ pack is authored. Set it to an [InkPalette] colour only for art
## drawn in white. Note that modulate multiplies, so it can darken art but never
## lighten it: tinting only works on white source art.
@export var ink_color: Color = Color.WHITE:
	set(value):
		ink_color = value
		self_modulate = value


func _ready() -> void:
	_apply_scale()
	self_modulate = ink_color
	# Mipmaps keep the lines clean across the 0.85 to 1.20 zoom range of section 9.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	if frames.is_empty():
		if texture == null:
			push_warning("InkSprite %s has no frames." % get_path())
			return
		frames.append(texture)

	_show_frame(InkClock.frame)
	if frames.size() > 1:
		InkClock.frame_changed.connect(_show_frame)


## Recolour the sprite, for the damage flash of section 13.2 and the dead paper
## mark of sections 15.11 and 29. Only affects art drawn in white.
func set_ink(color: Color) -> void:
	ink_color = color


func _apply_scale() -> void:
	var factor := extra_scale
	if supersample > 0.0:
		factor /= supersample
	scale = Vector2.ONE * factor


func _show_frame(index: int) -> void:
	texture = frames[index % frames.size()]
