class_name TerrainZone
extends Area2D
## A ground area with its own speed factors. Specification section 12.
##
## The zone is passive. It is detectable but detects nothing itself: each unit
## carries a small sensor that finds the zones it stands in and reads the factor
## that applies to it. That way one zone serves the cargo, defenders and enemies
## with the three different factors of section 12.2.

enum Kind { ROAD, MUD, OFF_ROAD }

## Road terrain does not change speed. Section 12.1.
const ROAD_CARGO_FACTOR := 1.00
## Off-road is not a zone. It is the absence of road, tested against the route
## centre line, and it applies only to the free steering profile. Section 12.3.
const OFF_ROAD_CARGO_FACTOR := 0.45
const OFF_ROAD_TURN_FACTOR := 0.70

@export var kind: Kind = Kind.MUD
@export var display_name: String = "Mud"
## Section 12.2.
@export var cargo_factor: float = 0.60
@export var defender_factor: float = 0.75
@export var enemy_factor: float = 0.80
## Mud does not change the turn rate. Only off-road does. Section 12.3.
@export var turn_factor: float = 1.00
## Tiled ground texture from the asset pack. Without one the zone falls back to
## the clear grey fill that section 12.2 asks for.
@export var ground_texture: Texture2D

@onready var _fill: Polygon2D = $Fill
@onready var _collision: CollisionPolygon2D = $Collision


func _ready() -> void:
	collision_layer = Layers.TERRAIN
	collision_mask = 0
	# Detectable, but does not look for anything itself.
	monitoring = false
	monitorable = true


## Shape this zone as a mud area over [param polygon]. Section 12.2.
func setup_mud(polygon: PackedVector2Array) -> void:
	kind = Kind.MUD
	display_name = "Mud"
	cargo_factor = 0.60
	defender_factor = 0.75
	enemy_factor = 0.80
	_collision.polygon = polygon
	_fill.polygon = polygon
	if ground_texture != null:
		# The polygon carries no explicit UVs, so the texture maps to local
		# coordinates one to one and repeats across the zone.
		_fill.texture = ground_texture
		_fill.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		_fill.color = Color.WHITE
	else:
		# A clear grey fill shows the mud area. Section 12.2.
		_fill.color = Color(InkPalette.GRAY_MEDIUM, 0.20)


## Short identifier for this terrain kind, used by the cargo terrain label.
func terrain_key() -> String:
	match kind:
		Kind.MUD:
			return "mud"
		Kind.OFF_ROAD:
			return "off_road"
		_:
			return "road"
