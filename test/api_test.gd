extends Node

## api_test — 端到端 API 联调与契约校验（主场景：test/api_test.tscn）
##
## 设计目的（不仅是「能连上」）：
##   1. **连通性**：主机/客户端能否通过 API_BASE_URL 访问虚拟机上的 FastAPI（网络、防火墙、端口）。
##   2. **后端对接正确**：路径、方法、JSON 字段与当前 FastAPI 路由及 Pydantic 模型一致；JWT 能下发并被后续请求携带。
##   3. **架构一致**：走真实 APIManager.make_request 与各封装方法（register/login/load_* / save_*），与游戏内
##   CharacterDataManager、GameDataManager 使用同一入口，避免「脚本直连 URL」与游戏逻辑脱节。
##
## 流程概览：注册 → 登录 → /me → 角色列表 → 背包/技能/属性/场景状态/基因 → 静态 game-data → 验证码相关接口
##
## 端口：本测试经 APIManager.API_BASE_URL 访问 **FastAPI :8000**（游戏存档/角色等）。
## Spring Boot 社区 API 为 **:8080**，不在此脚本覆盖范围内。
##
## 注意：后端默认要求「先发验证码 → 验证邮箱 → 再注册」
## 若直接注册返回 400，请在后端目录设置环境变量：
##   TEST_SKIP_EMAIL_VERIFY=1
## 然后重启后端，api_test 即可直接注册通过（仅调试；发版前仍建议走完整邮箱流程）

const TEST_USER = "api_test_user"
const TEST_PASS = "api_test_pass_123"
const TEST_EMAIL = "api_test@example.com"
## 控制台步骤编号上限（与下方各 _test_* 打印一致）
const _STEP_TOTAL := 17

const _BANNER := "════════════════════════════════════════"


func _ready() -> void:
	print(_BANNER)
	print("  API 路径测试开始")
	print(_BANNER)
	_test_register()


## 需要 character_id 的步骤：为空时跳过后续角色接口，直接进入静态 game-data 链，避免重复 if 块
func _require_cid() -> String:
	var cid := UserManager.current_character_id
	if cid.is_empty():
		_test_game_data_items()
		return ""
	return cid


func _log_step(index_str: String, title: String) -> void:
	print("\n[%s/%d] %s" % [index_str, _STEP_TOTAL, title])


## 静态 game-data 常见响应：{ "items": [...] } 或直接 Array
func _list_from_game_data(resp: Variant, key: String) -> Array:
	if resp is Array:
		return resp
	if resp is Dictionary:
		var v: Variant = resp.get(key, resp)
		return v if v is Array else []
	return []


func _test_register() -> void:
	_log_step("1", "POST /register")
	ApiManager.register(TEST_USER, TEST_PASS, TEST_EMAIL, func(success, _data):
		if success:
			print("  ✅ 注册成功")
		else:
			print("  ⚠ 注册失败（可能已存在），尝试登录")
		_test_login()
	)


func _test_login() -> void:
	_log_step("2", "POST /login")
	ApiManager.login(TEST_USER, TEST_PASS, func(success, data):
		if success:
			print("  ✅ 登录成功，token 已保存")
			_test_get_me()
		else:
			print("  ❌ 登录失败:", data)
	)


func _test_get_me() -> void:
	_log_step("3", "GET /me")
	ApiManager.get_me(func(success, data):
		if success:
			print("  ✅ 当前用户:", data.get("username", data))
			_test_list_characters()
		else:
			print("  ❌ 获取用户失败:", data)
	)


func _test_list_characters() -> void:
	_log_step("4", "GET /characters")
	ApiManager.list_characters(func(success, data):
		if success and data is Array:
			print("  ✅ 角色列表: %d 条" % data.size())
			if data.size() > 0:
				var first: Variant = data[0]
				if first is Dictionary:
					UserManager.current_character_id = str(first.get("character_id", first.get("id", "")))
				print("     使用 character_id = ", UserManager.current_character_id)
				_test_load_inventory()
			else:
				print("  ⚠ 无角色，尝试创建")
				_test_create_character()
		else:
			print("  ❌ 角色列表失败:", data)
	)


func _test_create_character() -> void:
	_log_step("4b", "POST /characters (创建角色)")
	var unique_name := "TestChar_%d" % Time.get_unix_time_from_system()
	ApiManager.create_character(unique_name, 1, "warrior", func(success, data):
		if success and data is Dictionary:
			UserManager.current_character_id = str(data.get("character_id", data.get("id", "")))
			print("  ✅ 创建角色成功，character_id = ", UserManager.current_character_id)
			_test_load_inventory()
		else:
			print("  ❌ 创建角色失败:", data)
			_test_game_data_items()
	)


func _test_load_inventory() -> void:
	var cid := _require_cid()
	if cid.is_empty():
		return
	_log_step("5", "GET /characters/%s/inventory" % cid)
	ApiManager.load_inventory(cid, func(success, resp):
		if success and resp is Dictionary:
			var slots: Array = resp.get("slots", [])
			print("  ✅ 加载背包: %d 槽位" % slots.size())
		else:
			print("  ❌ 加载背包失败:", resp)
		_test_save_inventory()
	)


func _test_save_inventory() -> void:
	var cid := _require_cid()
	if cid.is_empty():
		return
	_log_step("6", "POST /characters/%s/inventory" % cid)
	var slots: Array = InventoryManager.get_serializable_inventory() if InventoryManager else []
	ApiManager.save_inventory(cid, slots, func(success, resp):
		if success:
			print("  ✅ 保存背包成功")
		else:
			print("  ❌ 保存背包失败:", resp)
		_test_load_skills()
	)


func _test_load_skills() -> void:
	var cid := _require_cid()
	if cid.is_empty():
		return
	_log_step("7", "GET /characters/%s/skills" % cid)
	ApiManager.load_skills(cid, func(success, resp):
		if success and resp is Dictionary:
			var skills: Dictionary = resp.get("skills", {})
			print("  ✅ 加载技能: %d 个" % skills.size())
			if skills.size() > 0 and SkillManager:
				SkillManager.load_skills_data(resp["skills"])
		else:
			print("  ❌ 加载技能失败:", resp)
		_test_save_skills()
	)


func _test_save_skills() -> void:
	var cid := _require_cid()
	if cid.is_empty():
		return
	_log_step("8", "POST /characters/%s/skills" % cid)
	var skills_dict: Dictionary = SkillManager.save_skills_data() if SkillManager else {}
	ApiManager.save_skills(cid, skills_dict, func(success, resp):
		if success:
			print("  ✅ 保存技能成功")
		else:
			print("  ❌ 保存技能失败:", resp)
		_test_load_stats()
	)


func _test_load_stats() -> void:
	var cid := _require_cid()
	if cid.is_empty():
		return
	_log_step("9", "GET /characters/%s/stats" % cid)
	ApiManager.load_stats(cid, func(success, resp):
		if success and resp is Dictionary:
			print("  ✅ 加载属性: max_health=%s" % resp.get("max_health", "?"))
		else:
			print("  ❌ 加载属性失败:", resp)
		_test_save_stats()
	)


func _test_save_stats() -> void:
	var cid := _require_cid()
	if cid.is_empty():
		return
	_log_step("10", "POST /characters/%s/stats" % cid)
	var stats_dict := {
		"max_health": 100,
		"current_health": 100,
		"attack": 10,
		"defense": 5,
		"critical_rate": 0.05,
		"critical_damage": 1.5,
		"evasion": 0.05,
		"experience": 0.0,
	}
	ApiManager.save_stats(cid, stats_dict, func(success, resp):
		if success:
			print("  ✅ 保存属性成功")
		else:
			print("  ❌ 保存属性失败:", resp)
		_test_load_genes()
	)


func _test_load_genes() -> void:
	var cid := _require_cid()
	if cid.is_empty():
		return
	_log_step("10b", "GET /characters/%s/genes" % cid)
	ApiManager.load_genes(cid, func(success, resp):
		if success and resp is Dictionary:
			var genes: Variant = resp.get("genes", [])
			var count: int = genes.size() if genes is Array else 0
			print("  ✅ 加载基因: %d 条" % count)
		else:
			print("  ❌ 加载基因失败:", resp)
		_test_save_genes()
	)


func _test_save_genes() -> void:
	var cid := _require_cid()
	if cid.is_empty():
		return
	_log_step("10c", "POST /characters/%s/genes" % cid)
	ApiManager.save_genes(cid, [], func(success, resp):
		if success:
			print("  ✅ 保存基因成功（空列表）")
		else:
			print("  ❌ 保存基因失败:", resp)
		_test_game_data_items()
	)


func _test_game_data_items() -> void:
	_log_step("11", "GET /game-data/items (无需 token)")
	ApiManager.get_game_data_items(func(success, resp):
		if success:
			var items := _list_from_game_data(resp, "items")
			print("  ✅ 物品数据: %d 条" % items.size())
		else:
			print("  ❌ 物品数据失败:", resp)
		_test_game_data_skills()
	)


func _test_game_data_skills() -> void:
	_log_step("12", "GET /game-data/skills (无需 token)")
	ApiManager.get_game_data_skills(func(success, resp):
		if success:
			var skills := _list_from_game_data(resp, "skills")
			print("  ✅ 技能数据: %d 条" % skills.size())
		else:
			print("  ❌ 技能数据失败:", resp)
		_test_game_data_genes()
	)


func _test_game_data_genes() -> void:
	_log_step("13", "GET /game-data/genes (无需 token)")
	ApiManager.get_game_data_genes(func(success, resp):
		if success:
			var genes := _list_from_game_data(resp, "genes")
			print("  ✅ 基因数据: %d 条" % genes.size())
		else:
			print("  ❌ 基因数据失败:", resp)
		_test_send_verification()
	)


func _test_send_verification() -> void:
	_log_step("14", "POST /send_verification (发送验证码)")
	ApiManager.send_verification_code(TEST_EMAIL, func(success, resp):
		if success:
			print("  ✅ 验证码发送成功")
		else:
			var msg: Variant = resp.get("message", resp) if resp is Dictionary else resp
			print("  ⚠ 验证码发送失败（可能未配置邮件服务）:", msg)
		_test_verify_email()
	)


func _test_verify_email() -> void:
	_log_step("15", "POST /verify_email (需真实验证码，通常失败)")
	ApiManager.verify_email(TEST_EMAIL, "000000", func(success, resp):
		if success:
			print("  ✅ 邮箱验证成功")
		else:
			var msg: Variant = resp.get("message", resp) if resp is Dictionary else resp
			print("  ⚠ 邮箱验证失败（预期，需真实验证码）:", msg)
		_test_complete()
	)


func _test_complete() -> void:
	print("\n" + _BANNER)
	print("  API 路径测试完成")
	print(_BANNER)
