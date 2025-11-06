extends Control

## Node
# Input Node
@onready var mail_input: LineEdit = $Panel/MarginContainer/VBoxContainer/mail/mail_input
@onready var verifi_code_input: LineEdit = $Panel/MarginContainer/VBoxContainer/veriCode/veriInput_container/verifi_code_input
@onready var password_input: LineEdit = $Panel/MarginContainer/VBoxContainer/password/password_input
@onready var confirm_password_input: LineEdit = $Panel/MarginContainer/VBoxContainer/VBoxContainer/confirm_password_input

# Progress Bar
@onready var password_strength_bar: ProgressBar = $Panel/MarginContainer/VBoxContainer/passwordStrength_container/password_strength_bar
# Label
@onready var pswd_strength_label: Label = $Panel/MarginContainer/VBoxContainer/passwordStrength_container/pswd_strength_label
@onready var pswd_not_match_label: Label = $Panel/MarginContainer/VBoxContainer/VBoxContainer/confirm_pswd_label/pswd_not_match_label

# Button
@onready var register: Button = $Panel/MarginContainer/VBoxContainer/register
@onready var get_code_button: Button = $Panel/MarginContainer/VBoxContainer/veriCode/veriInput_container/verifi_code_input/get_code_button
# Check Box
@onready var agreement_checkbox: CheckBox = $Panel/MarginContainer/VBoxContainer/VBoxContainer2/agreement/agreement_checkbox
# Wrong Label Node
@onready var mail_wrong_label: Label = $Panel/MarginContainer/VBoxContainer/mail/mail_Wrong_label
@onready var veri_code_wrong_label: Label = $Panel/MarginContainer/VBoxContainer/veriCode/veriCode_Wrong_label
@onready var password_wrong_label: Label = $Panel/MarginContainer/VBoxContainer/password/password_Wrong_label
@onready var confirm_password_wrong_label: Label = $Panel/MarginContainer/VBoxContainer/VBoxContainer/confirmPassword_Wrong_label
@onready var agreement_wrong_label: Label = $Panel/MarginContainer/VBoxContainer/VBoxContainer2/agreement_Wrong_label


## 变量
var pswd_match: bool = false
var veriCode_match: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	if pswd_match && veriCode_match:
		register.disabled = false

func _on_register_pressed() -> void:
	if !agreement_checkbox.pressed:
		return
	#var username = username_input.text.strip_edges()
	#var password_input = password_input.text
	#
	#if username.is_empty() or password_input.is_empty():
		#_show_message("用户名和密码不能为空！", false)
		#return
	#
	#if username.length() < 3:
		#_show_message("用户名至少需要3个字符！", false)
		#return
	#
	#if password_input.length() < 6:
		#_show_message("密码至少需要6个字符！", false)
		#return
	#
	#message_label.text = "注册中..."
	#
	## 先注册到本地
	#var local_result = user_manager.register_local(username, password_input)
	#
	#if not local_result:
		#_show_message("注册失败：用户名已存在！", false)
		#return
	#
	## 同时注册到服务器
	#var server_result = await user_manager.register_server(username, password_input)
	#
	#if server_result:
		#_show_message("注册成功！已同步到服务器", true)
	#else:
		#_show_message("注册成功！（服务器同步失败）", true)
	#
	#if remember_me.button_pressed:
		#user_manager.save_credentials(username, password_input)

func _on_password_text_changed(new_text: String) -> void:
	match check_password_strength(new_text):
		"Weak":
			password_strength_bar.value = 20
			set_bar_color(Color.RED)
			pswd_strength_label.text = "Weak"
		"Medium":
			password_strength_bar.value = 50
			set_bar_color(Color.YELLOW)
			pswd_strength_label.text = "Medium"
		"Strong":
			password_strength_bar.value = 100
			set_bar_color(Color.GREEN)
			pswd_strength_label.text = "Strong"
		_:
			password_strength_bar.value = 0
			set_bar_color(Color.RED)
			pswd_strength_label.text = "Weak"

func set_bar_color(bar_color: Color):
	var fill: StyleBoxFlat = password_strength_bar.get_theme_stylebox("fill").duplicate()
	
	fill.bg_color = bar_color
	password_strength_bar.add_theme_stylebox_override("fill", fill)


func check_password_strength(password_text: String) -> String:
	var score := 0

	# 正则表达
	var uppercase := RegEx.new()
	uppercase.compile("[A-Z]")
	var lowercase := RegEx.new()
	lowercase.compile("[a-z]")
	var digit := RegEx.new()
	digit.compile("\\d")
	var special := RegEx.new()
	special.compile("[!@#\\$%\\^&\\*(),.?\":{}|<>/-]")
	
	# 条件判断
	if password_text.length() >= 8: 
		score += 1
	if password_text.length() >= 12: 
		score += 1
	if uppercase.search(password_text): 
		score += 1
		#print("444")
	if lowercase.search(password_text): 
		score += 1
		#print("333")
	if digit.search(password_text): 
		score += 1
		#print("222")
	if special.search(password_text): 
		score += 1 
		#print("111")
	
	# 根据得分返回强度
	match score:
		0,1,2:
			return "Weak"
		3,4,5:
			return "Medium"
		6:
			return "Strong"
	return "Unknown"

func _on_back_pressed() -> void:
	self.queue_free()


@warning_ignore("unused_parameter")
func _on_confirm_password_editing_toggled(toggled: bool) -> void:
	if confirm_password_input.text == password_input.text:
		pswd_match = true
		pswd_not_match_label.visible = false
	else:
		pswd_not_match_label.visible = true
		pswd_match = false
		

func _on_mail_input_text_changed(new_text: String) -> void:
	if new_text.contains("@") && new_text.contains("."):
		get_code_button.disabled = false
		
func _on_get_code_button_pressed() -> void:
	pass # Replace with function body.

func _on_verifi_code_input_text_changed(new_text: String) -> void:
	if new_text == "123456":
		veriCode_match = true
