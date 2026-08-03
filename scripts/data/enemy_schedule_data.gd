class_name EnemyScheduleData
extends Resource
## The fixed enemy attack schedule. Specification section 26.
##
## One entry for each of the six trigger areas, in route order. Where the trigger
## areas are is a property of the map, so the offsets stay in [MapRouteData] and
## only the group contents live here.

## Enemies in each group as (short-range count, long-range count). Section 26.
@export var groups: Array[Vector2i] = []

@export_group("Spawn placement", "spawn_")
## An enemy appears this far in front of the trigger point, along the route.
## Far enough to be seen coming, near enough to reach the cargo unit.
@export var spawn_ahead_min: float = 200.0
@export var spawn_ahead_max: float = 640.0
## Largest sideways offset from the route centre line.
##
## Must stay inside the navigation area, which reaches
## [member MapRouteData.navigation_margin] beyond the road edge.
@export var spawn_lateral_max: float = 380.0


## Total enemies in one group.
func group_size(index: int) -> int:
	if index < 0 or index >= groups.size():
		return 0
	return groups[index].x + groups[index].y
