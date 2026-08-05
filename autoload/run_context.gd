extends Node
## The run seed that defines the current session. Specification section 35.
##
## The seed controls enemy spawn positions only, and every system reads it
## from here instead of holding its own copy. A run started without going
## through `_ready` first, such as a headless test run, falls back to the
## same fixed seed resource.

const RUN_SEED_PATH := "res://data/run_seed.tres"

var seed_data: RunSeedData = null

## Seeded from the fixed run seed, so enemy spawn positions repeat exactly
## from run to run. Section 35.
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	seed_data = load(RUN_SEED_PATH)
	ensure_configured()


## Guarantees the rng is seeded. Every system calls this instead of assuming
## `_ready` already ran.
func ensure_configured() -> void:
	if seed_data == null:
		push_error("RunContext has no run seed resource to fall back to.")
		return
	rng.seed = seed_data.seed_value
