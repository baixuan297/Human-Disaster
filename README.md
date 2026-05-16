# Desastre Humano（Godot 客户端）

[中文](README.md) | [Español](README.es.md)

Godot 4.6 三维项目（`config/name="Desastre Humano"`，Forward Plus，1920×1080）。玩法与系统说明见 [docs/README.md](docs/README.md)（西语：[docs/README.es.md](docs/README.es.md)）。

## 做什么

第一/第三人称战斗、背包（`addons/xuanBag`）、武器与技能、基因、经验与 SYNC、敌人 AI、教程、本地设置存档与云端角色存档（FastAPI）。

## 环境

- Godot 4.6（与 `project.godot` 中 `config/features` 一致）
- 登录与云端存档：`StarshipBackend/PSQL_DH`（默认 `http://127.0.0.1:8000`）
- 社区 App 使用 Spring 8080，与 `APIManager.gd` 无关

## 目录

| 路径 | 用途 |
|------|------|
| `autoload/` | 全局单例 |
| `Script/` | 玩法与 UI（[docs/SCRIPT_LAYOUT.md](docs/SCRIPT_LAYOUT.md)） |
| `Scene/` | 场景与关卡 |
| `resource/`、`素材/` | 资源 |
| `addons/xuanBag/` | 背包插件 |
| `test/` | 如 `api_test.tscn` |
| `docs/` | 模块文档 |

## 运行

1. Godot 4.6 打开 `project.godot`，F5 运行。
2. 需要联机存档：PostgreSQL + FastAPI（[../StarshipBackend/PSQL_DH/README.md](../StarshipBackend/PSQL_DH/README.md)）。
3. 改 API 地址：`autoload/APIManager.gd` → `API_BASE_URL`（默认 `http://127.0.0.1:8000`）。

网络与端口：[../StarshipBackend/docs/NETWORK_DEPLOYMENT.md](../StarshipBackend/docs/NETWORK_DEPLOYMENT.md)、[../StarshipBackend/docs/BACKEND_PORTS.md](../StarshipBackend/docs/BACKEND_PORTS.md)。

## Autoload（`project.godot`）

`SettingData`、`SettingSignal`、`SaveManager`、`LocalCharacterSave`、`ApiManager`、`GameDataManager`、`GeneManager`、`CharacterDataManager`、`ExperienceRewards`、`EnemyLootService`、`InventoryManager`、`SceneManager`、`PauseManager`、`UiManager`、`UserManager`、`GBMssage`、`TutorialManager`、`AudioManager`、`SkillResourceRegistry`、`SkillManager`、`ScreenEffect`、`SignalBus`（占位）。详见 [docs/AUTOLOAD_AND_UI.md](docs/AUTOLOAD_AND_UI.md)。

## 默认键位

WASD 移动，Space 跳跃，Shift 冲刺，Ctrl 蹲伏，鼠标左键射击、右键瞄准，1/2 或滚轮换武器，B 背包，C 角色信息，Q/E/X 技能，F 交互。

## 测试

- `test/api_test.tscn`（需 FastAPI；本地可设 `TEST_SKIP_EMAIL_VERIFY=1`）
- 说明：[docs/TESTING.md](docs/TESTING.md)；后端 pytest 见 [../StarshipBackend/docs/TESTING.md](../StarshipBackend/docs/TESTING.md)

## 链接

- [docs/README.md](docs/README.md) — 模块文档索引
- [../README.md](../README.md) — Monorepo 总览
- [../PROJECT_INDEX.md](../PROJECT_INDEX.md) — 全仓库文档地图
