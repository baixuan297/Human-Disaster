# 伤害系统说明文档

本文档描述项目中**伤害计算**、**受击流程**与 **Stats** 的架构，涵盖角色、敌人、技能、武器的统一伤害路径。

---

## 一、核心原则

- **Stats** 为血量与属性的唯一来源，所有伤害统一走 `Stats.take_damage(AttackData)`。
- **AttackData** 为伤害数据载体，包含 `base_damage`、`final_damage`、`body_part_multiplier`、`source`（WEAPON/SKILL）等。
- 受击后 `Stats.health_changed` 发出，UI 监听并更新血条；`Stats.died` 发出时触发死亡逻辑。

---

## 二、伤害数据流

```mermaid
flowchart TB
    subgraph sources [伤害来源]
        Weapon[武器 / Bullet]
        Skill[技能 Skill]
        Enemy[敌人攻击]
    end
    subgraph attackData [AttackData]
        CreateWeapon[create_weapon_attack]
        CreateSkill[create_skill_attack]
        Manual[手动构造]
    end
    subgraph targets [受击目标]
        PlayerApply[Player.apply_attack_data]
        EnemyApply[BaseEnemy.apply_attack_data]
    end
    subgraph stats [Stats]
        TakeDamage[take_damage]
        HealthChanged[health_changed]
        Died[died]
    end
    subgraph ui [UI]
        PlayerUI[PlayerUIController.on_health_changed]
        EnemyBar[敌人血条 health_bar]
    end
    Weapon --> CreateWeapon
    Skill --> CreateSkill
    Enemy --> Manual
    CreateWeapon --> PlayerApply
    CreateSkill --> EnemyApply
    Manual --> PlayerApply
    PlayerApply --> TakeDamage
    EnemyApply --> TakeDamage
    TakeDamage --> HealthChanged
    TakeDamage --> Died
    HealthChanged --> PlayerUI
    HealthChanged --> EnemyBar
```

---

## 三、角色受击流程

```mermaid
sequenceDiagram
    participant Source as 伤害来源
    participant Player as Player
    participant Stats as playerStats
    participant UI as PlayerUIController
    Source->>Player: apply_attack_data(attack)
    Player->>Player: player_hit.emit
    Player->>Stats: apply_attack_data(attack)
    Stats->>Stats: take_damage(attack)
    Note over Stats: final_damage - defense
    Stats->>Stats: current_health -= actual_damage
    Stats->>Player: health_changed.emit
    Player->>Player: _on_stats_health_changed
    Player->>UI: health_changed.emit
    UI->>UI: on_health_changed 更新血条
```

---

## 四、敌人受击流程

```mermaid
sequenceDiagram
    participant Hitbox as 武器/技能 Hitbox
    participant Hurtboxes as Hurtboxes
    participant BaseEnemy as BaseEnemy
    participant Stats as stats
    participant HealthBar as health_bar
    Hitbox->>Hurtboxes: body_part_hit.emit(AttackData)
    Hurtboxes->>BaseEnemy: _on_area_3d_body_part_hit
    BaseEnemy->>BaseEnemy: enemy_hit.emit
    BaseEnemy->>Stats: take_damage(attack_data)
    Stats->>Stats: 防御减伤、扣血
    Stats->>BaseEnemy: health_changed.emit
    BaseEnemy->>HealthBar: health_bar.value = _health_percent
    Stats->>BaseEnemy: died.emit
    BaseEnemy->>BaseEnemy: _on_died 清理并 queue_free
```

---

## 五、敌人攻击角色流程

```mermaid
sequenceDiagram
    participant Enemy as enemy.gd
    participant AnimTree as AnimationTree
    participant MethodTrack as 攻击动画 Method Track
    participant Player as Player
    participant Stats as playerStats
    Enemy->>AnimTree: _anim_set "attack" true
    AnimTree->>MethodTrack: 命中帧调用 _hit_finished
    MethodTrack->>Enemy: _hit_finished
    Enemy->>Player: apply_attack_data(attack)
    Note over Enemy: attack 使用 stats.current_attack
    Player->>Stats: take_damage(attack)
    Stats->>Player: health_changed
    Player->>Player: PlayerUIController 更新血条
```

---

## 六、Stats.take_damage 计算逻辑

1. 使用 `AttackData.final_damage`（已含部位倍率）
2. 应用防御：`actual_damage = max(final_damage - current_defense, 0)`
3. 扣血：`current_health = clamp(current_health - actual_damage, 0, current_max_health)`
4. 发出 `health_changed(current_health, current_max_health)`
5. 若 `current_health <= 0`，发出 `died`

---

## 七、AttackData 构造方式

| 来源 | 构造方法 |
|------|----------|
| 武器 | `AttackData.create_weapon_attack(weapon_data, attacker)` |
| 技能 | `AttackData.create_skill_attack(skill_resource, level, caster)` |
| 敌人近战 | 手动 `AttackData.new()`，设置 `base_damage`、`final_damage`、`body_part_multiplier` |
| DOT/DEBUFF | 手动构造，`body_part_multiplier = 1.0` |

---

## 八、相关文件

| 文件 | 职责 |
|------|------|
| `resource/stats/stats.gd` | Stats 资源：take_damage、heal、recalculate_stats、health_changed、died |
| `resource/damageEvent/AttackData.gd` | 伤害数据：create_weapon_attack、create_skill_attack、apply_body_part_multiplier |
| `Script/player/Player.gd` | apply_attack_data、_on_stats_health_changed、health_changed 中继 |
| `Script/player/PlayerUIController.gd` | on_health_changed 更新血条 UI |
| `Script/enemy/BaseEnemy.gd` | _on_area_3d_body_part_hit、_on_health_changed、_on_died |
| `Script/enemy/enemy.gd` | _hit_finished 构造 AttackData 并调用 Player.apply_attack_data |
