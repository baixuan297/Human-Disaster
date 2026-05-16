# Godot 客户端测试

[← 文档索引](../README.md#文档索引)

无头单元测试、`api_test` 场景与发布前 Godot 相关检查（仅本客户端仓库内路径）。

## 无头单元测试（Hazard / AttackData）

不依赖 GUT，使用 `SceneTree` 脚本断言资源工厂行为。

| 路径 | 说明 |
|------|------|
| `test/unit/run_unit_tests.gd` | 入口脚本 |

```bash
godot --path "Human Disaster" --headless -s res://test/unit/run_unit_tests.gd
```

退出码 0 为通过，1 为失败。

扩展：可在 `_run_all()` 中增加 `Stats.take_damage` 等用例；或引入 [GUT](https://github.com/bitwes/Gut) / GdUnit4。

## api_test（API 联调）

`test/api_test.tscn` + `api_test.gd` 在真实环境下验证：

- `API_BASE_URL` 可达（默认 `http://127.0.0.1:8000`）
- 注册/登录/JWT、角色存档、`/game-data/*` 与 FastAPI 契约一致
- 请求均经 `APIManager`（与 `CharacterDataManager`、`GameDataManager` 同源）

运行：单独运行 `test/api_test.tscn`；控制台按步骤输出通过/失败。

本地调试可设 `TEST_SKIP_EMAIL_VERIFY=1`（仅开发）。路径表见 [APIManager.md](APIManager.md)。

## run_unit_tests 与 api_test 对照

| 维度 | run_unit_tests | api_test |
|------|----------------|----------|
| 测什么 | 客户端纯逻辑（Hazard、AttackData 等） | 真实 HTTP 全链路 |
| 要不要后端 | 不要 | 要（FastAPI 在 API_BASE_URL） |
| 经 APIManager | 否 | 是 |
| 运行 | 无头 `-s res://test/unit/run_unit_tests.gd` | 运行场景 `api_test.tscn` |

## 发布前（Godot 相关）

- [ ] 无头 `run_unit_tests.gd` 通过
- [ ] 运行 `api_test.tscn`，`API_BASE_URL` 正确
- [ ] 手测：新号进关、拾枪、受伤、存档、再登录恢复

服务端自动化测试在游戏 API 部署仓库中维护，不在本目录文档范围内。
