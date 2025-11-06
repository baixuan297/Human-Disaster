extends Control

@onready var option_info = $MarginContainer/VBoxContainer/option_informacion
@onready var back = $MarginContainer/VBoxContainer/back
var previour_scene = ""

signal exit_option_menu

func _ready():
	back.button_down.connect(on_back_pressed)
	option_info.Exit_Options_Menu.connect(on_back_pressed)
	set_process(false)
	previour_scene = get_tree().get_current_scene().get_name()
	print(previour_scene)

	
func on_back_pressed():
	if previour_scene == "Main_menu" or previour_scene == "World":
		exit_option_menu.emit()
		SettingSignal.emit_set_setting_dictionary(SettingData.create_storage_dictionary())
		set_process(false)
	elif previour_scene == "Option_menu":
		get_tree().change_scene_to_file("res://Scene/map/world.tscn")
