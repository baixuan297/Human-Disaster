extends Node

## API 路径测试 — 覆盖 APIManager 主要接口
## 运行：将 test/api_test.tscn 设为主场景或单独运行
## 流程：注册 → 登录 → /me → 角色列表 → 背包/技能/属性 → 静态数据 → 验证码
##
## 注意：后端默认要求「先发验证码 → 验证邮箱 → 再注册」
## 若直接注册返回 400，请在后端目录设置环境变量：
##   TEST_SKIP_EMAIL_VERIFY=1
## 然后重启后端，api_test 即可直接注册通过

const TEST_USER = "api_test_user"
const TEST_PASS = "api_test_pass_123"
const TEST_EMAIL = "api_test@example.com"


func _ready() -> void:
	print("════════════════════════════════════════")
	print("  API 路径测试开始")
	print("════════════════════════════════════════")
	_test_register()


func _test_register() -> void:
	print("\n[1/17] POST /register")
	ApiManager.register(TEST_USER, TEST_PASS, TEST_EMAIL, func(success, data):
		if success:
			print("  ✅ 注册成功")
			_test_login()
		else:
			# 可能已存在，尝试登录
			print("  ⚠ 注册失败（可能已存在），尝试登录")
			_test_login()
	)


func _test_login() -> void:
	print("\n[2/17] POST /login")
	ApiManager.login(TEST_USER, TEST_PASS, func(success, data):
		if success:
			print("  ✅ 登录成功，token 已保存")
			_test_get_me()
		else:
			print("  ❌ 登录失败:", data)
	)


func _test_get_me() -> void:
	print("\n[3/17] GET /me")
	ApiManager.get_me(func(success, data):
		if success:
			print("  ✅ 当前用户:", data.get("username", data))
			_test_list_characters()
		else:
			print("  ❌ 获取用户失败:", data)
	)


func _test_list_characters() -> void:
	print("\n[4/17] GET /characters")
	ApiManager.list_characters(func(success, data):
		if success and typeof(data) == TYPE_ARRAY:
			print("  ✅ 角色列表: %d 条" % data.size())
			if data.size() > 0:
				var first = data[0]
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
	print("\n[4b/17] POST /characters (创建角色)")
	var unique_name = "TestChar_%d" % Time.get_unix_time_from_system()
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
	var cid := UserManager.current_character_id
	if cid.is_empty():
		_test_game_data_items()
		return
	print("\n[5/17] GET /characters/%s/inventory" % cid)
	ApiManager.load_inventory(cid, func(success, resp):
		if success:
			var slots = resp.get("slots", [])
			print("  ✅ 加载背包: %d 槽位" % slots.size())
		else:
			print("  ❌ 加载背包失败:", resp)
		_test_save_inventory()
	)


func _test_save_inventory() -> void:
	var cid := UserManager.current_character_id
	if cid.is_empty():
		_test_game_data_items()
		return
	print("\n[6/17] POST /characters/%s/inventory" % cid)
	var slots := InventoryManager.get_serializable_inventory() if InventoryManager else []
	ApiManager.save_inventory(cid, slots, func(success, resp):
		if success:
			print("  ✅ 保存背包成功")
		else:
			print("  ❌ 保存背包失败:", resp)
		_test_load_skills()
	)


func _test_load_skills() -> void:
	var cid := UserManager.current_character_id
	if cid.is_empty():
		_test_game_data_items()
		return
	print("\n[7/17] GET /characters/%s/skills" % cid)
	ApiManager.load_skills(cid, func(success, resp):
		if success:
			var skills = resp.get("skills", {})
			print("  ✅ 加载技能: %d 个" % skills.size())
			if skills.size() > 0 and SkillManager:
				SkillManager.load_skills_data(resp["skills"])
		else:
			print("  ❌ 加载技能失败:", resp)
		_test_save_skills()
	)


func _test_save_skills() -> void:
	var cid := UserManager.current_character_id
	if cid.is_empty():
		_test_game_data_items()
		return
	print("\n[8/17] POST /characters/%s/skills" % cid)
	var skills_dict := SkillManager.save_skills_data() if SkillManager else {}
	ApiManager.save_skills(cid, skills_dict, func(success, resp):
		if success:
			print("  ✅ 保存技能成功")
		else:
			print("  ❌ 保存技能失败:", resp)
		_test_load_stats()
	)


func _test_load_stats() -> void:
	var cid := UserManager.current_character_id
	if cid.is_empty():
		_test_game_data_items()
		return
	print("\n[9/17] GET /characters/%s/stats" % cid)
	ApiManager.load_stats(cid, func(success, resp):
		if success and resp is Dictionary:
			print("  ✅ 加载属性: max_health=%s" % resp.get("max_health", "?"))
		else:
			print("  ❌ 加载属性失败:", resp)
		_test_save_stats()
	)


func _test_save_stats() -> void:
	var cid := UserManager.current_character_id
	if cid.is_empty():
		_test_game_data_items()
		return
	print("\n[10/17] POST /characters/%s/stats" % cid)
	var stats_dict := {
		"max_health": 100,
		"current_health": 100,
		"attack": 10,
		"defense": 5,
		"critical_rate": 0.05,
		"critical_damage": 1.5,
		"evasion": 0.05
	}
	ApiManager.save_stats(cid, stats_dict, func(success, resp):
		if success:
			print("  ✅ 保存属性成功")
		else:
			print("  ❌ 保存属性失败:", resp)
		_test_load_genes()
	)


func _test_load_genes() -> void:
	var cid := UserManager.current_character_id
	if cid.is_empty():
		_test_game_data_items()
		return
	print("\n[10b/17] GET /characters/%s/genes" % cid)
	ApiManager.load_genes(cid, func(success, resp):
		if success:
			var genes = resp.get("genes", []) if resp is Dictionary else resp
			var count = genes.size() if genes is Array else 0
			print("  ✅ 加载基因: %d 条" % count)
		else:
			print("  ❌ 加载基因失败:", resp)
		_test_save_genes()
	)


func _test_save_genes() -> void:
	var cid := UserManager.current_character_id
	if cid.is_empty():
		_test_game_data_items()
		return
	print("\n[10c/17] POST /characters/%s/genes" % cid)
	ApiManager.save_genes(cid, [], func(success, resp):
		if success:
			print("  ✅ 保存基因成功（空列表）")
		else:
			print("  ❌ 保存基因失败:", resp)
		_test_game_data_items()
	)


func _test_game_data_items() -> void:
	print("\n[11/17] GET /game-data/items (无需 token)")
	ApiManager.get_game_data_items(func(success, resp):
		if success:
			var items = resp.get("items", resp) if resp is Dictionary else resp
			var count = items.size() if items is Array else 0
			print("  ✅ 物品数据: %d 条" % count)
		else:
			print("  ❌ 物品数据失败:", resp)
		_test_game_data_skills()
	)


func _test_game_data_skills() -> void:
	print("\n[12/17] GET /game-data/skills (无需 token)")
	ApiManager.get_game_data_skills(func(success, resp):
		if success:
			var skills = resp.get("skills", resp) if resp is Dictionary else resp
			var count = skills.size() if skills is Array else 0
			print("  ✅ 技能数据: %d 条" % count)
		else:
			print("  ❌ 技能数据失败:", resp)
		_test_game_data_genes()
	)


func _test_game_data_genes() -> void:
	print("\n[13/17] GET /game-data/genes (无需 token)")
	ApiManager.get_game_data_genes(func(success, resp):
		if success:
			var genes = resp.get("genes", resp) if resp is Dictionary else resp
			var count = genes.size() if genes is Array else 0
			print("  ✅ 基因数据: %d 条" % count)
		else:
			print("  ❌ 基因数据失败:", resp)
		_test_send_verification()
	)


func _test_send_verification() -> void:
	print("\n[14/14] POST /send_verification (发送验证码)")
	ApiManager.send_verification_code(TEST_EMAIL, func(success, resp):
		if success:
			print("  ✅ 验证码发送成功")
		else:
			print("  ⚠ 验证码发送失败（可能未配置邮件服务）:", resp.get("message", resp))
		_test_verify_email()
	)


func _test_verify_email() -> void:
	print("\n[15/17] POST /verify_email (需真实验证码，通常失败)")
	ApiManager.verify_email(TEST_EMAIL, "000000", func(success, resp):
		if success:
			print("  ✅ 邮箱验证成功")
		else:
			print("  ⚠ 邮箱验证失败（预期，需真实验证码）:", resp.get("message", resp))
		_test_complete()
	)


func _test_complete() -> void:
	print("\n════════════════════════════════════════")
	print("  API 路径测试完成")
	print("════════════════════════════════════════")
