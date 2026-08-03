class_name AutoPathMotor
extends CargoMotor
## Cargo control method A: automatic path movement. Specification section 19.
##
## The cargo follows the centre of the road and the player only chooses a speed
## level. This motor writes the transform directly and does not call
## move_and_slide(): the cargo rides the centre line, so road wall collision
## cannot apply, and forcing the curve through the physics solver would only
## fight it. A closed barrier stops the cargo by clamping the route offset, which
## is exact where a collision response would let the cargo creep.

## Speed level of section 19. Stored as int so that stepping it up and down needs
## no cast on every change.
var speed_level: int = CargoData.SpeedLevel.STOP
var current_speed: float = 0.0
var route_offset: float = 0.0


func place_at_start() -> void:
	route_offset = 0.0
	speed_level = CargoData.SpeedLevel.STOP
	current_speed = 0.0
	_apply_transform()


func jump_to(target_offset: float) -> void:
	route_offset = clampf(target_offset, 0.0, map.route_length)
	_apply_transform()


func step(delta: float) -> void:
	# Terrain changes the maximum speed, not the acceleration. Section 12.
	var target := 0.0
	if not locked:
		target = cargo.data.speed_for_level(speed_level) * cargo.terrain_factor

	if current_speed < target:
		current_speed = minf(current_speed + cargo.data.acceleration * delta, target)
	elif current_speed > target:
		current_speed = maxf(current_speed - cargo.data.brake_rate * delta, target)

	if current_speed <= 0.0:
		current_speed = 0.0
		cargo.velocity = Vector2.ZERO
		return

	route_offset = minf(route_offset + current_speed * delta, _forward_limit())
	_apply_transform()
	# Published for consumers such as the camera lead direction, even though this
	# motor does not integrate velocity itself.
	cargo.velocity = map.route_direction(route_offset) * current_speed


func get_speed_level() -> int:
	return speed_level


func get_current_speed() -> float:
	return current_speed


func get_route_offset() -> float:
	return route_offset


func _unhandled_input(event: InputEvent) -> void:
	if cargo == null or not cargo.simulating or locked:
		return
	if event.is_action_pressed("cargo_speed_up"):
		set_speed_level(speed_level + 1)
	elif event.is_action_pressed("cargo_speed_down"):
		set_speed_level(speed_level - 1)
	elif event.is_action_pressed("cargo_full_brake"):
		# Space selects Stop immediately. Section 19.
		set_speed_level(CargoData.SpeedLevel.STOP)
	else:
		return
	get_viewport().set_input_as_handled()


func set_speed_level(level: int) -> void:
	var clamped := clampi(level, CargoData.SpeedLevel.STOP, CargoData.SpeedLevel.FAST)
	if clamped == speed_level:
		return
	speed_level = clamped
	# The cargo speed change uses one short click. Section 31.
	SoundBank.play(SoundBank.SPEED_CHANGE)
	cargo.speed_level_changed.emit(speed_level)


func _apply_transform() -> void:
	var placement := map.sample_route(route_offset)
	cargo.global_position = placement.get_origin()
	cargo.rotation = placement.get_rotation()


## The furthest route offset the cargo may reach, given the closed barriers.
## Section 19.
func _forward_limit() -> float:
	var limit := map.route_length
	var nose := cargo.data.body_size.x * 0.5
	for barrier in map.get_barriers():
		if barrier.is_open():
			continue
		var stop_at := barrier.route_offset - Barrier.THICKNESS * 0.5 - nose
		if stop_at >= route_offset:
			limit = minf(limit, stop_at)
	return limit
