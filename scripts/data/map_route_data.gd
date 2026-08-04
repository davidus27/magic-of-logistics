class_name MapRouteData
extends Resource
## The full battlefield layout. Specification section 11.
##
## Everything in the map is generated from [member control_points]: the road
## lines, the road walls, the navigation region, the terrain zones, the barriers
## and the final portal. Nothing about the route is placed by hand.
##
## [member control_points] are positions only. [Map] derives smooth tangents
## from the neighbours of each point, so moving one point in the editor keeps the
## route smooth.

## Route centre line, in order from the start area to the final portal.
@export var control_points: PackedVector2Array = PackedVector2Array()

## Visible road width in pixels. Specification section 11.
@export var road_width: float = 420.0

## Distance in pixels from the road edge to the edge of the navigation area.
## Must cover the defender attack leash (480) and the long-range enemy maximum
## range (360) so that no unit is ever pushed off the navigation mesh.
@export var navigation_margin: float = 360.0

@export_group("Contents")
## Mud areas as (offset along the route, length). Two entries. Section 12.2.
@export var mud_zones: Array[Vector2] = []
## Barrier positions as offsets along the route. Two entries. Section 28.
@export var barrier_offsets: PackedFloat32Array = PackedFloat32Array()
## Enemy trigger positions as offsets along the route. Six entries. Section 26.
@export var trigger_offsets: PackedFloat32Array = PackedFloat32Array()
## Final portal position as an offset along the route. Section 11.
@export var portal_offset: float = 8900.0
## Final portal trigger radius in pixels.
@export var portal_radius: float = 70.0

@export_group("Build")
## Distance in pixels between generated road samples. Lower is smoother and
## more expensive.
@export var sample_step: float = 40.0
## Barriers need the Repair state to open, so the route is not completable with
## barriers before that exists.
@export var enable_barriers: bool = false
## Off. The MVP has one cargo motor and it never leaves the road, so the walls
## would only ever collide with nothing.
@export var enable_road_walls: bool = false
