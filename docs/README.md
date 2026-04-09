# 项目文档索引

本文档目录包含各模块的架构说明与数据流图。

---

## 核心系统

| 文档 | 说明 |
|------|------|
| [AUTOLOAD_AND_UI.md](AUTOLOAD_AND_UI.md) | Autoload 顺序、Pause/UI、SignalBus（占位）、与 CharacterDataManager 协作 |
| [SCRIPT_LAYOUT.md](SCRIPT_LAYOUT.md) | `Script/` 目录按领域划分说明 |
| [APIManager.md](APIManager.md) | API 请求封装、JWT、超时、用户/角色/物品/技能/基因接口 |
| [CharacterDataManager.md](CharacterDataManager.md) | 角色数据加载/保存、快照/恢复、与 API 对接 |
| [GameDataManager.md](GameDataManager.md) | 静态物品/技能/基因定义加载与查询 |
| [SaveManager.md](SaveManager.md) | 设置存档（与游戏存档分离） |

---

## 游戏系统

| 文档 | 说明 |
|------|------|
| [INVENTORY.md](INVENTORY.md) | 背包系统（xuanBag 插件、InventoryManager、InventoryUI） |
| [SKILL_SYSTEM.md](SKILL_SYSTEM.md) | 技能系统（SkillManager、Skill、SkillResource、效果场景） |
| [WEAPON_SYSTEM.md](WEAPON_SYSTEM.md) | 武器系统（WeaponManager、BaseWeapon、WeaponViewModel、Bullet） |
| [PLAYER_CAMERA_AND_MOVEMENT.md](PLAYER_CAMERA_AND_MOVEMENT.md) | 第一/第三人称相机、移动 Callable、`PlayerViewPaths`、瞄准路径 |
| [DAMAGE_SYSTEM.md](DAMAGE_SYSTEM.md) | 伤害系统（Stats、AttackData、角色/敌人受击流程） |
| [GENE_SYSTEM.md](GENE_SYSTEM.md) | 基因模块（GeneData、CharacterGeneState、GeneManager、已集成） |

---

## 综合文档

| 文档 | 说明 |
|------|------|
| [PROJECT_ISSUES_AND_FIXES.md](PROJECT_ISSUES_AND_FIXES.md) | 工程问题台账、代码审计 §8、**后续 TODO §9**（与代码同步维护） |
| [CHARACTER_AND_WEAPON_OVERVIEW.md](CHARACTER_AND_WEAPON_OVERVIEW.md) | 角色与武器系统理解摘要、教程系统 |
| [CHARACTER_MENU.md](CHARACTER_MENU.md) | 角色菜单、属性面板、SYNC 等级与图标资源约定 |

---

## 测试

Godot 无头单测与 `api_test` 场景说明见仓库根目录 [TESTING.md](../../docs/TESTING.md)。
