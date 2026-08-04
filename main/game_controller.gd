class_name GameController
extends Node
## The game state machine. Specification section 8.
##
## This node runs while the tree is paused, because it has to react to the pause
## key and drive the screens that appear over a paused world. The run timer is
## still exact: it only advances in the states that are part of a run, so the
## pause state adds no time, which is what section 8.4 requires.

signal state_changed(state: State)
signal run_time_changed(seconds: float)
signal threat_changed(threat: float)

enum State {
	START,
	INSTRUCTIONS,
	RUN,
	PAUSE,
	PORTAL_CAST,
	SUCCESS,
	FAILURE,
}

## The cast takes four seconds. Section 8.5.
const PORTAL_CAST_SECONDS := 4.0
## A run must not continue for more than eight minutes. Section 7.
const RUN_TIME_LIMIT := 480.0

## Wired as NodePath rather than as node exports. See [NodeRef] for why.
@export var world_path: NodePath
@export var map_path: NodePath
@export var cargo_path: NodePath
@export var camera_path: NodePath
@export var squad_path: NodePath
@export var spawner_path: NodePath
@export var wizard_path: NodePath
@export var start_screen_path: NodePath
@export var instructions_path: NodePath
@export var hud_path: NodePath
@export var outcome_banner_path: NodePath

var world: Node2D
var map: Map
var cargo: CargoUnit
var camera: CameraRig
var squad: Squad
var spawner: EnemySpawner
var wizard: Wizard
var start_screen: Control
var instructions: Control
var hud: Control
var outcome_banner: Control

var state: State = State.START
var run_seconds: float = 0.0
## Increases by one each second and stops during pause. Section 27.
var threat: float = 0.0

var _cast_seconds: float = 0.0
var _pause_seconds: float = 0.0
var _end_reason: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	world = NodeRef.get_required(self, world_path, "world")
	map = NodeRef.get_required(self, map_path, "map")
	cargo = NodeRef.get_required(self, cargo_path, "cargo")
	camera = NodeRef.get_required(self, camera_path, "camera")
	squad = NodeRef.get_required(self, squad_path, "squad")
	spawner = NodeRef.get_required(self, spawner_path, "enemy spawner")
	wizard = NodeRef.get_required(self, wizard_path, "wizard")
	start_screen = NodeRef.get_required(self, start_screen_path, "start screen")
	instructions = NodeRef.get_required(self, instructions_path, "instructions")
	hud = NodeRef.get_required(self, hud_path, "hud")
	outcome_banner = NodeRef.get_required(self, outcome_banner_path, "outcome banner")

	if map == null or cargo == null or start_screen == null:
		push_error("GameController is missing required nodes and will not run.")
		return

	cargo.destroyed.connect(_on_cargo_destroyed)
	start_screen.start_pressed.connect(_on_start_pressed)
	_enter(State.START)


func _process(delta: float) -> void:
	match state:
		State.RUN:
			_advance_run(delta)
			_check_portal()
			if run_seconds >= RUN_TIME_LIMIT:
				# The time limit prevents a run from continuing indefinitely. Section 7.
				_fail("time_limit")
		State.PORTAL_CAST:
			_advance_run(delta)
			_cast_seconds += delta
			map.get_portal().set_cast_ratio(_cast_seconds / PORTAL_CAST_SECONDS)
			if _cast_seconds >= PORTAL_CAST_SECONDS:
				_succeed()
		State.PAUSE:
			_pause_seconds += delta


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_run"):
		if state == State.RUN or state == State.PORTAL_CAST:
			_pause()
		elif state == State.PAUSE:
			_resume()
		else:
			return
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("confirm"):
		if state == State.INSTRUCTIONS:
			start_run()
		elif state == State.PAUSE:
			_resume()
		elif state == State.SUCCESS or state == State.FAILURE:
			_enter(State.START)
		else:
			return
		get_viewport().set_input_as_handled()


## Build the world for a run and show the instruction screen.
## Section 8.1 and 8.2.
func begin_session() -> void:
	map.build()

	cargo.setup(map, AutoPathMotor.new())
	camera.target = cargo
	camera.snap_to_target()

	# Order matters. The spawner clears the field before the squad places
	# defenders around a cargo unit that is already at the start of the route,
	# and the wizard reads nothing from either.
	spawner.build()
	squad.build()
	wizard.build()

	run_seconds = 0.0
	threat = 0.0
	_cast_seconds = 0.0
	_pause_seconds = 0.0
	_end_reason = ""

	_enter(State.INSTRUCTIONS)


## Leave the instruction screen and start the run. Section 8.2.
func start_run() -> void:
	if state == State.INSTRUCTIONS:
		_enter(State.RUN)


## Start a run immediately. Used by the headless smoke test, which has no
## screens to click.
func begin_default_session() -> void:
	RunContext.ensure_configured()
	begin_session()
	_enter(State.RUN)


func _advance_run(delta: float) -> void:
	run_seconds += delta
	# The threat value rises one point a second and stops during pause, because
	# pause is not a run state and this runs only in the run states. Section 27.
	threat += delta
	# Each time it passes another interval the spawner sends reinforcements in
	# behind the cargo, so a slow run turns dangerous. Section 27.
	spawner.update_threat(threat)
	run_time_changed.emit(run_seconds)
	threat_changed.emit(threat)


func _check_portal() -> void:
	var portal := map.get_portal()
	if portal != null and portal.contains_point(cargo.global_position):
		_enter(State.PORTAL_CAST)


func _pause() -> void:
	_enter(State.PAUSE)


func _resume() -> void:
	_pause_seconds = 0.0
	_enter(State.RUN)


func _succeed() -> void:
	_end_reason = "portal"
	_enter(State.SUCCESS)


func _fail(reason: String) -> void:
	_end_reason = reason
	_enter(State.FAILURE)


func _on_cargo_destroyed() -> void:
	if state == State.SUCCESS or state == State.FAILURE:
		return
	# The player fails the run when the cargo health becomes zero. Section 6.
	_fail("cargo_destroyed")


func _on_start_pressed() -> void:
	begin_session()


func _enter(next_state: State) -> void:
	state = next_state

	# Section 8: the run simulates only in the active run and the portal cast.
	# Every other state stops all simulation.
	var simulating := state == State.RUN or state == State.PORTAL_CAST
	get_tree().paused = not simulating
	cargo.simulating = simulating
	# Enemies can attack during the cast, so the wizard keeps working through it.
	# Section 8.5.
	wizard.active = simulating

	if state == State.PORTAL_CAST:
		# The cargo unit stops during the cast. Section 8.5.
		cargo.set_motor_locked(true)
	elif state == State.RUN:
		cargo.set_motor_locked(false)

	# The map is generated when a session begins, so before that the world
	# holds an unbuilt map and a cargo unit stacked at the origin. Hide it rather
	# than show that through the start screen.
	if world != null:
		world.visible = state != State.START

	start_screen.visible = state == State.START
	instructions.visible = state == State.INSTRUCTIONS or state == State.PAUSE
	outcome_banner.visible = state == State.SUCCESS or state == State.FAILURE
	hud.visible = state not in [State.START, State.SUCCESS, State.FAILURE]

	if state == State.PAUSE:
		instructions.show_as_pause()
	elif state == State.INSTRUCTIONS:
		instructions.show_as_briefing()

	state_changed.emit(state)


## Name of the current state, for the debug overlay.
func state_name() -> String:
	return State.keys()[state]
