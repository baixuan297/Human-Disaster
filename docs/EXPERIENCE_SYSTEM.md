# 角色经验与等级系统

本文说明 `Stats`（`resource/stats/stats.gd`）中的**总经验**、**等级计算**、**玩家与敌人两种成长模式**、**存档与信号**，以及与 UI、战斗掉落的衔接。

---

## 玩家 vs 敌人

| 模式 | `level_derived_from_experience` | 等级来源 | 经验 |
|------|----------------------------------|----------|------|
| **玩家** | `true`（默认） | 由累计 `experience` 公式推导，并受 `max_level` 限制 | 可获得，`gain_experience` 生效 |
| **敌人** | `false` | 仅 `fixed_combat_level`（在资源或检查器中设置） | 不获得；`gain_experience` 直接返回 `0`，`experience` 恒为 `0` |

敌人应使用如 `resource/stats/enemy_stats.tres` 的配置：`level_derived_from_experience = false`，按需调整 `fixed_combat_level`。击杀敌人仍通过 `BaseEnemy.experience_reward` 给**玩家**的 `player_stats` 加经验，而不是给敌人 Stats。

---

## 核心概念（玩家 / 经验模式）

| 字段 | 含义 |
|------|------|
| `experience` | **累计总经验**（非「当前级内余量」） |
| `base_exp_to_next_level` | 经验缩放系数 \(b\)，默认 `100` |
| `max_level` | 等级上限，默认 `30`；`≤ 0` 表示不封顶（调试） |
| `level` | **展示/属性曲线用等级**（玩家：由经验推导并封顶；敌人：即 `fixed_combat_level`） |

---

## 等级公式（仅当 `level_derived_from_experience` 为 true）

定义 \(b = \max(\texttt{base\_exp\_to\_next\_level}, 0.001)\)。

**原始等级**（忽略 `max_level`）：

\[
\texttt{raw\_level} = \left\lfloor \max\left(1,\ \sqrt{\dfrac{\texttt{experience}}{b}} + 0.5\right) \right\rfloor
\]

**有效等级**：

- 若 `max_level > 0`：`level = min(raw_level, max_level)`
- 若 `max_level ≤ 0`：`level = raw_level`（不封顶）

等级 \(L \ge 2\) 时，该级经验区间约为 \(\left[(L - 0.5)^2 \cdot b,\ (L + 0.5)^2 \cdot b\right)\)。  
\(L = 1\) 时 `get_level_experience_segment()` 使用上界 \( (1.5)^2 \cdot b \)（左端为 `0`）。敌人固定等级模式下该方法返回 `(0, 1)`，不参与 UI 经验条。

---

## 经验封顶（仅玩家）

当 `max_level > 0` 且使用经验模式时，总经验上限约为：

\[
\texttt{cap} = (\texttt{max\_level} + 0.5)^2 \cdot b - 0.01
\]

满级后 `gain_experience` 的返回值可能为 `0`。

---

## 代码入口

### 获得经验（仅玩家 Stats）

```gdscript
# 推荐：带来源键，便于调试与统一入口
var gained: float = player_stats.grant_experience_from_source(25.0, "my_quest")

# 或直接（击杀链内部仍走 grant → gain）
var gained2: float = player_stats.gain_experience(25.0)
```

### 只读查询

| 方法 | 作用 |
|------|------|
| `get_raw_level()` | 经验模式下 sqrt 公式原始等级（未应用 `max_level`） |
| `get_formula_raw_level()` | 公式等级并应用 `max_level`（**不含** SYNC 门闸） |
| `get_level_experience_segment()` | 经验模式下返回 `Vector2(lo, hi)` 供经验条（按**有效等级**与当前经验上限） |
| `get_next_sync_breakthrough_gate()` | 下一待突破门槛等级，无则 `-1` |
| `is_at_sync_experience_cap()` / `is_sync_breakthrough_available()` | 是否攒满当前段经验 / 是否可点突破 |
| `attempt_sync_breakthrough_for_next_gate()` | 扣材料、写入 `sync_breakthroughs_completed`、抬升经验至该档下限 |

### 信号

| 信号 | 触发时机 |
|------|----------|
| `health_changed(current_health, maximum_health)` | 生命变化 |
| `experience_changed(total_experience, current_level)` | 总经验被写入（玩家）；敌人仅在 setter 同步时可能发出 |
| `character_level_up(new_level)` | **仅玩家**且等级数字上升 |
| `experience_gained(amount_added)` | **仅玩家**，`gain_experience` 实际增加量（已含基因经验加成） |
| `sync_breakthrough_succeeded(gate_level)` | 成功完成一档 SYNC 材料突破 |

`load_from_dict()` 先恢复 `sync_breakthroughs_completed` 再写入 `experience`，避免门闸错位；写入玩家经验时会短暂置 `_mute_level_up_signal`，避免登录误弹升级提示。敌人模式下不从字典写入 `experience`。

---

## 与战斗的衔接

- 敌人：`BaseEnemy` 经 **`ExperienceRewards.grant(..., "enemy_kill")`**（回退为直接 `Stats.grant_*`），含等级差倍率。
- 玩家：`Player.gd` 连接 `character_level_up` → `GBMssage` 升级提示；连接 `experience_gained` → `PlayerUIController` 合并飘字。

---

## 存档与 API

- 玩家：`save_to_dict()` / `load_from_dict()` 读写 **`experience`** 与 **`sync_breakthroughs_completed`**（与 `game.character_stats.sync_breakthroughs_completed`、FastAPI `CharacterStatsResponse` / `SaveRequest` 对齐）。
- 敌人：资源侧不依赖经验；若对敌人调用 `load_from_dict()`，将跳过经验写入并保持 `experience = 0`。

---

## 经验来源与扩展约定

| 来源类型 | 推荐接入方式 | 说明 |
|----------|----------------|------|
| 任意玩法 | **`ExperienceRewards.grant(player_stats, amount, "quest:foo", { ... })`** | Autoload 单点扩展：未来可按 `source_key` / `context` 挂表倍率、活动加成、埋点，而不改各任务脚本 |
| 击杀敌人 | 已由 `BaseEnemy` → `ExperienceRewards.grant(..., "enemy_kill")` | 含等级差倍率；仍进 `Stats.gain_experience`（基因经验加成、门闸封顶） |
| 任务 / 探索 / 活动 | `ExperienceRewards.grant` 或 `Stats.grant_experience_from_source` | **禁止**直接改 `experience` 绕过封顶与信号 |
| 调试 / 作弊面板 | 可临时 `gain_experience` | 发版路径应仍走 `ExperienceRewards` / `grant_*` |

新增玩法时：优先经 **`ExperienceRewards`**，避免在任务/副本中散落重复逻辑。

---

## 与 FastAPI（基因等级推导）的对齐

服务端 `_effective_character_level_for_genes` 使用与客户端一致的：

- `EXPERIENCE_SCALING_B`、`EXPERIENCE_DERIVED_MAX_LEVEL_CAP`
- **`DEFAULT_SYNC_BREAKTHROUGH_GATE_LEVELS`**（默认 `(20, 25, 30)`，与 `Stats.DEFAULT_SYNC_BREAKTHROUGH_GATES` 一致）
- 角色 **`sync_breakthroughs_completed`** JSON 数组，参与 **`effective_level_from_raw_and_breakthroughs`**

**约定**：改 `base_exp_to_next_level`、`max_level`、默认门槛数组或门闸规则时，须同步 **Godot / main.py / pytest**。

---

## SYNC 突破门闸（材料 + 经验攒满）

- **非门槛区间**：`Stats.level` 随经验按原公式自动提升（仍受 `max_level` 与基因加成影响）。
- **门槛等级**：默认 **`20 / 25 / 30`**（可在 Inspector 改 `sync_breakthrough_gate_levels`；**须与后端默认数组一致**，否则服务端基因等级会漂移）。到达「公式等级 ≥ 门槛」前需将该门槛记入 `sync_breakthroughs_completed`；否则 **有效等级**被压在 **`门槛 − 1`**。
- **经验积累**：在下一门槛未突破时，经验可继续涨到 **当前段上限**（至「进入下一公式等级」前一刻）；`gain_experience` 在达到该上限后 **不再增加**（表现为满条但等级不升）。
- **突破**：`attempt_sync_breakthrough_for_next_gate()` 要求 **已达本段经验上限** 且 **`sync_breakthrough_costs` 材料足够**（空数组表示该档仅需经验满）；成功后写入 `sync_breakthroughs_completed`，并把经验抬到该档公式下限，随后可继续升级与获得经验。
- **UI**：`attributes_panel` 在可突破时启用「突破」按钮，成功后 `CharacterDataManager.save_to_api(..., true)`。
- **迁移**：已有库执行 `MIGRATION_2026_SYNC_BREAKTHROUGH.sql`。

---

## HUD 轻量反馈（获得经验）

- `Stats` 在 `gain_experience` 实际增加经验时发出 **`experience_gained(amount_added: float)`**（已含基因经验加成后的增量）。
- `Player` → `PlayerUIController.on_experience_gained`：短时合并多次获得，约 **0.45s** 合并为一条提示，减轻连续击杀刷屏。

---

## 相关文件

| 路径 | 说明 |
|------|------|
| `autoload/ExperienceRewards.gd` | 经验奖励统一入口（任务/活动等扩展点） |
| `resource/stats/stats.gd` | 双模式等级、SYNC 门闸、`gain_experience` / `grant_*`、突破与 `sync_breakthroughs_completed` 序列化 |
| `resource/stats/player_stats.tres` | 玩家默认（`level_derived_from_experience = true`） |
| `resource/stats/enemy_stats.tres` | 敌人默认（固定等级） |
| `Script/menu/characterInfo/attr_panel/attributes_panel.gd` | 玩家经验条 |
| `Script/enemy/BaseEnemy.gd` | 击杀奖励与等级差倍率 → `ExperienceRewards.grant` |
| `Script/player/Player.gd` | `player_stats`、升级提示、`experience_gained` → HUD |
| `Script/player/PlayerUIController.gd` | 合并经验飘字提示 |
| `StarshipBackend/PSQL_DH/main.py` | `EXPERIENCE_*`、`DEFAULT_SYNC_BREAKTHROUGH_GATE_LEVELS`、`effective_level_from_raw_and_breakthroughs`、`_effective_character_level_for_genes` |
| `StarshipBackend/PSQL_DH/tests/test_experience_level_math.py` | 等级推导快照测试 |
