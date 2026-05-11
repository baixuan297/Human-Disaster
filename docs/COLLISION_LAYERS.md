# 三维物理层（Layer）与掩码（Mask）约定

本文档与 `project.godot` 中 `[layer_names]`、`Script/core/collision_layers.gd`（`class_name CollisionLayers`）保持一致，便于射线、技能范围与角色移动统一配置。

**引擎能力**：Godot 4 的 **3D 物理层固定为 32 个**（位 **0～31**，对应编辑器中的第 **1～32** 层）。本工程在 `project.godot` 为 **第 1～9 层** 填写了语义化名称；**第 10～32 层** 未命名，可作为将来扩展保留。若新功能占用这些层，须同步：编辑器层名、`CollisionLayers` 常量、本文档与依赖该层的场景/射线。

---

## 1. 层编号与名称（`3d_physics`）

| 层 | 位值（`collision_layer`） | 名称 | 典型用途 |
|----|----------------------------|------|----------|
| 1 | `1` | **World** | 地形、静态障碍、可行走表面 |
| 2 | `2` | **Character** | 玩家与敌人的 `CharacterBody3D` 主体 |
| 3 | `4` | **Hurtbox** | 受击用 `Area3D`（部位判定、`enemy_hit`） |
| 4 | `8` | **SkillArea** | 可选：专用技能检测体（当前多数技能用 Character + 组筛选） |
| 5 | `16` | **Pickup** | 可拾取武器等 `RigidBody3D`（`weapon_pickup`） |
| 6 | `32` | **PhysicsProp** | 可推动刚体、`moveObject` |
| 7 | `64` | **Interactable** | 门、终端等 `Interactable` |
| 8 | `128` | **GameplayVolume** | 玩法触发体积、相机相关等 |
| 9 | `256` | **Tutorial** | 教程区 `Area3D`、教程传送（与按 **E** 交互的宝箱分层分离；宝箱用 **Interactable**） |

---

## 2. 代码中的常量

在 GDScript 中优先使用 **`CollisionLayers.*`**，避免散落魔法数字：

| 常量 | 数值（掩码） | 说明 |
|------|--------------|------|
| `LAYER_TUTORIAL` | `256` | 教程触发区（第 9 命名层） |
| `MASK_BULLET` | `6` | `Character \| Hurtbox`，子弹/瞬时命中 |
| `MASK_AIM_TARGET` | `6` | 与上相同，瞄准/技能指示 |
| `MASK_SKILL_BODY` | `2` | 仅角色刚体（技能 `body_entered`） |
| `MASK_WORLD` | `1` | 地面射线、贴地 |
| `MASK_PLAYER_MOVE` | `499` | 含 **`Tutorial`**：与教程触发区、传送门等 `Area3D` 双向检测 |
| `MASK_SKILL_MOUSE_RAY` | `7` | 鼠标技能射线：`World \| Character \| Hurtbox` |
| `LAYER_PLAYER_BODY` | `194` | 玩家根节点 `collision_layer`：`Character \| Interactable \| GameplayVolume` |
| `MASK_ENEMY_MOVE` | `35` |敌人主体：`World \| Character \| PhysicsProp` |
| `MASK_INTERACT_RAY` | `211` | 交互射线：含 **Interactable**，不含 **Tutorial**（教程区由身体碰撞触发） |
| `MASK_PICKUP_RAY` | `49` | 短距捡物：`World \| Pickup \| PhysicsProp` |

---

## 3. 已对齐的资源（节选）

- **玩家**：`Fish_Man.tscn` 根节点 `collision_layer = 194`、`collision_mask = 499`（`MASK_PLAYER_MOVE`）；`Player.gd` 技能鼠标射线见 `MASK_AIM_TARGET` / `MASK_SKILL_MOUSE_RAY`。  
- **教程**：`TutorialZone.gd` 在 `_ready` 将自身置于 **`LAYER_TUTORIAL`**，`collision_mask = LAYER_PLAYER_BODY`；`tutorial_scene.tscn` 的 **TeleportArea** 同层；未完成教程时主菜单与模式选择页逻辑见 `CharacterDataManager.fetch_stats_snapshot_for_menu` 与 `main_menu.gd` / `chosegamemode.gd`。  
- **宝箱（世界）**：`world.tscn` 中 `chest` 使用 **Tutorial（256）**，交互射线掩码须含该层（`CameraRigFP` **467**）。  
- **敌人**：`alien.tscn` / `zombie.tscn` 主体为 **Character（掩码 2）**，`collision_mask = 35`（`MASK_ENEMY_MOVE`）；部位 **Hurtbox** 为命名第 **3** 层（位掩码 **4**），`collision_mask = 0`。  
- **训练用敌人**：`trainingBot.tscn` 与上述敌人一致（主体 **2 / 35**，`Hurtboxes` **4 / 0**）。  
- **子弹**：`bullet.tscn` 内 `RayCast3D` 使用 `MASK_BULLET`（`6`）。  
- **武器拾取**：`pickable_weapon_*.tscn` 使用 **Pickup** 层，交互射线掩码含 **Pickup**。  
- **第一人称相机**：`CameraRigFP.tscn` 中交互射线 `collision_mask = 211`（`MASK_INTERACT_RAY`），`pickray` = `49`（`MASK_PICKUP_RAY`）。  
- **技能范围**：火球/雷电/群体治疗等 `Area3D` 对 **Character** 层检测（`collision_mask = 2`，并结合 `global_group`等逻辑筛选）。  
- **飞船场景传送门**：`Scene/map/terrain.tscn` 中 `portal`（`Area3D`）置于 **GameplayVolume（128）**，`collision_mask` 含 **Character（2）**，以便 `body_entered` 检测到 `Player` 组角色。  
- **小游戏关卡地面**：`Scene/map/miniGame/mini_game.tscn` 中 `GridMap` 为静态地表，使用 **World（1）**，`collision_mask = 0`。

---

## 4. 修改层时的检查清单

1. 更新 `project.godot` 的 `layer_n` 名称。  
2. 在 `collision_layers.gd` 中增加或调整常量，并更新本文档表格。  
3. 搜索工程内仍写死的 `collision_mask =` / `collision_layer =`，改为常量或注明与表一致。  
4. 射线若需新层，同步 **交互**、**拾取**、**瞄准** 三条射线，避免「看得见提示却捡不起来」。

---

## 5. 相关脚本

| 文件 | 说明 |
|------|------|
| `Script/core/collision_layers.gd` | 位掩码与组合常量 |
| `Script/map/tutorial/TutorialZone.gd` | 教程触发 `Area3D` 的 layer/mask |
| `Script/player/Player.gd` | 技能鼠标射线 `collision_mask` |
| `autoload/CharacterDataManager.gd` | `fetch_stats_snapshot_for_menu`、教程完成标记 |
| `Script/enemy/BaseEnemy.gd` | 生成贴地射线与 `LAYER_WORLD` 合并 |
| `Script/SkillSystem/Skill.gd` | 技能落点地面射线 |
| `Script/poison_pool.gd` | 毒池对 **Character** 层 |
