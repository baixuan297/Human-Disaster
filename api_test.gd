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
	print("测试 /me 接口中...")
	ApiManager.make_request("/me", HTTPClient.METHOD_GET, {}, func(success, data):
		if success:
			print("✅ 当前用户信息:", data)
		else:
			print("❌ 获取用户信息失败:", data)
	)
