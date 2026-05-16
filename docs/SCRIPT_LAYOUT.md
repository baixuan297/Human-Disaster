# Script 目录结构说明
[← 文档索引](../README.md#文档索引)

`res://Script/` 目录地图。玩法逻辑的主说明见 [../README.md](../README.md#主题--主文档权威分工)。

| 路径 | 内容 |
|------|------|
| `player/` | `Player.gd`、`CameraController.gd`、`MovementComponent.gd`、`player_view_paths.gd`（`class_name PlayerViewPaths`，第三人称/瞄准路径常量）、`camera_rig_fp.gd`（`class_name CameraRigFP`，`Scene/Player/CameraRigFP.tscn`）、`Scene/Player/ThirdPersonCameraRig.tscn` 等 |
| `gun/` | 武器基类、弹道、世界可拾取武器、音效池 |
| `enemy/` | 敌人与部位受击 → [ENEMY_SYSTEM.md](ENEMY_SYSTEM.md) |
| `SkillSystem/` | 技能实例与效果脚本 |
| `menu/` | 主菜单、设置、键位、角色信息、技能 UI、登录注册 |
| `map/` | 关卡与教程区域；其中 `map/training/training_ground.gd`：清剿 `traningBotSpawn` 下全部 `trainingBot` 实例后显示 **Teleport** 并允许进入 **game**（`SceneManager.change_scene("game")`） |
| `spaceship/` | 传送门、舱门等场景交互 |
| `npc/` | NPC 行为 |
| `Multiplayer/` | 联机相关 UI（若启用） |
| `helth_bar/` | 生命条 UI（路径名为历史拼写） |
| 根目录 | `world.gd`（`class_name World`）等关卡根脚本 |
| `core/` | `collision_layers.gd` → [COLLISION_LAYERS.md](COLLISION_LAYERS.md) |

**Autoload** 在 `res://autoload/` → [AUTOLOAD_AND_UI.md](AUTOLOAD_AND_UI.md)。**相机/移动** → [PLAYER_CAMERA_AND_MOVEMENT.md](PLAYER_CAMERA_AND_MOVEMENT.md)。
