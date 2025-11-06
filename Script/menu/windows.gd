extends Control

@onready var option_button = $HBoxContainer/OptionButton

const WINDOW_MODE_ARRY : Array[String] = [
	"Full-Screen",
	"Window Mode",
	"Borderless Window",
	"Borderless Fullscreen"
]

# Called when the node enters the scene tree for the first time.
func _ready():
	add_window_mode_items()
	option_button.item_selected.connect(on_window_mode_selected)
	load_data()
	
func load_data():
	on_window_mode_selected(SettingData.get_window_mode_index())
	option_button.select(SettingData.get_window_mode_index())

func add_window_mode_items():
	for window_mode in WINDOW_MODE_ARRY:
		option_button.add_item(window_mode)

func on_window_mode_selected(index : int):
	SettingSignal.emit_on_window_mode_selected(index)
	match index:
		0: # Full-Screen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		1: # Window Mode
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		2: # Borderless Window
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		3: # Borderless Fullscreen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
