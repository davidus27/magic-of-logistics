extends Control
## Outcome banner. Specification sections 8.6 and 8.7.
##
## Replaces the old result screen and its five-question survey. While visible it
## builds one line from live [GameController] state — there is no metrics grid,
## no questionnaire, and nothing is written to disk.

## Wired as NodePath rather than as a node export. See [NodeRef] for why.
@export var controller_path: NodePath

var _controller: GameController = null
var _heading: Label = null
var _line: Label = null


func _ready() -> void:
	_controller = NodeRef.get_required(self, controller_path, "controller") as GameController
	_build()


func _build() -> void:
	var column := InkUi.build_overlay(self, 560.0, true)

	_heading = InkUi.label("", InkUi.FONT_SIZE_TITLE)
	column.add_child(_heading)
	column.add_child(InkUi.rule())

	_line = InkUi.label("", InkUi.FONT_SIZE_BODY, InkPalette.GRAY_MEDIUM)
	column.add_child(_line)

	column.add_child(InkUi.rule())
	column.add_child(InkUi.label("Press Enter to return.", InkUi.FONT_SIZE_HEADING))


func _process(_delta: float) -> void:
	if not visible or _controller == null:
		return
	var success := _controller.state == GameController.State.SUCCESS
	_heading.text = "Success" if success else "Failure"
	_line.text = _outcome_line(success)


func _outcome_line(success: bool) -> String:
	var seconds := int(_controller.run_seconds)
	var time_text := "%d:%02d" % [seconds / 60, seconds % 60]
	if success:
		return "Portal reached in %s" % time_text
	match _controller._end_reason:
		"cargo_destroyed":
			return "Cargo destroyed after %s" % time_text
		"time_limit":
			return "Run timed out after %s" % time_text
		_:
			return "Run ended after %s" % time_text
