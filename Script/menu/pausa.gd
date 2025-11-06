extends Control

#@export var world: World

var option_menu_scene = preload("res://Scene/menu/option_menu.tscn")
var option_menu: Control

@onready var resume: Button = $Panel/VBoxContainer/resume


# Called when the node enters the scene tree for the first time.
func _ready():
	resume.grab_focus()

#func _on_pause_toggled(is_pause : bool):
	#if is_pause:
		#Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	#else:
		#if not PauseManager.is_paused:
			#Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		#self.queue_free() # **
		
		#show()
	#else:
		#hide()

func _on_resume_pressed():
	#world.game_paused = false
	PauseManager.close_pause_menu()
	

func _on_exit_pressed():
	#world.game_paused = false
	#SceneManager.change_scene("main_menu")
	#SceneManager.change_scene_to_file("res://Scene/menu/main_menu3d.tscn")
	PauseManager.exit_to_main_menu()

func _on_setting_pressed():
	#world.game_paused = true
	#Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	option_menu = option_menu_scene.instantiate()
	option_menu.connect("exit_option_menu", _on_option_menu_exit)
	option_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	$"..".add_child(option_menu)

func _on_option_menu_exit():
	option_menu.queue_free()
	_on_resume_pressed()
	
