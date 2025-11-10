extends Node
# 用户管理类 - 处理本地和服务器的用户数据

const SAVE_PATH = "user://users.dat"
const CREDENTIALS_PATH = "user://credentials.dat"

var local_users = {}

func _init():
	_load_local_users()
	
	
func user_register(username: String, password: String, mail: String) -> bool:
	if local_users.has(username):
		return false

	
	ApiManager.register(username, password, mail, func(success, data):
		if success:
			print("✅ 注册成功:", data)
			register_local(username, password)
		else:
			print("❌ 注册失败:", data)
			return false
	)
	return register_local(username, password)

func user_login(username: String, password: String) -> bool:
	if not local_users.has(username):
		return false

	
	ApiManager.login(username, password, func(success, data):
		if success:
			print("✅ 登录成功，token=", ApiManager.jwt_token)
			return true
		else:
			print("❌ 登录失败:", data)
			return false
		)
	return login_local(username, password)

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
	var hashed_password = _hash_password(password)
	print("password = ", password, " / password_hased = ", hashed_password)
	print(local_users[username]["password"])
	print(local_users[username]["password"] == hashed_password)
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

# ============ 工具函数 ============

func _hash_password(password: String) -> String:
	# 简单的哈希实现（生产环境建议使用更安全的哈希算法）
	var context = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(password.to_utf8_buffer())
	var hash_code = context.finish()
	return hash_code.hex_encode()
