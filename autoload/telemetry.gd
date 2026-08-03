extends Node
## Records one run and writes it as a JSON file. Specification section 36.
##
## The record holds every field the specification requires. Fields belonging to
## systems that do not exist yet stay at zero, so the file format never changes
## as later milestones land, and the writer needs no update when they do.

const OUTPUT_DIR := "user://telemetry"

## Speed level names used as keys of the time_at_speed table. Section 19.
const SPEED_KEYS: PackedStringArray = ["stop", "slow", "normal", "fast"]
## Terrain names used as keys of the time_on_terrain table. Section 12.
const TERRAIN_KEYS: PackedStringArray = ["road", "mud", "off_road"]

var _record: Dictionary = {}
var _recording: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_record = _blank_record()


## Start a fresh record. Called by [RunContext] when a run is configured.
func begin_run(profile: ControlProfileData, seed_data: TestSeedData) -> void:
	_record = _blank_record()
	_record["control_profile"] = profile.id
	_record["control_profile_name"] = profile.display_name
	_record["cargo_mode"] = ControlProfileData.CargoMode.keys()[profile.cargo_mode]
	_record["defender_mode"] = ControlProfileData.DefenderMode.keys()[profile.defender_mode]
	_record["test_seed"] = seed_data.seed_value
	_recording = true


## Add to an integer counter.
func count(key: String, amount: int = 1) -> void:
	if not _recording:
		return
	_record[key] = int(_record.get(key, 0)) + amount


## Add to a float total.
func accumulate(key: String, amount: float) -> void:
	if not _recording:
		return
	_record[key] = float(_record.get(key, 0.0)) + amount


## Overwrite a value outright.
func set_value(key: String, value: Variant) -> void:
	if not _recording:
		return
	_record[key] = value


## Keep the highest value seen. Used for the maximum threat value.
func set_max(key: String, value: float) -> void:
	if not _recording:
		return
	_record[key] = maxf(float(_record.get(key, 0.0)), value)


## Add time spent at one cargo speed level. Section 36.
func add_speed_time(level: CargoData.SpeedLevel, delta: float) -> void:
	if not _recording:
		return
	var table: Dictionary = _record["time_at_speed"]
	var key: String = SPEED_KEYS[level]
	table[key] = float(table.get(key, 0.0)) + delta


## Add time spent on one terrain type. Section 36.
func add_terrain_time(terrain_key: String, delta: float) -> void:
	if not _recording:
		return
	var table: Dictionary = _record["time_on_terrain"]
	table[terrain_key] = float(table.get(terrain_key, 0.0)) + delta


## Count one defender state change, by the state entered. Section 33 requires
## the telemetry recorder to store each defender state change; a count for each
## state answers the questions of section 42 about defender control without a
## per-event log that no one would read.
func count_state_change(state_id: StringName) -> void:
	if not _recording:
		return
	var table: Dictionary = _record["defender_state_changes"]
	var key := String(state_id)
	table[key] = int(table.get(key, 0)) + 1
	_record["defender_state_changes_total"] = \
		int(_record.get("defender_state_changes_total", 0)) + 1


## Store the five result screen answers. Section 37.
func set_questionnaire(answers: PackedInt32Array) -> void:
	if not _recording:
		return
	_record["questionnaire"] = Array(answers)


func end_run(success: bool, run_seconds: float, cargo_health: int) -> void:
	if not _recording:
		return
	_record["success"] = success
	_record["run_duration"] = snappedf(run_seconds, 0.01)
	_record["cargo_health_end"] = cargo_health
	# The threat value is counted in whole points. Section 27.
	_record["max_threat"] = floori(float(_record.get("max_threat", 0.0)))


## Read-only view of the current record, for the result screen and the debug
## overlay.
func get_record() -> Dictionary:
	return _record.duplicate(true)


## Write the record to [constant OUTPUT_DIR] and return the full path, or an
## empty string when the write failed.
func write_file() -> String:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var stamp := Time.get_datetime_string_from_system(false, true)
	stamp = stamp.replace(":", "-").replace(" ", "_")
	var file_name := "run_%s_%s_seed%d.json" % [
		stamp, _record.get("control_profile", "unknown"), int(_record.get("test_seed", 0)),
	]
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Telemetry could not write %s: %s" % [
			path, error_string(FileAccess.get_open_error()),
		])
		return ""
	file.store_string(JSON.stringify(_rounded(_record), "\t", false))
	file.close()
	_recording = false
	return path


## Round every float to two decimals. Accumulating a value each frame leaves a
## long binary tail, and this file is meant to be read by a person as well as a
## script.
func _rounded(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			return snappedf(value, 0.01)
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for key: Variant in value:
				out[key] = _rounded(value[key])
			return out
		TYPE_ARRAY:
			var list: Array = []
			for item: Variant in value:
				list.append(_rounded(item))
			return list
		_:
			return value


func _blank_record() -> Dictionary:
	var speed_table: Dictionary = {}
	for key in SPEED_KEYS:
		speed_table[key] = 0.0
	var terrain_table: Dictionary = {}
	for key in TERRAIN_KEYS:
		terrain_table[key] = 0.0
	return {
		# Run identity. Sections 35 and 36.
		"control_profile": "",
		"control_profile_name": "",
		"cargo_mode": "",
		"defender_mode": "",
		"test_seed": 0,
		# Outcome.
		"success": false,
		"run_duration": 0.0,
		"cargo_health_end": 0,
		"defender_survivors": 0,
		"max_threat": 0.0,
		# Movement.
		"distance_traveled": 0.0,
		"time_at_speed": speed_table,
		"time_on_terrain": terrain_table,
		"cargo_direction_changes": 0,
		# Defender control.
		"defender_selections": 0,
		"defender_orders": 0,
		"direct_target_orders": 0,
		# Section 33. Not one of the section 36 fields, but the recorder is
		# required to store state changes and this is where a run is recorded.
		"defender_state_changes": {},
		"defender_state_changes_total": 0,
		# Wizard control.
		"spell_selections": 0,
		"spell_casts": 0,
		"invalid_spell_casts": 0,
		"mana_spent": 0,
		# Combat.
		"damage_to_cargo": 0,
		"damage_to_defenders": 0,
		"defender_deaths": 0,
		"cargo_repair_amount": 0.0,
		"barrier_work_amount": 0.0,
		"defender_idle_time": 0.0,
		"defender_time_outside_defense_radius": 0.0,
		# Section 34. How often a unit was blocked long enough to need a fallback
		# position, which is the acceptance criterion of section 40.
		"unit_fallbacks": 0,
		# Session behaviour.
		"pause_count": 0,
		"total_pause_time": 0.0,
		# Result screen. Section 37.
		"questionnaire": [],
	}
