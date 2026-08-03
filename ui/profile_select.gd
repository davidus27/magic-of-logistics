extends Control
## Control profile selection screen. Specification section 8.1.
##
## The player selects one control profile before the run, and can also select a
## fixed test seed. A profile whose control method does not exist yet is shown
## disabled rather than hidden, so the test plan of section 24 stays visible.

signal profile_confirmed(profile: ControlProfileData, seed_data: TestSeedData)

var _profile: ControlProfileData = null
var _seed: TestSeedData = null

var _profile_buttons: Array[Button] = []
var _seed_buttons: Array[Button] = []
var _start_button: Button = null


func _ready() -> void:
	_build()
	_refresh()


func _build() -> void:
	var column := InkUi.build_overlay(self, 760.0, true)

	column.add_child(InkUi.label("Fantasy Convoy", InkUi.FONT_SIZE_TITLE))
	column.add_child(InkUi.label(
		"Control test. Choose a control profile and a test seed.",
		InkUi.FONT_SIZE_BODY,
		InkPalette.GRAY_MEDIUM
	))
	column.add_child(InkUi.rule())

	column.add_child(InkUi.label("Control profile", InkUi.FONT_SIZE_HEADING))
	for profile in RunContext.get_profiles():
		var button := InkUi.button("")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(0.0, 62.0)
		var suffix := "" if profile.implemented else "   [not in this build]"
		button.text = "%s  -  %s%s\n%s" % [
			profile.id, profile.test_purpose, suffix, profile.description,
		]
		button.disabled = not profile.implemented
		if profile.implemented:
			button.pressed.connect(_on_profile_pressed.bind(profile))
		button.set_meta("profile_id", profile.id)
		_profile_buttons.append(button)
		column.add_child(button)

	column.add_child(InkUi.rule())
	column.add_child(InkUi.label("Test seed", InkUi.FONT_SIZE_HEADING))
	column.add_child(InkUi.label(
		"The seed fixes enemy spawn positions. Use the same seed to compare profiles.",
		InkUi.FONT_SIZE_SMALL,
		InkPalette.GRAY_MEDIUM
	))

	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 8)
	column.add_child(seed_row)
	for seed_data in RunContext.get_seeds():
		var button := InkUi.button(seed_data.display_name)
		button.pressed.connect(_on_seed_pressed.bind(seed_data))
		_seed_buttons.append(button)
		seed_row.add_child(button)

	column.add_child(InkUi.rule())
	_start_button = InkUi.button("Start", InkUi.FONT_SIZE_HEADING)
	_start_button.pressed.connect(_on_start_pressed)
	column.add_child(_start_button)

	# Preselect the baseline profile and the first seed, which section 23 names as
	# the profile the first build must use.
	var profiles := RunContext.get_profiles()
	var seeds := RunContext.get_seeds()
	for profile in profiles:
		if profile.implemented:
			_profile = profile
			break
	if not seeds.is_empty():
		_seed = seeds[0]


func _on_profile_pressed(profile: ControlProfileData) -> void:
	_profile = profile
	SoundBank.play(SoundBank.UI_CONFIRM)
	_refresh()


func _on_seed_pressed(seed_data: TestSeedData) -> void:
	_seed = seed_data
	SoundBank.play(SoundBank.UI_CONFIRM)
	_refresh()


func _on_start_pressed() -> void:
	if _profile == null or _seed == null:
		return
	SoundBank.play(SoundBank.UI_CONFIRM)
	profile_confirmed.emit(_profile, _seed)


func _refresh() -> void:
	for button in _profile_buttons:
		var chosen: bool = _profile != null and str(button.get_meta("profile_id")) == _profile.id
		button.add_theme_stylebox_override(
			"normal", InkUi.box(InkPalette.INK if chosen else InkPalette.LINE_LIGHT, 0.06 if chosen else 0.0)
		)
	for i in _seed_buttons.size():
		var seeds := RunContext.get_seeds()
		var chosen: bool = _seed != null and i < seeds.size() and seeds[i].id == _seed.id
		_seed_buttons[i].add_theme_stylebox_override(
			"normal", InkUi.box(InkPalette.INK if chosen else InkPalette.LINE_LIGHT, 0.06 if chosen else 0.0)
		)
	if _start_button != null:
		_start_button.disabled = _profile == null or _seed == null
