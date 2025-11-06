extends Control

@onready var audio_name = $HBoxContainer/Audio_name
@onready var hslider = $HBoxContainer/HSlider
@onready var audio_num = $HBoxContainer/Audio_num

@export_enum("Master", "Music", "Sfx") var bus_name : String

var bus_index : int = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	hslider.value_changed.connect(on_value_changed)
	get_bus()
	load_data()
	set_name_label()
	set_slider_value()
	
# 加载保存的数据
func load_data() -> void:
	match bus_name:
		"Master":
			on_value_changed(SettingData.get_master_volume())
		"Music":
			on_value_changed(SettingData.get_music_volume())
		"Sfx":
			on_value_changed(SettingData.get_sfx_volume())
	
func set_name_label():
	audio_name.text = str(bus_name) + " Volume"

func set_num_label():
	audio_num.text = str(hslider.value * 100) + "%"

func get_bus():
	bus_index = AudioServer.get_bus_index(bus_name)
	
func set_slider_value():
	hslider.value = db_to_linear(AudioServer.get_bus_volume_db(bus_index))
	set_num_label()

func on_value_changed(value : float):
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))
	set_num_label()
	
	match bus_index:
		0:
			SettingSignal.emit_on_master_sound_set(value)
		1:
			SettingSignal.emit_on_music_sound_set(value)
		2:
			SettingSignal.emit_on_sfx_sound_set(value)
