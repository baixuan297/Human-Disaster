# APIManager 说明文档

APIManager 是项目中用于与后端 HTTP API 通信的全局单例（autoload 中注册为 `ApiManager`），负责发送请求、携带 JWT、超时处理与统一回调。

---

## 一、基本配置

| 项 | 说明 |
|----|------|
| **脚本路径** | `autoload/APIManager.gd` |
| **Autoload 名称** | `ApiManager`（见 `project.godot`） |
| **API 根地址** | `API_BASE_URL = "http://192.168.1.100:8000"`（常量，需按实际服务器修改） |
| **请求超时** | `timeout_sec = 10.0` 秒 |
| **认证方式** | 请求头 `Authorization: Bearer <jwt_token>`，登录成功后自动保存 `jwt_token` |

---

## 二、核心方法

### 2.1 通用请求：`make_request`

```gdscript
func make_request(endpoint: String, method: int = HTTPClient.METHOD_GET, data: Dictionary = {}, callback: Callable = Callable()) -> void
```

- **endpoint**：相对路径，会拼在 `API_BASE_URL` 后（如 `"/login"` → `http://192.168.1.100:8000/login`）。
- **method**：`HTTPClient.METHOD_GET` / `METHOD_POST` / `METHOD_PUT` / `METHOD_DELETE` 等。
- **data**：请求体字典，非 GET 且非空时会用 `JSON.stringify(data)` 发送，请求头为 `Content-Type: application/json`。
- **callback**：请求完成时调用 `callback.call(success: bool, response_data)`。  
  - `success`：HTTP 状态码 2xx 为 true。  
  - `response_data`：解析后的 JSON（若解析失败则传 `{"message": "数据解析错误"}` 等）。  
  - 请求失败、超时、解析错误时也会调用 callback，此时 `success == false`。

行为摘要：

- 每次请求前会断开旧的 `request_completed` 连接，再绑定当前 `callback`。
- 若响应为 2xx 且为字典且包含 `"access_token"`，会自动把 `response_data["access_token"]` 写入 `jwt_token`，后续请求会带此 token。
- 超时通过内部 `Timer` 实现：超时后取消请求并调用 `callback.call(false, {"message": "请求超时"})`。

---

## 三、已实现的用户相关 API

| 方法 | 路径 | 方法 | 说明 |
|------|------|------|------|
| `register(username, password, email, callback)` | `/register` | POST | 用户注册 |
| `send_verification_code(email, callback)` | `/send_verification` | POST | 发送验证码 |
| `verify_email(email, code, callback)` | `/verify_email` | POST | 邮箱验证 |
| `login(username, password, callback)` | `/login` | POST | 用户登录（成功后会保存 `access_token` 到 `jwt_token`） |
| `get_me(callback)` | `/me` | GET | 获取当前用户信息（带 token，回调中返回 `success` 与 `data`） |

---

## 四、背包与技能 API（使用角色 ID）

| 方法 | 路径 | 方法 | 说明 |
|------|------|------|------|
| `save_inventory(character_id, slots, callback)` | `/characters/{id}/inventory` | POST | 保存背包，`slots` 建议用 `InventoryManager.get_serializable_inventory()` |
| `load_inventory(character_id, callback)` | `/characters/{id}/inventory` | GET | 加载背包，回调中 `resp["slots"]` 传给 `InventoryManager.load_serializable_inventory()` |
| `save_skills(character_id, skills_dict, callback)` | `/characters/{id}/skills` | POST | 保存技能，`skills_dict` 建议用 `SkillManager.save_skills_data()` |
| `load_skills(character_id, callback)` | `/characters/{id}/skills` | GET | 加载技能，回调中 `resp["skills"]` 用于恢复等级 |

---

## 五、使用示例

```gdscript
# 登录
ApiManager.login("myuser", "mypass", func(success, data):
    if success:
        print("登录成功，token 已保存")
    else:
        print("失败: ", data.get("message", "未知错误"))
)

# 获取当前用户信息
ApiManager.get_me(func(success, data):
    if success:
        var character_id = str(data.get("character_id", data.get("id", "1")))
        UserManager.current_character_id = character_id
)

# 保存背包
ApiManager.save_inventory(character_id, InventoryManager.get_serializable_inventory(), func(success, resp):
    if success:
        print("背包保存成功")
)

# 读取背包
ApiManager.load_inventory(character_id, func(success, resp):
    if success and resp.has("slots"):
        InventoryManager.load_serializable_inventory(resp["slots"])
)

# 保存技能
ApiManager.save_skills(character_id, SkillManager.save_skills_data(), func(success, resp):
    if success:
        print("技能保存成功")
)

# 读取技能（只恢复等级）
ApiManager.load_skills(character_id, func(success, resp):
    if success and resp.has("skills"):
        for name in resp["skills"].keys():
            var lvl = int(resp["skills"][name].get("level", 1))
            SkillManager.set_skill_level(name, lvl)
)
```

---

## 六、注意事项

1. **修改服务器地址**：改 `API_BASE_URL` 常量为你的后端地址。
2. **JWT 持久化**：当前仅在内存中保存 `jwt_token`，进程结束即丢失；若需持久化，可在登录成功后自行写入 `user://` 或通过 SettingData/SaveManager 等保存。
3. **线程/节点**：`HTTPRequest` 在 `_ready` 中创建并挂到 APIManager 下，回调在主线程执行，可直接操作场景树。

以上为 APIManager 的完整说明。
