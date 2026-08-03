extends Node
## Placeholder sounds. Specification section 31.
##
## Each player action has one clear sound. The files are the mono placeholders
## from the asset pack; the MVP does not require music.

## Identifiers used by the call sites. Section 31.
const SPEED_CHANGE := &"speed_change"
const DEFENDER_ORDER := &"defender_order"
const SPELL_CAST := &"spell_cast"
const CARGO_DAMAGE := &"cargo_damage"
const PORTAL_CAST := &"portal_cast"
const UI_CONFIRM := &"ui_confirm"

const SOUND_PATHS := {
	SPEED_CHANGE: "res://assets/audio/cargo_speed_click.wav",
	DEFENDER_ORDER: "res://assets/audio/defender_order_paper_tap.wav",
	SPELL_CAST: "res://assets/audio/spell_cast_ink_stroke.wav",
	CARGO_DAMAGE: "res://assets/audio/cargo_damage_paper_tear.wav",
	PORTAL_CAST: "res://assets/audio/portal_cast_low_tone_4s.wav",
	# The pack has no separate interface sound, so the short click stands in.
	UI_CONFIRM: "res://assets/audio/cargo_speed_click.wav",
}

## Set false to silence the game during headless test runs.
var enabled: bool = true

var _players: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for id: StringName in SOUND_PATHS:
		var stream: AudioStream = load(SOUND_PATHS[id])
		if stream == null:
			push_warning("SoundBank could not load %s." % SOUND_PATHS[id])
			continue
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.name = String(id)
		add_child(player)
		_players[id] = player


## Play a one-shot sound. An unknown identifier is ignored rather than fatal, so
## a new call site never breaks a test run.
func play(id: StringName) -> void:
	if not enabled:
		return
	var player: AudioStreamPlayer = _players.get(id)
	if player == null:
		return
	player.play()


## Start the continuous portal cast tone. Section 31.
func start_loop(id: StringName) -> void:
	play(id)


func stop_loop(id: StringName) -> void:
	var player: AudioStreamPlayer = _players.get(id)
	if player != null:
		player.stop()
