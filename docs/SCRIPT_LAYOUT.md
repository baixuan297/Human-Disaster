# Script 目录结构说明

`res://Script/` 下为游戏玩法与 UI 逻辑，按领域分子目录。**新增脚本时请放入对应域**，并在模块文档（如 `WEAPON_SYSTEM.md`）中补充数据流或节点约定。

| 路径 | 内容 |
|------|------|
| `player/` | `Player.gd`、移动/相机/交互/输入等组件 |
| `gun/` | 武器基类、弹道、世界可拾取武器、音效池 |
| `enemy/` | 敌人与部位受击 |
| `SkillSystem/` | 技能实例与效果脚本 |
| `menu/` | 主菜单、设置、键位、角色信息、技能 UI、登录注册 |
| `map/` | 关卡与教程区域 |
| `spaceship/` | 传送门、舱门等场景交互 |
| `npc/` | NPC 行为 |
| `Multiplayer/` | 联机相关 UI（若启用） |
| `helth_bar/` | 生命条 UI（路径名为历史拼写） |
| 根目录 | `world.gd`（`class_name World`）等关卡根脚本 |

**Autoload 单例**位于 `res://autoload/`，不在 `Script/` 下；架构说明见 [AUTOLOAD_AND_UI.md](AUTOLOAD_AND_UI.md)。
