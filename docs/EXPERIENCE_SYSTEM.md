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
var gained: float = player_stats.gain_experience(25.0)
```

### 只读查询

| 方法 | 作用 |
|------|------|
| `get_raw_level()` | 经验模式下未应用 `max_level` 的原始等级 |
| `get_level_experience_segment()` | 经验模式下返回 `Vector2(lo, hi)` 供经验条 |

### 信号

| 信号 | 触发时机 |
|------|----------|
| `health_changed(current_health, maximum_health)` | 生命变化 |
| `experience_changed(total_experience, current_level)` | 总经验被写入（玩家）；敌人仅在 setter 同步时可能发出 |
| `character_level_up(new_level)` | **仅玩家**且等级数字上升 |

`load_from_dict()` 写入玩家经验时会短暂置 `_mute_level_up_signal`，避免登录误弹升级提示。敌人模式下不从字典写入 `experience`。

---

## 与战斗的衔接

- 敌人：`BaseEnemy.experience_reward` → 击杀后给玩家 `player_stats.gain_experience(...)`。
- 玩家：`Player.gd` 连接 `player_stats.character_level_up` → `GBMssage` 提示升级。

---

## 存档与 API

- 玩家：`save_to_dict()` / `load_from_dict()` 正常读写 `experience`。
- 敌人：资源侧不依赖经验；若对敌人调用 `load_from_dict()`，将跳过经验写入并保持 `experience = 0`。

---

## 相关文件

| 路径 | 说明 |
|------|------|
| `resource/stats/stats.gd` | 双模式等级、经验、信号、曲线 |
| `resource/stats/player_stats.tres` | 玩家默认（`level_derived_from_experience = true`） |
| `resource/stats/enemy_stats.tres` | 敌人默认（固定等级） |
| `Script/menu/characterInfo/attr_panel/attributes_panel.gd` | 玩家经验条 |
| `Script/enemy/BaseEnemy.gd` | 击杀奖励经验 |
| `Script/player/Player.gd` | `player_stats`、升级提示 |
