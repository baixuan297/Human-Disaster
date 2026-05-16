# Hazard 系统对齐检查清单

## 一、Godot 客户端

| 文件 | 状态 | 说明 |
|------|------|------|
| `resource/hazard/hazard.gd` | ✅ | HazardType 枚举 (FIRE/POISON/THORNS/OTHER)，create_attack_data 传递 hazard_type |
| `resource/damageEvent/AttackData.gd` | ✅ | hazard_sub_type、create_hazard_attack(damage, node, hazard_type)、get_hazard_type_name |
| `Script/poison_pool.gd` | ✅ | 仅使用 hazard_data，无则 push_warning，_apply_damage 用 hazard_data.create_attack_data |
| `resource/stats/stats.gd` | ✅ | fire/poison/thorns/other_resistance，load/save，take_damage 抗性计算 |
| `autoload/CharacterDataManager.gd` | ✅ | fallback 含抗性字段 |

## 二、后端数据库

| 项 | 状态 | 说明 |
|------|------|------|
| `DesastreHuman.sql` | ✅ | hazard_type_enum 枚举定义 + 四抗性列（单一基线） |

**部署**：**空库**执行 `psql -v ON_ERROR_STOP=1 -f StarshipBackend/PSQL_DH/DesastreHuman.sql`。已有库结构变更请单独写增量 SQL 或重建库。

## 三、后端 API

| 文件 | 状态 | 说明 |
|------|------|------|
| `models.py` | ✅ | CharacterStats 含 fire/poison/thorns/other_resistance |
| `schemas.py` | ✅ | CharacterStatsResponse、CharacterStatsSaveRequest 含抗性字段 |
| `main.py` | ✅ | save_character_stats 写入抗性并 clamp 0~1 |

## 四、类型映射（统一）

| Hazard.HazardType | 整型 | 抗性字段 | SQL enum |
|-------------------|------|----------|----------|
| FIRE | 0 | fire_resistance | FIRE |
| POISON | 1 | poison_resistance | POISON |
| THORNS | 2 | thorns_resistance | THORNS |
| OTHER | 3 | other_resistance | OTHER |

## 五、数据流

```
poison_pool: hazard_data(Hazard) → create_attack_data(node)
    → AttackData.hazard_sub_type
    → Player/BaseEnemy.apply_attack_data(attack)
    → Stats.take_damage(attack)
    → 防御减伤 → 抗性乘算 → 至少 1 点 → 扣血 → health_changed
```

## 六、API 对接

- **LOAD**：GET /characters/{id}/stats 返回 fire_resistance 等 → Godot load_from_dict
- **SAVE**：Godot save_to_dict 含抗性 → POST /characters/{id}/stats
