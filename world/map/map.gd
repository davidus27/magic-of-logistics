class_name Map
extends Node2D
## Builds the whole battlefield from one [MapRouteData] resource.
## Specification sections 11, 12, 28 and 34.
##
## Nothing about the route is placed by hand. The road lines, the road walls, the
## map border walls, the navigation region, the mud zones, the barriers and the
## final portal are all derived from the route centre line, because the route is
## 9000 pixels long and hand placing that much geometry is not maintainable.
##
## [method build] is public and idempotent. [GameController] calls it once the
## control profile is known, because the profile decides whether the road walls
## exist at all.

signal route_built(route_length: float)

## Distance from the navigation area out to the map border walls.
const BORDER_MARGIN := 600.0
## Baking radius of the navigation mesh. A little above the defender body radius
## so a unit never clips a wall corner.
const NAVIGATION_AGENT_RADIUS := 14.0
## Samples searched either side of a position hint before a full scan.
const HINT_WINDOW := 8
## Spacing of the centre line the navigation band is offset from.
const NAVIGATION_SPINE_STEP := 200.0
## Width of the road edge lines.
const EDGE_LINE_WIDTH := 3.0

@export var route: MapRouteData
@export var terrain_zone_scene: PackedScene
@export var barrier_scene: PackedScene

var curve := Curve2D.new()
var route_length: float = 0.0
## World rectangle inside the map border walls.
var bounds := Rect2()

var _samples := PackedVector2Array()
## Unit normal at each sample, pointing to the left of the travel direction.
var _normals := PackedVector2Array()
## Arc length offset of each sample.
var _offsets := PackedFloat32Array()

@onready var _paper: Polygon2D = $PaperBackground
@onready var _road: Node2D = $Road
@onready var _road_walls: Node2D = $RoadWalls
@onready var _map_walls: Node2D = $MapWalls
@onready var _terrain_root: Node2D = $TerrainZones
@onready var _barrier_root: Node2D = $BarrierContainer
@onready var _navigation: NavigationRegion2D = $NavigationRegion2D
@onready var _portal: FinalPortal = $FinalPortal


## Generate the battlefield. Safe to call again after changing [member route].
func build() -> void:
	if route == null:
		push_error("Map has no MapRouteData assigned.")
		return
	if route.control_points.size() < 2:
		push_error("MapRouteData needs at least two control points.")
		return

	_build_curve()
	_sample_curve()
	_compute_bounds()

	_build_paper_background()
	_build_road_lines()
	_build_road_walls()
	_build_map_walls()
	_build_navigation()
	_build_terrain_zones()
	_build_barriers()
	_place_portal()

	print("[Map] route length %.0fpx, %d samples, %d barriers, %d mud zones" % [
		route_length, _samples.size(), _barrier_root.get_child_count(),
		_terrain_root.get_child_count(),
	])
	route_built.emit(route_length)


# --- Public queries -----------------------------------------------------------


## Position and travel direction at an arc offset along the route.
func sample_route(offset: float) -> Transform2D:
	var clamped := clampf(offset, 0.0, route_length)
	return Transform2D(route_direction(clamped).angle(), curve.sample_baked(clamped, true))


## Unit travel direction at an arc offset.
##
## Derived from two nearby positions rather than from
## [method Curve2D.sample_baked_with_rotation], whose axis convention is easy to
## misread. Two positions cannot be misread.
func route_direction(offset: float) -> Vector2:
	var behind := curve.sample_baked(clampf(offset - 1.0, 0.0, route_length), true)
	var ahead := curve.sample_baked(clampf(offset + 1.0, 0.0, route_length), true)
	var forward := ahead - behind
	if forward.length_squared() < 0.000001:
		return Vector2.RIGHT
	return forward.normalized()


## Index of the route sample nearest to a world position.
##
## [param hint] is the caller's previous result. The search stays in a window
## around it, which is not only cheaper than a full scan but also more correct:
## on a winding route a position can sit near two distant parts of the curve, and
## a full scan may snap progress to the wrong bend.
func nearest_sample_index(world_point: Vector2, hint: int = -1) -> int:
	if _samples.is_empty():
		return -1
	if hint >= 0 and hint < _samples.size():
		var best := hint
		var best_distance := world_point.distance_squared_to(_samples[hint])
		var low := maxi(0, hint - HINT_WINDOW)
		var high := mini(_samples.size() - 1, hint + HINT_WINDOW)
		for i in range(low, high + 1):
			var distance := world_point.distance_squared_to(_samples[i])
			if distance < best_distance:
				best_distance = distance
				best = i
		# Only trust the window when the winner is inside it. A winner on the
		# edge means the real nearest sample is probably beyond the window.
		if best > low and best < high:
			return best
	var scan_best := 0
	var scan_distance := world_point.distance_squared_to(_samples[0])
	for i in range(1, _samples.size()):
		var distance := world_point.distance_squared_to(_samples[i])
		if distance < scan_distance:
			scan_distance = distance
			scan_best = i
	return scan_best


## Arc offset of the route point nearest to a world position.
func offset_at(world_point: Vector2, hint_index: int = -1) -> float:
	var index := nearest_sample_index(world_point, hint_index)
	if index < 0:
		return 0.0
	return _offsets[index]


## Perpendicular distance from a world position to the route centre line.
## Used for the off-road test of section 12.3 and for the portal distance readout.
func distance_from_centerline(world_point: Vector2, hint_index: int = -1) -> float:
	var index := nearest_sample_index(world_point, hint_index)
	if index < 0:
		return 0.0
	# Measure against the segment through the nearest sample rather than the
	# sample itself, or the result steps by the sample spacing.
	var neighbour := index + 1 if index + 1 < _samples.size() else index - 1
	if neighbour < 0:
		return world_point.distance_to(_samples[index])
	var closest := Geometry2D.get_closest_point_to_segment(
		world_point, _samples[index], _samples[neighbour]
	)
	return world_point.distance_to(closest)


func get_portal() -> FinalPortal:
	return _portal


func get_barriers() -> Array[Barrier]:
	var out: Array[Barrier] = []
	for child in _barrier_root.get_children():
		var barrier := child as Barrier
		if barrier != null:
			out.append(barrier)
	return out


## Remaining route distance to the final portal.
func distance_to_portal(world_point: Vector2, hint_index: int = -1) -> float:
	return maxf(0.0, route.portal_offset - offset_at(world_point, hint_index))


## Rebake the navigation mesh. Called when a barrier opens. Section 34.
func rebake_navigation() -> void:
	_build_navigation()


# --- Curve --------------------------------------------------------------------


func _build_curve() -> void:
	curve = Curve2D.new()
	var points := route.control_points
	var count := points.size()
	for i in count:
		# Tangents from the neighbours of each point, so the route stays smooth
		# when a point is moved in the editor. One sixth of the span between the
		# neighbours matches a Catmull-Rom spline.
		var before := points[maxi(0, i - 1)]
		var after := points[mini(count - 1, i + 1)]
		var tangent := (after - before) / 6.0
		curve.add_point(points[i], -tangent, tangent)
	route_length = curve.get_baked_length()


func _sample_curve() -> void:
	_samples = PackedVector2Array()
	_normals = PackedVector2Array()
	_offsets = PackedFloat32Array()
	var step := maxf(4.0, route.sample_step)
	var offset := 0.0
	while offset < route_length:
		_append_sample(offset)
		offset += step
	_append_sample(route_length)


func _append_sample(offset: float) -> void:
	var forward := route_direction(offset)
	_samples.append(curve.sample_baked(offset, true))
	_normals.append(Vector2(-forward.y, forward.x))
	_offsets.append(offset)


func _compute_bounds() -> void:
	var reach := route.road_width * 0.5 + route.navigation_margin + BORDER_MARGIN
	bounds = Rect2(_samples[0], Vector2.ZERO)
	for point in _samples:
		bounds = bounds.expand(point)
	bounds = bounds.grow(reach)


# --- Geometry helpers ---------------------------------------------------------


## Remove vertices that are too close together to be distinct to the navigation
## rasteriser.
##
## The bends of the route are 1400 pixels apart while the navigation band is 570
## pixels wide either side, so the band around one bend overlaps its neighbours and
## the offset result is a single merged outline. The polygon clipper leaves
## coincident and near coincident vertices along those merge seams, and each one
## becomes an "edges tried to occupy the same rasterization space" error and a hole
## in edge connectivity. Snapping to whole pixels and dropping repeats removes them.
func _clean_outline(outline: PackedVector2Array) -> PackedVector2Array:
	var cleaned := PackedVector2Array()
	for point in outline:
		var snapped_point := point.round()
		if cleaned.is_empty() or not cleaned[cleaned.size() - 1].is_equal_approx(snapped_point):
			cleaned.append(snapped_point)
	# An outline is implicitly closed, so a repeated first point is another
	# zero length edge.
	while cleaned.size() > 1 and cleaned[0].is_equal_approx(cleaned[cleaned.size() - 1]):
		cleaned.remove_at(cleaned.size() - 1)
	return cleaned


## A decimated centre line for the navigation bake. See [method _build_navigation].
func _navigation_spine() -> PackedVector2Array:
	var stride := maxi(1, int(round(NAVIGATION_SPINE_STEP / maxf(4.0, route.sample_step))))
	var spine := PackedVector2Array()
	for i in range(0, _samples.size(), stride):
		spine.append(_samples[i])
	var last := _samples[_samples.size() - 1]
	if spine.is_empty() or not spine[spine.size() - 1].is_equal_approx(last):
		spine.append(last)
	return spine


## Points along the route offset sideways by [param distance]. Positive is left.
func _edge_points(distance: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(_samples.size())
	for i in _samples.size():
		out[i] = _samples[i] + _normals[i] * distance
	return out


## Closed polygon covering the road between two arc offsets.
##
## The two ends are placed at the exact offsets asked for, and the route samples
## strictly between them fill in the middle. The comparison has to be strict: zone
## offsets in the route data tend to be round numbers that land exactly on a
## sample offset, and repeating that point gives the polygon a zero length edge,
## which makes convex decomposition of the collision shape fail outright.
func _band_polygon(from_offset: float, to_offset: float, half_width: float) -> PackedVector2Array:
	if to_offset <= from_offset:
		return PackedVector2Array()

	var offsets := PackedFloat32Array([from_offset])
	for offset in _offsets:
		if offset > from_offset and offset < to_offset:
			offsets.append(offset)
	offsets.append(to_offset)

	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for offset in offsets:
		var clamped := clampf(offset, 0.0, route_length)
		var forward := route_direction(clamped)
		var normal := Vector2(-forward.y, forward.x)
		var origin := curve.sample_baked(clamped, true)
		left.append(origin + normal * half_width)
		right.append(origin - normal * half_width)

	# Down one side and back along the other closes the ring.
	right.reverse()
	var polygon := left
	polygon.append_array(right)
	return polygon


func _clear(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
		node.remove_child(child)


func _make_static_wall(name_hint: String, outline: PackedVector2Array, layer: int) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = name_hint
	body.collision_layer = layer
	# Walls never test against anything themselves.
	body.collision_mask = 0

	var segments := PackedVector2Array()
	for i in outline.size() - 1:
		segments.append(outline[i])
		segments.append(outline[i + 1])

	var shape := ConcavePolygonShape2D.new()
	shape.segments = segments
	var collider := CollisionShape2D.new()
	collider.shape = shape
	body.add_child(collider)
	return body


# --- Build steps --------------------------------------------------------------


func _build_paper_background() -> void:
	# A paper coloured fill over the play area. The screen clear colour is the
	# same, so this only marks where the map is.
	_paper.color = InkPalette.PAPER
	_paper.polygon = PackedVector2Array([
		bounds.position,
		Vector2(bounds.end.x, bounds.position.y),
		bounds.end,
		Vector2(bounds.position.x, bounds.end.y),
	])


func _build_road_lines() -> void:
	_clear(_road)
	var half := route.road_width * 0.5
	for side in [half, -half]:
		var line := Line2D.new()
		line.points = _edge_points(side)
		line.width = EDGE_LINE_WIDTH
		line.default_color = InkPalette.LINE_LIGHT
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.antialiased = true
		_road.add_child(line)
	# The road interior stays paper. Mud is the only filled ground, which is what
	# makes it read at a glance. Section 12.2.


func _build_road_walls() -> void:
	_clear(_road_walls)
	RunContext.ensure_configured()
	if not RunContext.profile.use_road_walls:
		# Control method C removes the road walls so the cargo can leave the
		# road. Section 21.
		return
	var half := route.road_width * 0.5
	_road_walls.add_child(_make_static_wall("LeftWall", _edge_points(half), Layers.ROAD_WALL))
	_road_walls.add_child(_make_static_wall("RightWall", _edge_points(-half), Layers.ROAD_WALL))


func _build_map_walls() -> void:
	_clear(_map_walls)
	var outline := PackedVector2Array([
		bounds.position,
		Vector2(bounds.end.x, bounds.position.y),
		bounds.end,
		Vector2(bounds.position.x, bounds.end.y),
		bounds.position,
	])
	_map_walls.add_child(_make_static_wall("BorderWall", outline, Layers.MAP_WALL))


func _build_navigation() -> void:
	# The navigation band is wider than the minimum turn radius of the route, so
	# a plain sideways offset of the centre line would fold through itself on the
	# inside of a bend. Geometry2D.offset_polyline resolves that properly.
	#
	# It is offset from a coarser spine than the road uses. Offsetting all 227
	# road samples by 570 pixels puts many outline vertices inside one navigation
	# rasterisation cell, and the navigation server then reports hundreds of
	# duplicate edges and produces a mesh with holes. The band is 570 pixels wide,
	# so a 200 pixel spine loses no accuracy that matters.
	var band_half := route.road_width * 0.5 + route.navigation_margin
	var outlines := Geometry2D.offset_polyline(
		_navigation_spine(), band_half, Geometry2D.JOIN_ROUND, Geometry2D.END_SQUARE
	)

	var source := NavigationMeshSourceGeometryData2D.new()
	for outline in outlines:
		source.add_traversable_outline(_clean_outline(outline))

	# A closed barrier is a hole in the navigation area until it opens. Section 34.
	for child in _barrier_root.get_children():
		var barrier := child as Barrier
		if barrier != null and not barrier.is_open():
			source.add_obstruction_outline(barrier.get_obstruction_outline())

	var polygon := NavigationPolygon.new()
	polygon.agent_radius = NAVIGATION_AGENT_RADIUS
	NavigationServer2D.bake_from_source_geometry_data(polygon, source)
	_navigation.navigation_polygon = polygon


func _build_terrain_zones() -> void:
	_clear(_terrain_root)
	if terrain_zone_scene == null:
		return
	var half := route.road_width * 0.5
	for zone_data in route.mud_zones:
		var from_offset: float = zone_data.x
		var to_offset: float = zone_data.x + zone_data.y
		var polygon := _band_polygon(from_offset, to_offset, half)
		if polygon.is_empty():
			push_warning("Mud zone at offset %.0f produced no polygon." % from_offset)
			continue
		var zone: TerrainZone = terrain_zone_scene.instantiate()
		_terrain_root.add_child(zone)
		zone.setup_mud(polygon)


func _build_barriers() -> void:
	_clear(_barrier_root)
	if not route.enable_barriers or barrier_scene == null:
		return
	for offset in route.barrier_offsets:
		var barrier: Barrier = barrier_scene.instantiate()
		_barrier_root.add_child(barrier)
		var placement := sample_route(offset)
		barrier.global_position = placement.get_origin()
		# The art is drawn along its own x axis, so turning it a quarter turn
		# from the travel direction lays it across the road.
		barrier.rotation = placement.get_rotation() + PI * 0.5
		barrier.road_width = route.road_width
		barrier.opened.connect(_on_barrier_opened)


func _place_portal() -> void:
	var placement := sample_route(route.portal_offset)
	_portal.global_position = placement.get_origin()
	_portal.radius = route.portal_radius


func _on_barrier_opened() -> void:
	# The navigation map must update after a barrier opens. Section 34.
	rebake_navigation()
