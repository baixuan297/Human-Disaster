# 客户端文档索引

[中文](README.md) | [Español](README.es.md) | [项目 README](../README.md) | [项目 README (ES)](../README.es.md)

本目录描述 **Godot 客户端** 各模块的实现与数据流，与代码路径对照维护。仓库级文档（GDD、测试、部署、数据库）在 [`../../docs/`](../../docs/README.md)。

模块正文为**中文**；西语仅提供本索引（[`README.es.md`](README.es.md)），便于对照文件名与主题。

## 按主题查（避免重复阅读）

| 主题 | 文档 |
|------|------|
| 敌人（数据、AI、近战、生成） | [ENEMY_SYSTEM.md](ENEMY_SYSTEM.md) |
| 伤害与 Stats | [DAMAGE_SYSTEM.md](DAMAGE_SYSTEM.md) |
| 基因 | [GENE_SYSTEM.md](GENE_SYSTEM.md) |
| 经验与等级 | [EXPERIENCE_SYSTEM.md](EXPERIENCE_SYSTEM.md) |
| 本地/云端存档 | [LOCAL_AND_CLOUD_SAVE.md](LOCAL_AND_CLOUD_SAVE.md) |

## 核心与网络

| 文档 | 内容 |
|------|------|
| [AUTOLOAD_AND_UI.md](AUTOLOAD_AND_UI.md) | Autoload 顺序、UI/暂停、与存档协作 |
| [SCRIPT_LAYOUT.md](SCRIPT_LAYOUT.md) | `Script/` 目录划分 |
| [APIManager.md](APIManager.md) | HTTP、JWT、FastAPI 端点 |
| [CharacterDataManager.md](CharacterDataManager.md) | 角色快照、云端保存/加载 |
| [GameDataManager.md](GameDataManager.md) | 静态 items/weapons/skills/genes/enemies |
| [SaveManager.md](SaveManager.md) | 设置存档（与角色存档分离） |
| [LOCAL_AND_CLOUD_SAVE.md](LOCAL_AND_CLOUD_SAVE.md) | 本地快存、版本号、同步策略 |

## 玩法系统

| 文档 | 内容 |
|------|------|
| [INVENTORY.md](INVENTORY.md) | xuanBag、`InventoryManager` |
| [WEAPON_SYSTEM.md](WEAPON_SYSTEM.md) | 武器、`WeaponManager`、弹道 |
| [SKILL_SYSTEM.md](SKILL_SYSTEM.md) | 技能、`SkillManager`、效果场景 |
| [PLAYER_CAMERA_AND_MOVEMENT.md](PLAYER_CAMERA_AND_MOVEMENT.md) | 第一/第三人称、移动与瞄准 |
| [COLLISION_LAYERS.md](COLLISION_LAYERS.md) | 物理层与 `CollisionLayers` |
| [DAMAGE_SYSTEM.md](DAMAGE_SYSTEM.md) | `Stats`、`AttackData` |
| [ENEMY_SYSTEM.md](ENEMY_SYSTEM.md) | 敌人管线与运行时 |
| [EXPERIENCE_SYSTEM.md](EXPERIENCE_SYSTEM.md) | 经验、击杀、存档字段 |
| [GENE_SYSTEM.md](GENE_SYSTEM.md) | `GeneManager`、面板与后端对齐 |

## 综合

| 文档 | 内容 |
|------|------|
| [CHARACTER_AND_WEAPON_OVERVIEW.md](CHARACTER_AND_WEAPON_OVERVIEW.md) | 角色/武器摘要、教程 |
| [CHARACTER_MENU.md](CHARACTER_MENU.md) | 角色菜单、SYNC 图标 |
| [PROJECT_ISSUES_AND_FIXES.md](PROJECT_ISSUES_AND_FIXES.md) | 问题台账、审计与 TODO |

## 测试

Godot 无头测试与 `test/api_test.tscn`：[../../docs/TESTING.md](../../docs/TESTING.md)。

后端契约与 pytest：[../../StarshipBackend/PSQL_DH/tests/README.md](../../StarshipBackend/PSQL_DH/tests/README.md)。
