extends Control

@onready var option_button = $HBoxContainer/OptionButton

const RESOLUTION_DICTIONARY : Dictionary = {
	"1920 x 1080" : Vector2i(1920, 1080),
	"1152 x 648" : Vector2i(1152, 648),
	"1280 x 720" : Vector2i(1280, 720)
}

# Called when the node enters the scene tree for the first time.
func _ready():
	option_button.item_selected.connect(on_resolution_selected)
	add_resolution_items()
	load_data()

func load_data():
	on_resolution_selected(SettingData.get_resolution_mode_index())
	option_button.select(SettingData.get_resolution_mode_index())

func add_resolution_items():
	for resolution in RESOLUTION_DICTIONARY:
		option_button.add_item(resolution)

func on_resolution_selected(index : int):
	# 保存分辨率
	SettingSignal.emit_on_resolution_mode_selected(index)
	DisplayServer.window_set_size(RESOLUTION_DICTIONARY.values()[index])
