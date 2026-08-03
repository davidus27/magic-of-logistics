extends Control
## Result screen. Specification section 37.
##
## The screen shows objective results first and then asks the five test
## questions, in that order, because section 37 fixes it: the player should read
## what happened before scoring how it felt.

## The five questions of section 37, in order.
const QUESTIONS: PackedStringArray = [
	"I understood the active controls.",
	"I could control the cargo unit.",
	"I could control the defenders.",
	"I could use wizard spells during other actions.",
	"I want to play this control profile again.",
]

var _heading: Label = null
var _values: GridContainer = null
var _status: Label = null
var _save_button: Button = null

var _answers: PackedInt32Array = PackedInt32Array()
var _answer_buttons: Array = []


func _ready() -> void:
	_answers.resize(QUESTIONS.size())
	_answers.fill(0)
	_build()


func _build() -> void:
	var column := InkUi.build_overlay(self, 720.0, true)

	_heading = InkUi.label("Run finished", InkUi.FONT_SIZE_TITLE)
	column.add_child(_heading)
	column.add_child(InkUi.rule())

	_values = GridContainer.new()
	_values.columns = 2
	_values.add_theme_constant_override("h_separation", 28)
	_values.add_theme_constant_override("v_separation", 3)
	column.add_child(_values)

	column.add_child(InkUi.rule())
	column.add_child(InkUi.label("Five questions", InkUi.FONT_SIZE_HEADING))
	column.add_child(InkUi.label(
		"1 is no, 5 is yes.", InkUi.FONT_SIZE_SMALL, InkPalette.GRAY_MEDIUM
	))

	for index in QUESTIONS.size():
		var question := InkUi.label("%d.  %s" % [index + 1, QUESTIONS[index]], InkUi.FONT_SIZE_BODY)
		question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(question)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		column.add_child(row)

		var buttons: Array[Button] = []
		for score in range(1, 6):
			var button := InkUi.button(str(score))
			button.custom_minimum_size = Vector2(56.0, 0.0)
			button.pressed.connect(_on_score_pressed.bind(index, score))
			buttons.append(button)
			row.add_child(button)
		_answer_buttons.append(buttons)

	column.add_child(InkUi.rule())
	_save_button = InkUi.button("Save telemetry", InkUi.FONT_SIZE_HEADING)
	_save_button.pressed.connect(_on_save_pressed)
	column.add_child(_save_button)

	_status = InkUi.label("", InkUi.FONT_SIZE_SMALL, InkPalette.GRAY_MEDIUM)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)


## Fill in the objective results. Section 37.
func show_results(success: bool, run_seconds: float, cargo_health: int, threat: float) -> void:
	_heading.text = "Success" if success else "Failure"

	for child in _values.get_children():
		child.queue_free()
		_values.remove_child(child)

	var record := Telemetry.get_record()
	var seconds := int(run_seconds)
	var rows := [
		["Result", "Success" if success else "Failure"],
		["Control profile", "%s  %s" % [
			record.get("control_profile", "?"), record.get("control_profile_name", ""),
		]],
		["Test seed", str(record.get("test_seed", 0))],
		["Run time", "%d:%02d" % [seconds / 60.0, seconds % 60]],
		["Cargo health", "%d" % cargo_health],
		["Defender survivors", "not in this build"],
		["Defender orders", str(record.get("defender_orders", 0))],
		["Spell casts", str(record.get("spell_casts", 0))],
		["Pause count", str(record.get("pause_count", 0))],
		["Maximum threat", "%d" % int(threat)],
		["Distance travelled", "%.0f px" % float(record.get("distance_traveled", 0.0))],
	]
	for row in rows:
		var name_label := InkUi.label(row[0], InkUi.FONT_SIZE_BODY, InkPalette.GRAY_MEDIUM)
		name_label.custom_minimum_size = Vector2(220.0, 0.0)
		_values.add_child(name_label)
		_values.add_child(InkUi.label(row[1], InkUi.FONT_SIZE_BODY))

	_status.text = ""
	_save_button.disabled = false


func _on_score_pressed(question_index: int, score: int) -> void:
	_answers[question_index] = score
	SoundBank.play(SoundBank.UI_CONFIRM)
	var buttons: Array = _answer_buttons[question_index]
	for i in buttons.size():
		var chosen := i + 1 == score
		buttons[i].add_theme_stylebox_override(
			"normal",
			InkUi.box(InkPalette.INK if chosen else InkPalette.LINE_LIGHT, 0.10 if chosen else 0.0)
		)


func _on_save_pressed() -> void:
	# The result screen stores these answers in the telemetry file. Section 37.
	Telemetry.set_questionnaire(_answers)
	var path := Telemetry.write_file()
	if path.is_empty():
		_status.text = "The telemetry file could not be written. See the console."
		return
	_status.text = "Saved to %s" % ProjectSettings.globalize_path(path)
	_save_button.disabled = true
