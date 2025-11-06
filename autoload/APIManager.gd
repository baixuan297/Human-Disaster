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
	# verification_code: String = "", 
	var data = {
		"username": username,
		"password": password
	}
	
	if email != "":
		data["email"] = email
	
	#if verification_code != "":
		#data["verification_code"] = verification_code
	
	make_request("/register", HTTPClient.METHOD_POST, data, callback)

# 用户登录
func login(username: String, password: String, callback: Callable) -> void:
	make_request("/login", HTTPClient.METHOD_POST, {"username": username, "password": password}, callback)

# 获取个人信息（带 token）
func get_me() -> void:
	make_request("/me", HTTPClient.METHOD_GET)

## === 用户属性API ===
#
## 获取用户属性
#func get_user_stats(user_id: int, callback: Callable) -> void:
	#make_request("/user/" + str(user_id) + "/stats", HTTPClient.METHOD_GET, {}, callback)
#
## 更新用户属性
#func update_user_stats(user_id: int, stats: Dictionary, callback: Callable) -> void:
	#make_request("/user/" + str(user_id) + "/stats", HTTPClient.METHOD_PUT, stats, callback)

## === 背包API ===
#
## 获取用户背包
#func get_user_inventory(user_id: int, callback: Callable) -> void:
	#make_request("/user/" + str(user_id) + "/inventory", HTTPClient.METHOD_GET, {}, callback)
#
## 添加物品到背包
#func add_inventory_item(user_id: int, item_id: int, quantity: int, callback: Callable) -> void:
	#make_request("/user/" + str(user_id) + "/inventory", HTTPClient.METHOD_POST, {
		#"item_id": item_id,
		#"quantity": quantity
	#}, callback)
#
## 更新物品信息
#func update_item(user_id: int, item_id: int, quantity: int, callback: Callable):
	#make_request("/user/" + str(user_id) + "/inventory", HTTPClient.METHOD_POST, {
				#"item_id": item_id,
				#"quantity": quantity
			#}, callback)
#
## 从背包移除物品
#func remove_inventory_item(user_id: int, item_id: int, quantity: int, callback: Callable) -> void:
	#make_request("/user/" + str(user_id) + "/inventory/" + str(item_id) + "?quantity=" + str(quantity), HTTPClient.METHOD_DELETE, {}, callback)

## === 状态API ===
#
## 获取用户状态
#func get_user_status(user_id: int, callback: Callable) -> void:
	#make_request("/user/" + str(user_id) + "/status", HTTPClient.METHOD_GET, {}, callback)
#
## 添加用户状态
#func add_user_status(user_id: int, status_name: String, status_value: String = "", expires_at: String = "", callback: Callable = Callable()) -> void:
	#var data = {
		#"status_name": status_name,
		#"status_value": status_value
	#}
	#
	#if expires_at != "":
		#data["expires_at"] = expires_at
	#
	#make_request("/user/" + str(user_id) + "/status", HTTPClient.METHOD_POST, data, callback)
