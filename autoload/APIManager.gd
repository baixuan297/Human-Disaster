extends Node

# API配置 - 修改为你的虚拟机IP和端口
const API_BASE_URL = "http://192.168.1.100:8000"
# 令牌
var jwt_token := ""
# HTTP请求节点
var http_request: HTTPRequest

var timeout_sec := 10.0

func _ready():
	# 创建HTTP请求节点
	http_request = HTTPRequest.new()
	add_child(http_request)
	#http_request.connect("request_completed", _on_request_completed)

# 通用HTTP请求方法
func make_request(endpoint: String, method: int = HTTPClient.METHOD_GET, data: Dictionary = {}, callback: Callable = Callable()) -> void:
	var url = API_BASE_URL + endpoint
	#var headers = [
		#"Content-Type: application/json"]
		#"Authorization: Bearer " + jwt_token]
	var headers = PackedStringArray(["Content-Type: application/json"])
	headers.append("Authorization: Bearer %s" % jwt_token)
	var body = ""
	
	if method != HTTPClient.METHOD_GET and not data.is_empty():
		body = JSON.stringify(data)
	
	# 连接请求完成信号
	if http_request.request_completed.is_connected(_on_request_completed):
		http_request.request_completed.disconnect(_on_request_completed)
	
	http_request.request_completed.connect(_on_request_completed.bind(callback))
	
	var error = http_request.request(url, headers, method, body)
	
	if error != OK:
		print("HTTP请求错误: ", error)
		if callback.is_valid():
			callback.call(false, {"message": "请求失败"})
			
	var timer := Timer.new()
	timer.wait_time = timeout_sec
	timer.one_shot = true
	add_child(timer)
	timer.start()
	
	timer.timeout.connect(func():
		if http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
			print("请求超时，取消请求: ", url)
			http_request.cancel_request()
			if callback.is_valid():
				callback.call(false, {"message": "请求超时"})
		timer.queue_free()
	)

# 请求完成回调
func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, callback: Callable) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		print("请求失败: ", result)
		if callback.is_valid():
			callback.call(false, {"message": "网络错误"})
		return
	
	var response_text = body.get_string_from_utf8()
	print("reponse text is: " + response_text)
	var json = JSON.new()
	var parse_error = json.parse(response_text)
	#var parse_error = JSON.parse_string(response_text)
	
	if parse_error != OK:
		print("JSON解析错误: ", parse_error)
		if callback.is_valid():
			callback.call(false, {"message": "数据解析错误"})
		return
	
	var response_data = json.data
	
	var success = response_code >= 200 and response_code < 300
	if success and typeof(response_data) == TYPE_DICTIONARY and response_data.has("access_token"):
		jwt_token = response_data["access_token"]
	
	if callback.is_valid():
		callback.call(success, response_data)

## === 用户相关API ===
#
## 检查密码强度
#func check_password_strength(password: String, callback: Callable) -> void:
	#make_request("/check_password_strength", HTTPClient.METHOD_POST, {"password": password}, callback)
#
## 发送验证码
#func send_verification_code(email: String, callback: Callable) -> void:
	#make_request("/send_verification_code", HTTPClient.METHOD_POST, {"email": email}, callback)
#
# 用户注册
func register(username: String, password: String, email: String = "", callback: Callable = Callable()) -> void: 
	
	var data = {
		"username": username,
		"email" : email,
		"password": password
	}
	make_request("/register", HTTPClient.METHOD_POST, data, callback)

# 发送验证码
func send_verification_code(email: String, callback: Callable) -> void:
	make_request("/send_verification", HTTPClient.METHOD_POST, {"email": email}, callback)

# 邮箱验证
func verify_email(email: String, code: String, callback: Callable):
	make_request("/verify_email", HTTPClient.METHOD_POST, {"email": email, "code": code}, callback)

# 用户登录
func login(username: String, password: String, callback: Callable) -> void:
	make_request("/login", HTTPClient.METHOD_POST, {"username": username, "password": password}, callback)

# 获取个人信息（带 token）
func get_me(callback: Callable = Callable()) -> void:
	make_request("/me", HTTPClient.METHOD_GET, {}, callback)

## === 角色 API（与数据库 game.characters 对齐） ===
## 建角/列表后得到 character_id（UUID 字符串），用于背包与技能接口
func list_characters(callback: Callable = Callable()) -> void:
	make_request("/characters", HTTPClient.METHOD_GET, {}, callback)

func create_character(name: String, server_id: int, character_class: String, callback: Callable = Callable()) -> void:
	var data := {
		"name": name,
		"server_id": server_id,
		"character_class": character_class
	}
	make_request("/characters", HTTPClient.METHOD_POST, data, callback)

## === 背包API（使用角色 ID） ===
##
## slots 建议直接传 InventoryManager.get_serializable_inventory() 的结果：
## [ { "id": 101, "qty": 3 }, null, { "id": 205, "qty": 1 }, ... ]
func save_inventory(character_id: String, slots: Array, callback: Callable = Callable()) -> void:
	var data := {"slots": slots}
	make_request("/characters/%s/inventory" % character_id, HTTPClient.METHOD_POST, data, callback)

func load_inventory(character_id: String, callback: Callable) -> void:
	make_request("/characters/%s/inventory" % character_id, HTTPClient.METHOD_GET, {}, callback)

## === 技能API（使用角色 ID） ===
##
## skills_dict 可以直接用 SkillManager.save_skills_data() 返回值：
## { "Fireball": { "level": 3, "cooldown_remaining": 0.5 }, ... }
func save_skills(character_id: String, skills_dict: Dictionary, callback: Callable = Callable()) -> void:
	var data := {"skills": skills_dict}
	make_request("/characters/%s/skills" % character_id, HTTPClient.METHOD_POST, data, callback)

func load_skills(character_id: String, callback: Callable) -> void:
	make_request("/characters/%s/skills" % character_id, HTTPClient.METHOD_GET, {}, callback)
