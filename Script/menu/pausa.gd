extends Control

#@export var world: World

var option_menu_scene = preload("res://Scene/menu/option_menu.tscn")
var option_menu: Control

@onready var resume: Button = $Panel/VBoxContainer/resume
@onready var exit_btn: Button = $Panel/VBoxContainer/exit
@onready var setting_btn: Button = $Panel/VBoxContainer/setting


# Called when the node enters the scene tree for the first time.
func _ready():
	resume.grab_focus()
	# 暂停时仍处理输入（父节点 PauseManager 已设 PROCESS_MODE_ALWAYS）
	process_mode = Node.PROCESS_MODE_ALWAYS


## 由 PauseManager 在 ui_cancel 时优先调用：若设置菜单叠在暂停之上，先关这一层
func try_close_top_overlay() -> bool:
	if option_menu != null and is_instance_valid(option_menu):
		_close_option_menu_only()
		return true
	return false


func _exit_tree() -> void:
	# 设置界面挂在 root 上与 pausa 同级，避免暂停关闭后残留
	if option_menu != null and is_instance_valid(option_menu):
		option_menu.queue_free()
		option_menu = null


func _close_option_menu_only() -> void:
	if option_menu != null and is_instance_valid(option_menu):
		if option_menu.exit_option_menu.is_connected(_on_option_menu_exit):
			option_menu.exit_option_menu.disconnect(_on_option_menu_exit)
		option_menu.queue_free()
	option_menu = null
	if is_instance_valid(setting_btn):
		setting_btn.grab_focus()
	elif is_instance_valid(resume):
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
	if exit_btn:
		exit_btn.disabled = true
		exit_btn.text = "Guardando..."
	PauseManager.exit_to_main_menu()

func _on_setting_pressed():
	if option_menu != null and is_instance_valid(option_menu):
		return
	option_menu = option_menu_scene.instantiate()
	option_menu.exit_option_menu.connect(_on_option_menu_exit)
	option_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	$"..".add_child(option_menu)


func _on_option_menu_exit() -> void:
	# 从设置返回暂停：只关掉选项层，不要当作「继续游戏」
	_close_option_menu_only()
	
