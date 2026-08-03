extends Node
## The selections that define the current run. Specification sections 8.1 and 35.
##
## The control profile selection screen writes here, and every system reads the
## profile from here instead of holding its own copy. A run started without a
## selection, such as a headless test run, falls back to the first profile and
## the first seed.

const PROFILE_PATHS: PackedStringArray = [
	"res://data/profiles/profile_p1.tres",
	"res://data/profiles/profile_p2.tres",
	"res://data/profiles/profile_p3.tres",
	"res://data/profiles/profile_p4.tres",
]
const SEED_PATHS: PackedStringArray = [
	"res://data/seeds/seed_1.tres",
	"res://data/seeds/seed_2.tres",
	"res://data/seeds/seed_3.tres",
]

var profile: ControlProfileData = null
var seed_data: TestSeedData = null

## Seeded from the selected test seed, so enemy spawn positions repeat exactly
## for every control profile. Section 35.
var rng := RandomNumberGenerator.new()

var _profiles: Array[ControlProfileData] = []
var _seeds: Array[TestSeedData] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for path in PROFILE_PATHS:
		var res: ControlProfileData = load(path)
		if res != null:
			_profiles.append(res)
	for path in SEED_PATHS:
		var res: TestSeedData = load(path)
		if res != null:
			_seeds.append(res)


func get_profiles() -> Array[ControlProfileData]:
	return _profiles


func get_seeds() -> Array[TestSeedData]:
	return _seeds


## Select the profile and seed for the next run and start a telemetry record.
func configure(selected_profile: ControlProfileData, selected_seed: TestSeedData) -> void:
	profile = selected_profile
	seed_data = selected_seed
	rng.seed = selected_seed.seed_value
	Telemetry.begin_run(profile, seed_data)


## Apply the baseline profile and the first seed. Used when a scene is run
## directly and by the headless smoke test.
func configure_default() -> void:
	if _profiles.is_empty() or _seeds.is_empty():
		push_error("RunContext has no profile or seed resources to fall back to.")
		return
	configure(_profiles[0], _seeds[0])


## Guarantees a valid selection. Every system calls this instead of assuming the
## selection screen ran.
func ensure_configured() -> void:
	if profile == null or seed_data == null:
		configure_default()
