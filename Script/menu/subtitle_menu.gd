extends Control

@onready var checkbutton = $HBoxContainer/CheckButton
@onready var buttonstate = $HBoxContainer/Button_state

# Called when the node enters the scene tree for the first time.
func _ready():
	checkbutton.toggled.connect(on_subtitles_toggled)
	load_data()
	
func load_data():
	if SettingData.get_subtitles_set() != true:
		checkbutton.button_pressed = false
	else:
		checkbutton.button_pressed = true
	
	set_label_text(SettingData.get_subtitles_set())

func set_label_text(pressed : bool):
	if pressed != true:
		buttonstate.text = "Off"
	else:
		buttonstate.text = "On"

func on_subtitles_toggled(pressed : bool):
	set_label_text(pressed)
	SettingSignal.emit_on_subtitles_toggled(pressed)
