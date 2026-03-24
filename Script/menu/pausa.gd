extends Control

#@export var world: World

var option_menu_scene = preload("res://Scene/menu/option_menu.tscn")
var option_menu: Control

@onready var resume: Button = $Panel/VBoxContainer/resume
@onready var exit_btn: Button = $Panel/VBoxContainer/exit


# Called when the node enters the scene tree for the first time.
func _ready():
	resume.grab_focus()
	# 暂停时仍处理输入（父节点 PauseManager 已设 PROCESS_MODE_ALWAYS）
	process_mode = Node.PROCESS_MODE_ALWAYS

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
	if exit_btn:
		exit_btn.disabled = true
		exit_btn.text = "Guardando..."
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
	
