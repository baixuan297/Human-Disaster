extends Node

## UserManager — 用户与角色 ID 管理
##
## 职责：登录/注册（调用 ApiManager）、角色 ID 缓存、记住密码
## 数据源：以服务器为准，本地 users.dat 仅作兼容，credentials.dat 存记住的账号密码
## 注意：本地 _hash_password 用 SHA256，仅用于 users.dat 兼容；后端用 argon2 校验

const SAVE_PATH = "user://users.dat"
## 记住密码：明文存储于 user://，仅便利本地调试；正式环境建议改为 OS 密钥环或禁用
const CREDENTIALS_PATH = "user://credentials.dat"

var local_users = {}
## 当前角色 ID，登录成功后由 GET /characters 填充，用于背包/技能/属性 API
var current_character_id: String = ""
## 当前角色显示名与职业（与列表中第一条角色同步，供属性面板等 UI）
var current_character_name: String = ""
var current_character_class: String = ""

func _init():
	_load_local_users()


## 注册：调用后端 API，callback(success: bool, data) 在 API 返回后调用
## 若 callback 为空，仅检查本地是否已存在后发起请求，不阻塞
func user_register(username: String, password: String, mail: String, callback: Callable = Callable()) -> bool:
	if local_users.has(username):
		if callback.is_valid():
			callback.call(false, {"message": "Username already exists"})
		return false

	ApiManager.register(username, password, mail, func(success: bool, data):
		if success:
			print("✅ 注册成功:", data)
			register_local(username, password)
		else:
			print("❌ 注册失败:", data)
		if callback.is_valid():
			callback.call(success, data)
	)
	return true

## 登录：以服务器为准，直接调用 API 验证，不依赖本地用户表
## callback(success: bool, data) — 成功时 data 可省略，失败时 data 含错误信息
func user_login(username: String, password: String, callback: Callable) -> void:
	ApiManager.login(username, password, func(success, data):
		if not success:
			if callback.is_valid():
				callback.call(false, data)
			return
		print("✅ 登录成功，token=", ApiManager.jwt_token)
		_fetch_character_id(func():
			if callback.is_valid():
				callback.call(true)
		)
	)

# ============ 本地存储功能 ============
func register_local(username: String, password: String) -> bool:
	
	var hashed_password = _hash_password(password)
	local_users[username] = {
		"password": hashed_password,
		"created_at": Time.get_unix_time_from_system()
	}
	_save_local_users()
	return true

func login_local(username: String, password: String) -> bool:
	if not local_users.has(username):
		return false
	var hashed_password := _hash_password(password)
	return local_users[username]["password"] == hashed_password

func save_user_local(username: String, password: String):
	var hashed_password = _hash_password(password)
	local_users[username] = {
		"password": hashed_password,
		"created_at": Time.get_unix_time_from_system()
	}
	_save_local_users()

func _load_local_users():
	if not FileAccess.file_exists(SAVE_PATH):
		return 
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			local_users = json.data
		else:
			push_warning("加载本地用户数据失败")

func _save_local_users():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(local_users, "\t"))
		file.close()

# ============  凭据保存功能（记住密码）============

func save_credentials(username: String, password: String):
	var credentials = {
		"username": username,
		"password": password
	}
	
	var file = FileAccess.open(CREDENTIALS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(credentials))
		file.close()

func load_credentials() -> Dictionary:
	if not FileAccess.file_exists(CREDENTIALS_PATH):
		return {}
	
	var file = FileAccess.open(CREDENTIALS_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			return json.data
	
	return {}

func clear_credentials():
	if FileAccess.file_exists(CREDENTIALS_PATH):
		DirAccess.remove_absolute(CREDENTIALS_PATH)

# ============ 角色 ID（用于背包/技能/属性 API，来自 GET /characters） ============

func _fetch_character_id(on_done: Callable = Callable()) -> void:
	ApiManager.list_characters(func(success, data):
		current_character_name = ""
		current_character_class = ""
		if success and typeof(data) == TYPE_ARRAY and data.size() > 0:
			var first = data[0]
			if typeof(first) == TYPE_DICTIONARY and first.has("character_id"):
				current_character_id = str(first["character_id"])
			elif typeof(first) == TYPE_DICTIONARY and first.has("id"):
				current_character_id = str(first["id"])
			else:
				current_character_id = ""
			if typeof(first) == TYPE_DICTIONARY:
				current_character_name = str(first.get("name", ""))
				current_character_class = str(first.get("character_class", ""))
			print("✅ 角色 ID 已更新: ", current_character_id)
		else:
			current_character_id = ""
			print("未获取到角色列表，请先创建角色")
		if on_done.is_valid():
			on_done.call()
	)

# ============ 工具函数 ============

func _hash_password(password: String) -> String:
	# 简单的哈希实现（生产环境建议使用更安全的哈希算法）
	var context = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(password.to_utf8_buffer())
	var hash_code = context.finish()
	return hash_code.hex_encode()
