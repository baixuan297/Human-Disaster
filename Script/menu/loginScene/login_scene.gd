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

func _ready():
	user_manager = UserManager
	
	#password_input.secret = true
	
	# 尝试自动登录 如果有保存的信息数据
	_try_auto_login()
	
func _on_login_button_pressed():
	var username = username_input.text.strip_edges()
	var password = password_input.text
	
	if username.is_empty() or password.is_empty():
		_show_message("Username and password cannot be empty!", false)
		return
		
	message_label.text = "Logging in..."
	
	# 先尝试本地登录
	var local_result = user_manager.login_local(username, password)
	
	if local_result:
		_show_message("Login successful!", true)
		if remember_me.button_pressed:
			user_manager.save_credentials(username, password)
		_show_message("Welcome User" + username, true)
		await get_tree().create_timer(1.0).timeout
		SceneManager.change_scene("main_menu")
		return
	
	# 如果本地失败，尝试服务器登录
	var server_result = await user_manager.login_server(username, password)
	
	if server_result:
		_show_message("服务器登录成功！", true)
		# 同步到本地
		user_manager.save_user_local(username, password)
		if remember_me.button_pressed:
			user_manager.save_credentials(username, password)
		_show_message("欢迎用户", username)
	else:
		_show_message("登录失败：用户名或密码错误！", false)

func _on_register_button_pressed():
	var register_instan = register_scene.instantiate()
	add_child(register_instan)

func _try_auto_login():
	var saved_creds = user_manager.load_credentials()
	if saved_creds:
		username_input.text = saved_creds.username
		password_input.text = saved_creds.password
		remember_me.button_pressed = true

func _show_message(message: String, success: bool):
	message_label.visible = true
	message_label.text = message
	message_label.modulate = Color.GREEN if success else Color.RED
	
	await get_tree().create_timer(2.0).timeout
	if message_label.text == message:
		message_label.text = ""
		message_label.visible = false


func _on_close_button_pressed() -> void:
	pass # Replace with function body.


func _on_forget_password_pressed() -> void:
	var forgetPswdScene = forget_password_scene.instantiate()
	add_child(forgetPswdScene)

func toogle_login_menu(state: bool):
	if state:
		Login_panel.hide()
	else :
		Login_panel.show()
