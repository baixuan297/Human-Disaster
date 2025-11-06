extends Control

@onready var salir = $Button
var previor_scene = ""

signal exit_creditos_menu

func _ready():
	salir.button_down.connect(on_back_pressed)
	set_process(false)
	previor_scene = get_tree().get_current_scene().get_name()
	
func on_back_pressed():
	if previor_scene == "Main_menu":
		exit_creditos_menu.emit()
		SettingSignal.emit_set_setting_dictionary(SettingData.create_storage_dictionary())
		set_process(false)
	elif previor_scene == "Option_menu":
		get_tree().change_scene_to_file("res://Scene/map/world.tscn")
