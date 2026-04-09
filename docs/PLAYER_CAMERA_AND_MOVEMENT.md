# 玩家相机与移动（第一 / 第三人称）

本文说明 `Fish_Man` 上相机、移动输入与武器瞄准路径的**职责划分**与**约定路径**，与实现保持同步。

## 1. 职责划分（解耦）

| 模块 | 职责 | 不做什么 |
|------|------|----------|
| **Player.gd** | 组装依赖：`MovementComponent` 的 `Callable`、切相机 `make_current`、转发鼠标与物理帧里对 `CameraController` 的调用 | 不实现具体移动公式或弹簧臂避障 |
| **MovementComponent.gd** | 重力、状态机、速度、`move_and_slide`；`external_movement_basis_provider` + `remap_move_input` | 不引用 Camera；TP/FP 由 Player 的 Callable 区分 |
| **CameraController.gd** | FP：nek/head 旋转与 bob 目标；TP：Yaw/Pitch、枢轴跟随、弹簧臂长度（世界米÷scale）、锁定目标时转 Yaw、排除自身碰撞 | 不读 Input；不直接改 `CharacterBody3D.rotation` 做走路转身（避免带动子相机） |
| **WeaponManager.gd** | 解析 FP/TP 瞄准射线；默认 TP 路径来自 **`PlayerViewPaths`** | 不假设旧版 `thirdperson/Camera3D` 扁平结构 |
| **PlayerViewPaths**（`Script/player/player_view_paths.gd`） | 第三人称与瞄准相关 **NodePath / 相对 rig 子路径** 的唯一字面量来源 | 无运行时逻辑 |

走路时角色**模型**朝向由 `Player._apply_third_person_body_face_movement` 转 `player_mesh` 的 yaw；锁定目标时同样只扭网格 + `CameraController` 驱动相机 Yaw。

## 2. 场景结构

- **第一人称**：`firstperson/nek/head/CameraRigFP/FPCamera`（子场景 `CameraRigFP.tscn`）。
- **第三人称**：`thirdperson` 为 `ThirdPersonCameraRig.tscn` 实例，内部链为  
  `Yaw → Pitch → SpringArm3D → Camera3D（本地偏移越肩）→ Aimray / aimrayend`。
- **玩家根 `FishMan`** 常带 **非 1 缩放**（如 0.3）：`CameraController` 中枢轴高度与弹簧臂**目标长度按世界米计算**，再除以 `abs(scale.y)` 写回子节点本地值。

## 3. 输入与移动轴向

- `Input.get_vector`：`W` 时 `y` 为负。
- **第三人称**：`remap_move_input` 为恒等；Basis 来自 `CameraController.get_third_person_movement_basis()`（相机水平前向）。
- **第一人称**：`remap_move_input` 为 `Vector2(-x, -y)`，与历史 `(-input.x, 0, -input.y)` 等价，避免与旧模型前向冲突。

鼠标视角：`Player._on_input_mouse_moved` 以 **`third_person.is_current()`** 优先分支，避免 FP 相机仍 `is_current` 时双路旋转。

## 4. 修改清单（换 rig 或改名节点时）

1. `Scene/Player/ThirdPersonCameraRig.tscn`
2. `Script/player/player_view_paths.gd`
3. `Player.gd` 中若仍有硬编码子路径（应已无）
4. 检视器里 `Weapon_manager` 的 `weapon_bind_tp_*`（仅当偏离默认时）
5. 本文与 `WEAPON_SYSTEM.md` / `CHARACTER_AND_WEAPON_OVERVIEW.md`

## 5. 相关文件

| 文件 | 说明 |
|------|------|
| `Script/player/player_view_paths.gd` | 路径常量 `PlayerViewPaths` |
| `Script/player/Player.gd` | 编排与切视角 |
| `Script/player/MovementComponent.gd` | 移动 + Callable 注入点 |
| `Script/player/CameraController.gd` | 双模式相机逻辑 |
| `Scene/Player/ThirdPersonCameraRig.tscn` | 第三人称架 |
| `autoload/WeaponManager.gd` | 瞄准射线绑定（默认路径用 `PlayerViewPaths`） |

## 6. 运行时 API 约定（重构时同步调用方）

以下签名若有变更，应全库 `grep` 调用点（当前仅 `Player.gd` 组装）：

- **`MovementComponent.setup`**  
  `(character, input_controller, raycast3d, collision_stand, collision_crouch, head, animation_tree)` — 不再传入 `player_mesh`。
- **`CameraController.setup`**  
  `(character_body, nek, head, camera_rig_fp, third_person, t_person, speed_lerp, weapon_manager)` — 不再传入第一人称 `Camera3D`（未使用）。
- **`CameraController.update_third_person_camera`**  
  仅 `(delta: float)`；移动输入不参与 TP 相机更新。
- **水平移动 Basis**：`_get_movement_basis_for_current_person` 以 **`third_person.is_current()`** 为准，与 `remap_move_input`、鼠标分支一致。

## 7. 后端与数据库

- **无需**为第三人称相机 / `PlayerViewPaths` 修改 PostgreSQL 迁移或表结构。
- FastAPI 侧 `CharacterStatsSaveRequest` / `loadout` / `scene_state` 仍为通用 JSON，**不包含** Godot 节点路径或相机模式；与 [CharacterDataManager.md](CharacterDataManager.md) 持久化字段一致。
- 若未来增加「玩家设置」（如鼠标灵敏度、肩位左右），应使用**独立配置字段**或新表，勿塞进武器 `loadout`。
