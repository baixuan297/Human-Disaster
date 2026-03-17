extends Node

func _ready():
	print("测试注册中...")
	ApiManager.register("alice", "abc", "alice@example.com", func(success, data):
		if success:
			print("✅ 注册成功:", data)
			login_test()
		else:
			print("❌ 注册失败:", data)
	)

func login_test():
	print("测试登录中...")
	ApiManager.login("alice", "abc", func(success, data):
		if success:
			print("✅ 登录成功，token=", ApiManager.jwt_token)
			get_me_test()
		else:
			print("❌ 登录失败:", data)
	)

func get_me_test():
	print("测试 /me 与角色列表...")
	ApiManager.get_me(func(success, data):
		if success:
			print("✅ 当前用户信息:", data)
		else:
			print("❌ 获取用户信息失败:", data)
		ApiManager.list_characters(func(list_ok, list_data):
			if list_ok and typeof(list_data) == TYPE_ARRAY and list_data.size() > 0:
				var first = list_data[0]
				UserManager.current_character_id = str(first.get("character_id", first.get("id", "")))
				print("✅ 角色列表:", list_data.size(), " 条，使用 character_id=", UserManager.current_character_id)
			else:
				UserManager.current_character_id = ""
				print("未获取到角色，请先创建角色")
			test_inventory_skills()
		)
	)

func test_inventory_skills():
	var cid := UserManager.current_character_id
	if cid.is_empty():
		print("跳过背包/技能测试（无 character_id）")
		return
	print("测试背包/技能 API，character_id=", cid)
	ApiManager.save_inventory(cid, InventoryManager.get_serializable_inventory(), func(success, resp):
		if success:
			print("✅ 背包保存成功")
		else:
			print("❌ 背包保存失败:", resp)
	)
	ApiManager.save_skills(cid, SkillManager.save_skills_data(), func(success, resp):
		if success:
			print("✅ 技能保存成功")
		else:
			print("❌ 技能保存失败:", resp)
	)
