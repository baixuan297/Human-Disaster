extends Control

## UI节点引用
@onready var username_input: LineEdit = $Panel/MarginContainer/VBoxContainer/username
@onready var password_input: LineEdit = $Panel/MarginContainer/VBoxContainer/password
@onready var remember_me: CheckBox = $Panel/MarginContainer/VBoxContainer/remember_me
@onready var login_button: Button = $Panel/MarginContainer/VBoxContainer/login_button
@onready var register_button: LinkButton = $Panel/MarginContainer/VBoxContainer/HBoxContainer/register_button
@onready var forget_password: LinkButton = $Panel/MarginContainer/VBoxContainer/HBoxContainer/forget_password
@onready var message_label: Label = $Panel/message
@onready var Login_panel: Panel = $Panel


## Scene instantiate
var register_scene  = preload("res://Scene/menu/LoginScene/register_scene.tscn")
var forget_password_scene = preload("res://Scene/menu/LoginScene/forget_passwordScene.tscn")

## 用户管理器
var user_manager: UserManager
## 全局消息
var gb_message: GlobalMessage

func _ready():
	user_manager = UserManager
	gb_message = GBMssage
		
	# 尝试自动登录 如果有保存的信息数据
	_try_auto_login()

	
func _on_login_button_pressed():
	var username = username_input.text.strip_edges()
	var password = password_input.text
	
	if username.is_empty() or password.is_empty():
		gb_message.show_message("Username and password cannot be empty!", "error")
		return
		
	# 登录加载
	gb_message.show_message("Logging in...", "success")
	await get_tree().create_timer(0.5).timeout
	
	# 尝试登录
	var result = user_manager.user_login(username, password)
	
	# 如果返回正确，那么登录反之错误
	if result:
		gb_message.show_message("Login successful!", "success")
		if remember_me.button_pressed:
			user_manager.save_credentials(username, password)
		else :
			user_manager.clear_credentials()
		await get_tree().create_timer(0.5).timeout
		gb_message.show_message("Welcome User" + username, "success")
		await get_tree().create_timer(0.5).timeout
		SceneManager.change_scene("main_menu")
		return
	# 如果返回的结果是false，那么证明用户名或者密码错误
	else :
		gb_message.show_message("Incorrect password or username", "error")

func _on_register_button_pressed():
	var register_instan = register_scene.instantiate()
	add_child(register_instan)

func _try_auto_login():
	var saved_creds = user_manager.load_credentials()
	if saved_creds:
		username_input.text = saved_creds.username
		password_input.text = saved_creds.password
		remember_me.button_pressed = true


func _on_close_button_pressed() -> void:
	queue_free()


func _on_forget_password_pressed() -> void:
	var forgetPswdScene = forget_password_scene.instantiate()
	add_child(forgetPswdScene)

func toogle_login_menu(state: bool):
	if state:
		Login_panel.show()
	else :
		Login_panel.hide()
