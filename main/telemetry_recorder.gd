class_name TelemetryRecorder
extends Node
## Samples the per-frame values of the telemetry file. Specification section 36.
##
## The record itself lives in the Telemetry autoload, which outlives any scene.
## This node contributes only what the running scene knows: time at each cargo
## speed level, time on each terrain type, and distance travelled.

## Wired as NodePath rather than as node exports. See [NodeRef] for why.
@export var controller_path: NodePath
@export var cargo_path: NodePath

var controller: GameController
var cargo: CargoUnit


func _ready() -> void:
	controller = NodeRef.get_required(self, controller_path, "controller")
	cargo = NodeRef.get_required(self, cargo_path, "cargo")


func _process(delta: float) -> void:
	if controller == null or cargo == null:
		return
	# Only a live run counts. The pause state must not add time. Section 8.4.
	if controller.state != GameController.State.RUN \
			and controller.state != GameController.State.PORTAL_CAST:
		return

	Telemetry.add_speed_time(cargo.get_speed_level(), delta)
	Telemetry.add_terrain_time(cargo.terrain_key, delta)
	Telemetry.set_value("distance_traveled", snappedf(cargo.distance_travelled, 0.1))
