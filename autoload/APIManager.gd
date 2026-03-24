extends Node

## APIManager — 后端 HTTP API 统一入口
##
## 职责：封装所有 API 请求、携带 JWT、超时处理、统一回调
## 并行：每次 make_request 创建独立 HTTPRequest，支持并发（GameDataManager 同时拉 items/skills/genes）
## 配置：修改 API_BASE_URL 为实际后端地址，或后续改为 project.godot 配置
##
## 依赖：project.godot 中注册为 ApiManager（autoload）

# ── 配置（部署时需修改）────────────────────────────────────────────────────────
const API_BASE_URL = "http://192.168.1.100:8000"
var jwt_token := ""
## 请求超时秒数（网络不稳定或后端冷启动时可适当增大）
var timeout_sec: float = 25.0


func _ready() -> void:
	## 暂停时仍处理 HTTP 请求与回调（否则暂停菜单点「退出」时 save_to_api 回调不会执行）
	process_mode = Node.PROCESS_MODE_ALWAYS


# ── 通用请求 ─────────────────────────────────────────────────────────────────
## require_auth: 静态数据接口（game-data）无需 token，设为 false	
func make_request(endpoint: String, method: int = HTTPClient.METHOD_GET, data: Dictionary = {}, callback: Callable = Callable(), require_auth: bool = true) -> void:
	var url = API_BASE_URL + endpoint
	var headers = PackedStringArray(["Content-Type: application/json"])
	if require_auth:
		headers.append("Authorization: Bearer %s" % jwt_token)
	var body = ""
	if method != HTTPClient.METHOD_GET and not data.is_empty():
		body = JSON.stringify(data)

	var req := HTTPRequest.new()
	add_child(req)

	var timed_out_state := [false]  ## 用数组包装，lambda 内可正确修改
	var timer := Timer.new()
	timer.wait_time = timeout_sec
	timer.one_shot = true
	add_child(timer)

	var on_completed := func(_result: int, response_code: int, _headers: PackedStringArray, resp_body: PackedByteArray) -> void:
		if timed_out_state[0]:
			return
		timer.stop()
		timer.queue_free()
		req.queue_free()

		var result := _result
		if result != HTTPRequest.RESULT_SUCCESS:
			if callback.is_valid():
				callback.call(false, {"message": "网络错误"})
			return

		var response_text := resp_body.get_string_from_utf8()
		var json := JSON.new()
		if json.parse(response_text) != OK:
			if callback.is_valid():
				callback.call(false, {"message": "数据解析错误"})
			return

		var response_data = json.data
		var success := response_code >= 200 and response_code < 300
		if success and typeof(response_data) == TYPE_DICTIONARY and response_data.has("access_token"):
			jwt_token = response_data["access_token"]
		if not success and typeof(response_data) == TYPE_DICTIONARY and response_data.has("detail") and not response_data.has("message"):
			response_data["message"] = response_data["detail"] if typeof(response_data["detail"]) == TYPE_STRING else str(response_data["detail"])

		if callback.is_valid():
			callback.call(success, response_data)

	req.request_completed.connect(on_completed)
	var err := req.request(url, headers, method, body)
	if err != OK:
		req.queue_free()
		timer.queue_free()
		print("HTTP请求错误: ", err)
		if callback.is_valid():
			callback.call(false, {"message": "请求失败"})
		return

	var on_timeout := func() -> void:
		if timed_out_state[0]:
			return
		timed_out_state[0] = true
		if req.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
			req.cancel_request()
		print("API 请求超时: ", url, " （请检查 API_BASE_URL、后端是否运行、网络/防火墙）")
		if callback.is_valid():
			callback.call(false, {"message": "请求超时，请检查网络或后端地址"})
		req.queue_free()
		timer.queue_free()
	timer.timeout.connect(on_timeout)
	timer.start()

## === 用户相关API ===
#
# 用户注册（无需 token）
func register(username: String, password: String, email: String = "", callback: Callable = Callable()) -> void:
	var data = {
		"username": username,
		"email" : email,
		"password": password
	}
	make_request("/register", HTTPClient.METHOD_POST, data, callback, false)

# 发送验证码（无需 token）
func send_verification_code(email: String, callback: Callable) -> void:
	make_request("/send_verification", HTTPClient.METHOD_POST, {"email": email}, callback, false)

# 邮箱验证（无需 token）
func verify_email(email: String, code: String, callback: Callable) -> void:
	make_request("/verify_email", HTTPClient.METHOD_POST, {"email": email, "code": code}, callback, false)

# 用户登录（无需 token）
func login(username: String, password: String, callback: Callable) -> void:
	make_request("/login", HTTPClient.METHOD_POST, {"username": username, "password": password}, callback, false)

# 获取个人信息（带 token）
func get_me(callback: Callable = Callable()) -> void:
	make_request("/me", HTTPClient.METHOD_GET, {}, callback)

## === 角色 API（与数据库 game.characters 对齐） ===
## 建角/列表后得到 character_id（UUID 字符串），用于背包与技能接口
func list_characters(callback: Callable = Callable()) -> void:
	make_request("/characters", HTTPClient.METHOD_GET, {}, callback)

func create_character(char_name: String, server_id: int, character_class: String, callback: Callable = Callable()) -> void:
	var data := {
		"name": char_name,
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

## === 角色属性 API（与 game.character_stats 对齐） ===
func load_stats(character_id: String, callback: Callable) -> void:
	make_request("/characters/%s/stats" % character_id, HTTPClient.METHOD_GET, {}, callback)

func save_stats(character_id: String, stats_dict: Dictionary, callback: Callable = Callable()) -> void:
	make_request("/characters/%s/stats" % character_id, HTTPClient.METHOD_POST, stats_dict, callback)

## === 场景状态 API（场景路径、玩家位置与朝向） ===
##
## data 格式: { "scene_path": "res://Scene/map/world.tscn", "position": [x,y,z], "rotation_y": float }
func save_scene_state(character_id: String, data: Dictionary, callback: Callable = Callable()) -> void:
	make_request("/characters/%s/scene_state" % character_id, HTTPClient.METHOD_POST, data, callback)

func load_scene_state(character_id: String, callback: Callable) -> void:
	make_request("/characters/%s/scene_state" % character_id, HTTPClient.METHOD_GET, {}, callback)

## === 基因 API（使用角色 ID，与 game.character_genes 对齐） ===
##
## genes_list 格式: [ { "gene_id": int, "current_level": int, "is_active": bool, "points_spent": int }, ... ]
func load_genes(character_id: String, callback: Callable) -> void:
	make_request("/characters/%s/genes" % character_id, HTTPClient.METHOD_GET, {}, callback)

func save_genes(character_id: String, genes_list: Array, callback: Callable = Callable()) -> void:
	var data := {"genes": genes_list}
	make_request("/characters/%s/genes" % character_id, HTTPClient.METHOD_POST, data, callback)

func unlock_gene(character_id: String, gene_id: int, callback: Callable = Callable()) -> void:
	make_request("/characters/%s/genes/unlock" % character_id, HTTPClient.METHOD_POST, {"gene_id": gene_id}, callback)

func upgrade_gene(character_id: String, gene_id: int, callback: Callable = Callable()) -> void:
	make_request("/characters/%s/genes/upgrade" % character_id, HTTPClient.METHOD_POST, {"gene_id": gene_id}, callback)

func toggle_gene(character_id: String, gene_id: int, is_active: bool, callback: Callable = Callable()) -> void:
	var data := {"gene_id": gene_id, "is_active": is_active}
	make_request("/characters/%s/genes/toggle" % character_id, HTTPClient.METHOD_POST, data, callback)

## === 静态游戏数据 API（GameDataManager 启动时拉取，无需 token） ===
func get_game_data_items(callback: Callable) -> void:
	make_request("/game-data/items", HTTPClient.METHOD_GET, {}, callback, false)

func get_game_data_skills(callback: Callable) -> void:
	make_request("/game-data/skills", HTTPClient.METHOD_GET, {}, callback, false)

func get_game_data_genes(callback: Callable) -> void:
	make_request("/game-data/genes", HTTPClient.METHOD_GET, {}, callback, false)
