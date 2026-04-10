# 敌人系统架构与需求对照

## 需求满足情况（摘要）

| 需求 | 状态 | 说明 |
|------|------|------|
| 行为树 AI | **部分** | `behavior_tree_id`、`ai_behavior_packs` 中 `bt:*` 已进库与 API；`EnemyBehaviorBrain` 负责路由。运行时仍由 `enemy.gd` 的 **FSM 兜底**（打印提示），接入 Godot BT 资源后在此加载即可。 |
| 阶层 NORMAL/SPECIAL/ELITE/BOSS | **已满足** | JSON `enemy_rank` → 库列 + API；`EnemyRank.gd` 乘子。**BOSS 数值乘子为 ×1**，避免与策划已拉满的 `base_*` 双重放大；高层差异靠 **技能 / 阶段 / BT**。 |
| 掉落（材料、货币等） | **已满足** | `metadata.drop_items` 数组 → `game.enemy_drops`；API 顶层 **`drops[]`**；`EnemyLootService` Roll 后进背包。货币即对应 `item_id`。 |
| 多套 AI / 组合加载 | **已满足** | **`ai_behavior_packs`** 字符串数组（`fsm:*` / `bt:*`），可叠加描述；客户端 `EnemyBehaviorBrain.get_ai_behavior_packs()`。 |
| 技能（强化/AOE/控制/特殊） | **数据已满足，执行渐进** | API 顶层 **`skills[]`**（`skill_id`、`skill_type`、`cooldown_s`、`params`）；`EnemySkillExecutor` 读取与按类型过滤。具体施放需动画/BT/脚本节点实现。 |
| 仇恨 | **已加强** | `EnemyAggroComponent`：伤害威胁、`apply_taunt`、**时间衰减**、可选 **距离外加速衰减**（`threat_radius_max`）。 |
| 模块化 / 数据驱动 / 可读 | **已满足** | 后端 schema + seeder + JSON 单源；Godot 分文件：`BaseEnemy`、`enemy.gd`、`EnemyRank`、`EnemyAggroComponent`、`EnemyLootService`、`EnemyBehaviorBrain`、`EnemySkillExecutor`。 |
| 精英/Boss 高于普通怪 | **已满足（机制向）** | 数据上：更多 `skills`、`boss_phases`、`bt:*` 包与非空 `behavior_tree_id`；数值上：BOSS 用表里大 `base_hp`，避免再叠 Rank 倍率。 |

## 数据流

1. **`game_data/enemies.json`** → `seeder.py` → `game.enemies`（含 **`enemy_rank`、`behavior_tree_id` 列** 与 **`extra_data`**）+ `game.enemy_drops`。
2. **`GET /game-data/enemies`** → `EnemyDefResponse`：顶层字段含 `enemy_rank`、`behavior_tree_id`、`ai_behavior_packs`、`skills`、`drops`；叙事与阶段在 **`metadata`**。
3. Godot **`GameDataManager`** 缓存整条字典；**`BaseEnemy.enemy_template_id`** 对齐 `enemy_id`。

## 模块路径

| 模块 | 路径 |
|------|------|
| 基类 | `Script/enemy/BaseEnemy.gd` |
| 近战 FSM | `Script/enemy/enemy.gd` |
| 阶层 | `Script/enemy/EnemyRank.gd` |
| 仇恨 | `Script/enemy/EnemyAggroComponent.gd`（子节点名 `AggroComponent`） |
| 掉落 | `autoload/EnemyLootService.gd` |
| BT / AI 路由 | `Script/enemy/EnemyBehaviorBrain.gd` |
| 技能数据 | `Script/enemy/EnemySkillExecutor.gd` |

## 与行为树的边界

BT 适合阶段、优先级、技能 CD。推荐：**BT 输出意图**（目标点、要放的 `skill_id`），**不绕过** `AttackData` / `Stats.take_damage`，以便基因、部位、经验、掉落一致。

## 已有库升级数据库

在 PostgreSQL 中执行：

`StarshipBackend/PSQL_DH/migrations/MIGRATION_2026_ENEMY_RANK_BT.sql`

然后：`python seeder.py`（或项目等价入口）刷新敌人行。

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
  "metadata": { "boss_phases": [], "ai_profile": {} }
}
```
