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

	gb_message.show_message("Logging in...", "success")
	login_button.disabled = true

	user_manager.user_login(username, password, func(success, _data = null):
		login_button.disabled = false
		if success:
			gb_message.show_message("Login successful!", "success")
			if remember_me.button_pressed:
				user_manager.save_credentials(username, password)
			else:
				user_manager.clear_credentials()
			gb_message.show_message("Welcome " + username, "success")
			await get_tree().create_timer(0.5).timeout
			SceneManager.change_scene("main_menu")
		else:
			var msg := "Incorrect password or username"
			if _data is Dictionary and _data.has("detail"):
				var d = _data["detail"]
				msg = str(d) if d is String else str(d)
			gb_message.show_message(msg, "error")
	)

func _on_register_button_pressed():
	var register_instan = register_scene.instantiate()
	add_child(register_instan)

func _try_auto_login():
	var saved_creds := user_manager.load_credentials()
	if not saved_creds.is_empty():
		username_input.text = saved_creds.get("username", "")
		password_input.text = saved_creds.get("password", "")
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
