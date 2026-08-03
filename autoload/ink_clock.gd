extends Node
## One global tick for the hand-drawn line effect. Specification section 10.3.
##
## Important world objects use two slightly different line frames and change the
## frame every 0.15 seconds. Every [InkSprite] listens to this one signal instead
## of running its own timer, so the whole picture is redrawn together and the
## cost is one signal each 0.15 seconds.
##
## This node is pausable on purpose. The line effect freezes with the simulation.

signal frame_changed(frame: int)

const FRAME_SECONDS := 0.15
const FRAME_COUNT := 2

## Index of the line frame that is currently visible.
var frame: int = 0

var _elapsed: float = 0.0


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < FRAME_SECONDS:
		return
	_elapsed = fmod(_elapsed, FRAME_SECONDS)
	frame = (frame + 1) % FRAME_COUNT
	frame_changed.emit(frame)
