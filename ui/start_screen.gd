extends Control
## Start screen. Specification section 8.1.
##
## The first screen the player sees. It states the run objective in one paragraph
## and lets the player begin; there is no profile or seed to choose now that the
## control-profile experiment and testing apparatus are gone.

signal start_pressed

var _start_button: Button = null


func _ready() -> void:
	_build()


func _build() -> void:
	var column := InkUi.build_overlay(self, 640.0, true)

	column.add_child(InkUi.label("Fantasy Convoy", InkUi.FONT_SIZE_TITLE))
	column.add_child(InkUi.label(
		"Move the cargo unit from the start area to the final portal. Keep the" +
		" cargo health above zero. Command four defenders and a wizard to help it" +
		" survive the road.",
		InkUi.FONT_SIZE_BODY,
		InkPalette.GRAY_MEDIUM
	))
	column.add_child(InkUi.rule())

	_start_button = InkUi.button("Start", InkUi.FONT_SIZE_HEADING)
	_start_button.pressed.connect(_on_start_pressed)
	column.add_child(_start_button)


func _on_start_pressed() -> void:
	SoundBank.play(SoundBank.UI_CONFIRM)
	start_pressed.emit()
