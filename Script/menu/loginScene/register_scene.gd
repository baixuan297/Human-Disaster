extends Control

## 注册场景 — 邮箱验证 + 密码 + 用户协议
##
## 流程：1. 输入邮箱 → 2. 点击「获取验证码」→ 3. 输入验证码并失焦触发验证
##      4. 输入密码、确认密码、勾选协议 → 5. 点击注册
## API：send_verification_code → verify_email → (UserManager) register

# ── 节点引用 ─────────────────────────────────────────────────────────────────
@onready var mail_input: LineEdit = $Panel/MarginContainer/VBoxContainer/mail/mail_input
@onready var verifi_code_input: LineEdit = $Panel/MarginContainer/VBoxContainer/veriCode/veriInput_container/verifi_code_input
@onready var password_input: LineEdit = $Panel/MarginContainer/VBoxContainer/password/password_input
@onready var confirm_password_input: LineEdit = $Panel/MarginContainer/VBoxContainer/VBoxContainer/confirm_password_input
@onready var password_strength_bar: ProgressBar = $Panel/MarginContainer/VBoxContainer/passwordStrength_container/password_strength_bar
@onready var pswd_strength_label: Label = $Panel/MarginContainer/VBoxContainer/passwordStrength_container/pswd_strength_label
@onready var pswd_not_match_label: Label = $Panel/MarginContainer/VBoxContainer/VBoxContainer/confirm_pswd_label/pswd_not_match_label
@onready var register: Button = $Panel/MarginContainer/VBoxContainer/register
@onready var get_code_button: Button = $Panel/MarginContainer/VBoxContainer/veriCode/veriInput_container/verifi_code_input/get_code_button
@onready var agreement_checkbox: CheckBox = $Panel/MarginContainer/VBoxContainer/VBoxContainer2/agreement/agreement_checkbox

# ── 状态 ───────────────────────────────────────────────────────────────────
var pswd_match: bool = false
var veriCode_match: bool = false
var agmt_match: bool = false

# ── 全局 ───────────────────────────────────────────────────────────────────
var userManager: UserManager
var gb_message: GlobalMessage
var apiManager: ApiManager

# ── 验证码冷却 ─────────────────────────────────────────────────────────────
var code_cooldown: float = 0.0
var _cooldown_timer: Timer = null
const CODE_COOLDOWN_TIME: float = 60.0
const VERIFY_CODE_LEN: int = 6

func _ready() -> void:
	userManager = UserManager
	gb_message = GBMssage
	apiManager = ApiManager

# ── 邮箱 ───────────────────────────────────────────────────────────────────
func _on_mail_input_text_changed(new_text: String) -> void:
	var email_regex = RegEx.new()
	email_regex.compile(r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$")
	var valid = email_regex.search(new_text) != null
	get_code_button.disabled = not valid or code_cooldown > 0
	veriCode_match = false
	update_register_button()

# ── 发送验证码 ──────────────────────────────────────────────────────────────
func _on_get_code_button_pressed() -> void:
	var email := mail_input.text.strip_edges()
	if email.is_empty():
		gb_message.show_message("请输入邮箱地址", "error")
		return

	gb_message.show_message("正在发送验证码...", "warning")
	get_code_button.disabled = true
	apiManager.send_verification_code(email, _on_verification_code_sent)


func _on_verification_code_sent(success: bool, data) -> void:
	if success:
		gb_message.show_message("验证码已发送到您的邮箱", "success")
		_start_code_cooldown()
	else:
		var msg := "发送失败"
		if data is Dictionary:
			msg = data.get("message", data.get("detail", msg))
		gb_message.show_message("发送失败: " + str(msg), "error")
		get_code_button.disabled = false


func _start_code_cooldown() -> void:
	code_cooldown = CODE_COOLDOWN_TIME
	get_code_button.disabled = true
	if _cooldown_timer:
		_cooldown_timer.queue_free()
	_cooldown_timer = Timer.new()
	add_child(_cooldown_timer)
	_cooldown_timer.wait_time = 1.0
	_cooldown_timer.timeout.connect(_on_cooldown_tick)
	_cooldown_timer.start()


func _on_cooldown_tick() -> void:
	code_cooldown -= 1.0
	if code_cooldown <= 0:
		code_cooldown = 0
		if _cooldown_timer:
			_cooldown_timer.queue_free()
			_cooldown_timer = null
		var email_regex = RegEx.new()
		email_regex.compile(r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$")
		get_code_button.disabled = email_regex.search(mail_input.text) == null

# ── 验证码校验（失焦时触发）──────────────────────────────────────────────────
func _on_verifi_code_input_editing_toggled(toggled_on: bool) -> void:
	if toggled_on:
		return
	var email := mail_input.text.strip_edges()
	var code := verifi_code_input.text.strip_edges()
	if code.length() != VERIFY_CODE_LEN:
		if code.length() > 0:
			gb_message.show_message("验证码为 6 位数字", "error")
		return
	if email.is_empty():
		return

	apiManager.verify_email(email, code, _on_verificate)


func _on_verificate(success: bool, data) -> void:
	if success:
		gb_message.show_message("邮箱验证成功", "success")
		veriCode_match = true
	else:
		veriCode_match = false
		var msg := "验证失败"
		if data is Dictionary:
			msg = data.get("message", data.get("detail", msg))
		gb_message.show_message(str(msg), "error")
	update_register_button()

# ── 密码强度 ────────────────────────────────────────────────────────────────
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


func set_bar_color(bar_color: Color) -> void:
	var fill: StyleBoxFlat = password_strength_bar.get_theme_stylebox("fill").duplicate()
	fill.bg_color = bar_color
	password_strength_bar.add_theme_stylebox_override("fill", fill)


func check_password_strength(password_text: String) -> String:
	var score := 0
	var uppercase := RegEx.new()
	uppercase.compile("[A-Z]")
	var lowercase := RegEx.new()
	lowercase.compile("[a-z]")
	var digit := RegEx.new()
	digit.compile("\\d")
	var special := RegEx.new()
	special.compile("[!@#\\$%\\^&\\*(),.?\":{}|<>/-]")
	if password_text.length() >= 8:
		score += 1
	if password_text.length() >= 12:
		score += 1
	if uppercase.search(password_text):
		score += 1
	if lowercase.search(password_text):
		score += 1
	if digit.search(password_text):
		score += 1
	if special.search(password_text):
		score += 1
	match score:
		0, 1, 2:
			return "Weak"
		3, 4, 5:
			return "Medium"
		6:
			return "Strong"
		_:
			return "Unknown"

# ── 确认密码 ────────────────────────────────────────────────────────────────
func _on_confirm_password_input_text_changed(new_text: String) -> void:
	if new_text == password_input.text:
		pswd_match = true
		pswd_not_match_label.visible = false
	else:
		pswd_not_match_label.visible = true
		pswd_match = false
	update_register_button()

# ── 用户协议（支持勾选/取消）──────────────────────────────────────────────────
func _on_agreement_checkbox_pressed() -> void:
	agmt_match = agreement_checkbox.button_pressed
	update_register_button()

# ── 注册 ───────────────────────────────────────────────────────────────────
func _on_register_pressed() -> void:
	if not agreement_checkbox.button_pressed:
		gb_message.show_message("请先同意用户协议", "error")
		return

	var mail := mail_input.text.strip_edges()
	var password := password_input.text
	if mail.is_empty():
		gb_message.show_message("请输入邮箱", "error")
		return
	if password.length() < 8:
		gb_message.show_message("密码至少 8 位", "error")
		return
	if not pswd_match:
		gb_message.show_message("两次密码不一致", "error")
		return
	if not veriCode_match:
		gb_message.show_message("请先完成邮箱验证", "error")
		return

	register.disabled = true
	userManager.user_register(mail, password, mail, _on_register_done)


func _on_register_done(success: bool, data) -> void:
	update_register_button()
	if success:
		gb_message.show_message("注册成功", "success")
		var t := get_tree().create_timer(1.0)
		t.timeout.connect(func(): queue_free(), CONNECT_ONE_SHOT)
	else:
		var msg := "注册失败"
		if data is Dictionary:
			msg = data.get("message", data.get("detail", msg))
		gb_message.show_message(str(msg), "error")


func update_register_button() -> void:
	register.disabled = not (pswd_match and veriCode_match and agmt_match)

func _on_back_pressed() -> void:
	queue_free()
