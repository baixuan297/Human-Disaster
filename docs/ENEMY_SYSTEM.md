# 敌人系统（数据 + Godot 运行时）
[← 文档索引](../README.md#文档索引)

**敌人数据与运行时** 的主文档：静态数据管线、模块路径、受击/近战/生成等行为。

---

## 与其它文档的分工

| 主题 | 本文档中的位置 | 其它文档 |
|------|----------------|----------|
| 敌人模板 API、`enemy_template_id` | [数据流](#数据流)、[模块路径](#模块路径) | [GameDataManager.md](GameDataManager.md) 仅保留查询 API 表 |
| `Stats.take_damage`、防御、抗性、AttackData 字段 | 仅 [玩家击中敌人](#玩家击中敌人) 链一句 | **[DAMAGE_SYSTEM.md](DAMAGE_SYSTEM.md)** 为伤害公式与 Stats 主文档 |
| `vs_targets`、`combat_tags`、暴击附加 | [玩家击中敌人](#玩家击中敌人) | **[GENE_SYSTEM.md](GENE_SYSTEM.md)** 为基因字段与 GeneManager |
| 击杀经验、`experience_reward` | 一句 + 链 | **[EXPERIENCE_SYSTEM.md](EXPERIENCE_SYSTEM.md)** |
| 武器/技能弹道如何造 AttackData | 不写 | [WEAPON_SYSTEM.md](WEAPON_SYSTEM.md)、[SKILL_SYSTEM.md](SKILL_SYSTEM.md) |

---

## 需求满足情况（摘要）

| 需求 | 状态 | 说明 |
|------|------|------|
| 行为树 AI | **部分** | `behavior_tree_id`、`ai_behavior_packs` 中 `bt:*` 已进库与 API；`EnemyBehaviorBrain` 负责路由。运行时仍由 `enemy.gd` 的 **FSM 兜底**（打印提示），接入 Godot BT 资源后在此加载即可。 |
| 阶层 NORMAL/SPECIAL/ELITE/BOSS | **已满足** | JSON `enemy_rank` → 库列 + API；`EnemyRank.gd` 乘子。**BOSS 数值乘子为 ×1**，避免与策划已拉满的 `base_*` 双重放大；高层差异靠 **技能 / 阶段 / BT**。 |
| 掉落（材料、货币等） | **已满足** | `metadata.drop_items` 数组 → `game.enemy_drops`；API 顶层 **`drops[]`**；`EnemyLootService` Roll 后进背包。货币即对应 `item_id`。 |
| 多套 AI / 组合加载 | **已满足** | **`ai_behavior_packs`** 字符串数组（`fsm:*` / `bt:*`），可叠加描述；客户端 `EnemyBehaviorBrain.get_ai_behavior_packs()`。 |
| 技能（强化/AOE/控制/特殊） | **数据已满足，执行渐进** | API 顶层 **`skills[]`**（`skill_id`、`skill_type`、`cooldown_s`、`params`）；`EnemySkillExecutor` 读取与按类型过滤。具体施放需动画/BT/脚本节点实现。 |
| 仇恨 | **已加强** | `EnemyAggroComponent`：伤害威胁、`apply_taunt`、**时间衰减**、可选 **距离外加速衰减**（`threat_radius_max`）。 |
| 模块化 / 数据驱动 / 可读 | **已满足** | 后端 schema + seeder + JSON 单源；Godot 分文件见 [模块路径](#模块路径)。 |
| 精英/Boss 高于普通怪 | **已满足（机制向）** | 数据上：更多 `skills`、`boss_phases`、`bt:*` 包与非空 `behavior_tree_id`；数值上：BOSS 用表里大 `base_hp`，避免再叠 Rank 倍率。 |

---

## 数据流

1. **`game_data/enemies.json`** → `seeder.py` → `game.enemies`（含 **`enemy_rank`、`behavior_tree_id` 列** 与 **`extra_data`**）+ `game.enemy_drops`。
2. **`GET /game-data/enemies`** → `EnemyDefResponse`：顶层字段含 `enemy_rank`、`behavior_tree_id`、`ai_behavior_packs`、`skills`、`drops`；叙事与阶段在 **`metadata`**。
3. Godot **`GameDataManager`** 缓存整条字典；**`BaseEnemy.enemy_template_id`** 对齐 `enemy_id`。

---

## 模块路径

| 模块 | 路径 |
|------|------|
| 基类 | `Script/enemy/BaseEnemy.gd` |
| 近战宿主（导出参数 + `_hit_finished`） | `Script/enemy/enemy.gd` |
| 近战状态机 | `Script/enemy/EnemyMeleeFsm.gd` |
| 平面移动 / 巡逻采样 | `Script/enemy/EnemyMeleeLocomotion.gd` |
| 动画条件（AnimationTree `parameters/conditions/*`） | `Script/enemy/EnemyAnimationConditions.gd` |
| 目标解析与索敌距离 | `Script/enemy/EnemyCombatTargeting.gd` |
| 静态 `metadata.ai_profile` → 宿主导出 | `Script/enemy/EnemyAiProfileBinding.gd` |
| 部位倍率 → `body_part_hit` | `Script/enemy/bodypart.gd` |
| 阶层 | `Script/enemy/EnemyRank.gd` |
| 仇恨 | `Script/enemy/EnemyAggroComponent.gd`（子节点名 **`AggroComponent`** 或场景里现有命名） |
| 掉落 | `autoload/EnemyLootService.gd` |
| BT / AI 路由 | `Script/enemy/EnemyBehaviorBrain.gd` |
| 技能数据读取 | `Script/enemy/EnemySkillExecutor.gd` |
| 关卡内生成示例 | `Script/world.gd`（`_on_alienspawn_timeout` 等） |

---

## Godot 运行时行为

### 玩家击中敌人

1. 武器/技能命中 **Hurtboxes**（`bodypart.gd`）→ `body_part_hit.emit(AttackData)` → **`BaseEnemy._on_area_3d_body_part_hit`**。
2. **`_apply_attacker_gene_modifiers`**（仅 WEAPON/SKILL，且来源关联玩家）：按 **`combat_tags`** 与基因 `vs_targets` 修正 `final_damage`；暴击时附加与目标当前生命相关的加成（见 [GENE_SYSTEM.md](GENE_SYSTEM.md)）。
3. **`stats.take_damage(attack_data)`**；扣血、死亡、经验与掉落见 [DAMAGE_SYSTEM.md](DAMAGE_SYSTEM.md)、[EXPERIENCE_SYSTEM.md](EXPERIENCE_SYSTEM.md)。

另：**`BaseEnemy.apply_attack_data`**、**`apply_dot`** 供技能等直接调用，同样最终进 `Stats.take_damage`（起身无敌见下节）。

### 近战 AI（FSM）与动画树条件（alien 参考实现）

本项目目前的敌人“行为树”运行时仍以 **FSM** 为主（`EnemyMeleeFsm`），动画表现由 **AnimationTree 条件**驱动：

- **宿主**：`Script/enemy/enemy.gd`（薄封装）负责 `_process` 中驱动 FSM，且提供 `_hit_finished()` 供 AnimationTree Method 轨回调出手帧。
- **FSM**：`Script/enemy/EnemyMeleeFsm.gd` 负责状态与移动/攻击判定。
- **动画条件**：`Script/enemy/EnemyAnimationConditions.gd` 统一写 `AnimationTree.parameters/conditions/*`，避免散落路径字符串。

当前常用条件（`alien.tscn` 已包含）：

- `run`：追击/移动动画
- `attack`：攻击动画
- `die`：死亡动画
- `idle`：待机动画
- `look`：观察动画（站桩）
- `alert`：警觉/尖叫（Screaming）动画（站桩）

关键语义（用于对齐设计稿/动画树）：

- **Stand Up / get_up（起身）**：完全站桩，不移动；并且处于起身状态时免疫伤害（见下节）。
- **IDLE**：站桩，可受伤、可死亡；检测到目标进入 `detection_range` 后进入 **LOOK**。
- **LOOK**：站桩、面朝目标（仅旋转不移动），可受伤可死亡；距离进入 `alert_range` 后进入 **ALERT**。
- **ALERT（Screaming）**：站桩、面朝目标；**不扣血**（命中可触发仇恨与“进入警觉”但不会调用 `Stats.take_damage`）。只有当 AnimationTree 状态机当前节点切到 **`run`**（表示 Screaming 动画结束并过渡完成）后，FSM 才进入 **CHASE** 并开始移动。
- **CHASE**：只有当 AnimationTree 当前状态为 **`run`** 时才允许移动，避免“动画没切完但角色滑步”。
- **脱战**：距离超出 `lose_target_range` 或目标无效时回到锚点（最近一次 idle/巡逻停点）并保持 idle。

可调参数（`enemy.gd` 导出，亦可由静态数据 `metadata.ai_profile` 覆盖同名项）：

- `detection_range`：进入观察范围阈值（触发 LOOK）
- `alert_range`：触发警觉阈值（LOOK → ALERT）
- `lose_target_range`：脱战阈值（CHASE → RETURN/IDLE）

### 起身阶段无敌

- **`BaseEnemy.is_intro_getup_invulnerable()`**：读取子节点 **`AnimationTree`** 的 **`parameters/playback`**（`AnimationNodeStateMachinePlayback`），若当前状态名在 **`intro_getup_state_names`** 内则视为无敌。
- 默认状态名：**`Stand Up`**（如 `Scene/npc/enemy/alien.tscn`）、**`get_up`**（如 `zombie.tscn`）。可按敌人在检视器增删。
- 无敌期间：**`_on_area_3d_body_part_hit`**、**`apply_attack_data`** 直接返回；**`apply_dot`** 当跳不扣血、不消耗 tick，仅延后下一跳。

### 生成与世界坐标

- 将实例挂到带变换的父节点（如 `NavigationRegion3D`）后，应设置 **`global_position`**，勿把世界坐标误赋给 **`position`**（本地坐标）。示例：`Script/world.gd` 中 alien 生成。
- 若父节点存在 **缩放**（例如关卡整体缩放），建议 **先 `add_child` 入树，再设置 `global_position`**，避免入树前设置世界坐标在入树后被当作本地坐标、从而继承缩放导致模型“变大/变小”。
- **`BaseEnemy`**：`snap_to_floor_on_spawn` 为真时，`_ready` 里 `call_deferred` 向下射线，将 **`global_position.y`** 对齐地面（射线 mask 与 **`collision_mask | 1`** 合并，避免敌人 mask 不含地形层时打不中）。导出项可调射线高度、深度与 **`floor_snap_vertical_padding`**。
- `Script/world.gd` 额外提供 **范围刷怪 + 避免重叠** 的示例参数（以 `stage/spawns/spawns4` 为中心，半径 `alien_spawn_radius`，最小间距 `alien_spawn_min_separation`，最多尝试 `alien_spawn_max_attempts` 次）；并在生成后 `call_deferred("resnap_to_floor")` 以复用敌人贴地逻辑再次贴地。

### 敌人近战与命中判定

近战伤害**不是**拳头碰撞体扫到玩家，而是由 **`EnemyMeleeFsm`** 在动画 **Method 轨** 调用 **`enemy.gd._hit_finished()`** → **`on_hit_finished()`** 内构造 **`AttackData`**（WEAPON，`source_node` 为敌人，`final_damage` 常用 **`stats.current_attack`**），再 **`Player.apply_attack_data`**。

为避免 **大号胶囊 + 双 CharacterBody 挤开** 导致 **3D 距离仍大于 `attack_range`**（进不了 ATTACK 或出手帧打空）：

- **平面距离**：进入攻击、维持攻击、出手命中判定使用 **XZ 与目标的水平距离**（`_melee_plane_dist_to_target()`），避免身高/枢轴拉高 3D 距离。
- **`attack_range_slack`**：`enemy.gd` 导出，默认约 **`0.75`**，用于「**平面距离 ≤ attack_range + slack**」才进入 **`State.ATTACK`**。静态数据里 **`metadata.ai_profile`** 可通过 **`EnemyAiProfileBinding`** 写入同名键。
- 出手帧允许距离略宽于旧版常量（见 **`EnemyMeleeFsm`** 内 **`_ON_HIT_RANGE_BONUS`**、**`_ATTACK_CANCEL_PLANE_EXTRA`**）。
- **动画 Method 轨**必须调用到挂 **`enemy.gd`** 的 **`CharacterBody3D`**：`AnimationPlayer` 建议显式 **`root_node = NodePath("..")`**（父节点即敌人根），避免轨路径 **`"."`** 误绑到 **`AnimationPlayer`** 自身导致 **`_hit_finished` 永不执行**。
- **场景碰撞**：例如 alien 根缩放 **0.4** 时胶囊仍不宜过大；**`NavigationAgent3D.radius`** 建议与体宽同量级，避免寻路停点与物理体不一致。

**索敌**：`EnemyCombatTargeting.resolve_combat_target` 优先 **`EnemyAggroComponent`**，否则 **`"Player"`** 组。脱战距离仍可用 **3D 距离**（与平面近战判定分工不同）。

### 与行为树的边界

BT 适合阶段、优先级、技能 CD。推荐：**BT 输出意图**（目标点、要放的 `skill_id`），**不绕过** `AttackData` / `Stats.take_damage`，以便基因、部位、经验、掉落一致。

---

## 已有库升级数据库

在 PostgreSQL 中执行：

数据库需包含 `enemy_rank`、`behavior_tree_id` 等列（由游戏 API 侧迁移维护；客户端只消费 `/game-data/enemies`）

然后：`python seeder.py`（或项目等价入口）刷新敌人行。

---

## API 条目字段示意

```json
{
  "enemy_id": 4001005,
  "enemy_rank": "ELITE",
  "behavior_tree_id": "BT_Elite_Quantum_V1",
  "ai_behavior_packs": ["bt:elite_skirmish", "fsm:melee_basic"],
  "skills": [
    { "skill_id": "phase_shift", "skill_type": "SPECIAL", "cooldown_s": 4.0, "params": {} }
  ],
  "drops": [{ "item_id": 1001003, "drop_rate": 0.2, "min_qty": 1, "max_qty": 1 }],
  "metadata": { "boss_phases": [], "ai_profile": { "attack_range": 2.5, "attack_range_slack": 0.8 } }
}
```

`ai_profile` 中键名与 **`enemy.gd`** 导出一致时由 **`EnemyAiProfileBinding`** 写入宿主（见该脚本 **`_PROFILE_KEYS`**）。
