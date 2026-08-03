extends Node
## Captures screenshots of the running game, for visual review without the editor.
##
## Must run windowed, because saving a viewport image needs a real rendering
## device. The movie writer crashes under --headless for the same reason.
##
##     Godot --fixed-fps 60 --resolution 1280x720 res://tools/screenshot_run.tscn
##
## Files land in user://screenshots, and the absolute directory is printed at the
## end. Each shot positions the game with public calls only, so this tool cannot
## drift away from what the game actually does.

const MAIN_SCENE := "res://main/main.tscn"
const OUTPUT_DIR := "user://screenshots"

var _main: Node = null
var _controller: GameController = null
var _cargo: CargoUnit = null
var _camera: CameraRig = null
var _hud: Control = null
var _shots: PackedStringArray = PackedStringArray()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SoundBank.enabled = false
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)

	var scene: PackedScene = load(MAIN_SCENE)
	_main = scene.instantiate()
	add_child(_main)

	_controller = _main.get_node("GameController")
	_cargo = _main.get_node("World/CargoUnit")
	_camera = _main.get_node("World/CameraRig")
	_hud = _main.get_node("UserInterface/Hud")

	await _run_shots()

	print("")
	print("=== screenshots ===")
	for shot in _shots:
		print("  %s" % shot)
	print("  directory %s" % ProjectSettings.globalize_path(OUTPUT_DIR))
	print("===================")
	await get_tree().process_frame
	get_tree().quit(0)


func _run_shots() -> void:
	# 1. Control profile selection. Section 8.1.
	await _wait(10)
	await _capture("01_profile_select")

	RunContext.ensure_configured()
	_controller.begin_session(RunContext.profile, RunContext.seed_data)

	# 2. Instruction screen. Section 8.2.
	await _wait(4)
	await _capture("02_instructions")

	_controller.start_run()
	var motor := _cargo.motor as AutoPathMotor

	# 3. The start area, at Normal speed. Sections 11 and 19.
	motor.set_speed_level(CargoData.SpeedLevel.NORMAL)
	await _wait(40)
	await _capture("03_start_area")

	# 4. A bend at Fast speed, showing the camera lead of section 9.
	motor.set_speed_level(CargoData.SpeedLevel.FAST)
	_jump(700.0)
	await _wait(30)
	await _capture("04_bend")

	# 5. The first mud area, with the terrain label of section 12.4.
	_jump(1790.0)
	await _wait(20)
	await _capture("05_mud")

	# 6. Both crack marks, which appear below 30 health. Section 13.2.
	_cargo.apply_damage(_cargo.data.max_health - 25)
	await _wait(20)
	await _capture("06_damaged")

	# 7. The pause screen. Section 8.4.
	_controller._pause()
	await _wait(4)
	await _capture("07_paused")
	_controller._resume()

	# 8. The portal cast ring part way through the four seconds. Section 8.5.
	_cargo.heal(_cargo.data.max_health)
	_jump(8880.0)
	await _wait(90)
	await _capture("08_portal_cast")

	# 9. The result screen. Section 37.
	while _controller.state != GameController.State.RESULT:
		await get_tree().process_frame
	await _wait(4)
	await _capture("09_result")


func _jump(route_offset: float) -> void:
	_cargo.motor.jump_to(route_offset)
	_cargo.route_hint = -1
	_camera.snap_to_target()


func _wait(frames: int) -> void:
	for _i in frames:
		await get_tree().process_frame


func _capture(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, shot_name]
	var error := image.save_png(path)
	if error != OK:
		printerr("could not save %s: %s" % [path, error_string(error)])
		return
	_shots.append("%s.png  %dx%d" % [shot_name, image.get_width(), image.get_height()])
