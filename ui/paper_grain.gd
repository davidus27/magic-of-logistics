extends TextureRect
## Static paper grain over the whole screen. Specification section 10.2.
##
## The grain sits on a CanvasLayer, so it is in screen space and does not move
## with the world, which is what "static" means in section 10.2. It is a tiled
## texture and not a shader, as that section also requires.

## Tiled grain from the asset pack.
@export var grain_texture: Texture2D


func _ready() -> void:
	if grain_texture == null:
		push_warning("PaperGrain has no texture. The paper effect is missing.")
		return
	texture = grain_texture
	stretch_mode = TextureRect.STRETCH_TILE
	# The pack ships the grain with the 8 percent opacity of section 10.2 already
	# in its alpha channel, so it is drawn at full opacity. Modulating by 8
	# percent again would take it far below one percent and make it invisible.
	modulate = Color.WHITE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	InkUi.fill_parent(self)
