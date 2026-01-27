extends Node
class_name CombatCalculator

## ════════════════════════════════════════════════════════════
## 战斗计算工具类 - 集中处理所有伤害计算
## ════════════════════════════════════════════════════════════
## 职责：
## 1. 统一伤害计算逻辑
## 2. 处理暴击、防御、元素等复杂计算
## 3. 避免计算逻辑分散在各处
## ════════════════════════════════════════════════════════════


## 计算最终伤害（在 Stats.take_damage() 之前调用）
static func calculate_final_damage(attack_data: AttackData, defender_stats: Stats) -> float:
	if attack_data == null or defender_stats == null:
		push_error("CombatCalculator: 攻击数据或防御者属性为空")
		return 0.0
	
	var damage: float = attack_data.final_damage
	
	# 应用防御减伤
	var actual_damage = max(damage - defender_stats.current_defense, 0.0)
	
	# TODO: 可扩展部分
	# - 元素克制计算
	# - 暴击伤害加成
	# - 护甲穿透
	# - Buff/Debuff 加成
	
	return actual_damage


## 计算暴击
static func try_critical_hit(base_crit_rate: float, base_crit_damage: float) -> Dictionary:
	var is_crit := randf() < base_crit_rate
	var multiplier := base_crit_damage if is_crit else 1.0
	
	return {
		"is_critical": is_crit,
		"multiplier": multiplier
	}

## 计算技能伤害（在技能释放时调用）
static func calculate_skill_damage(skill_res: SkillResource, skill_level: int, attacker_stats: Stats = null) -> float:
	if skill_res == null:
		return 0.0
	
	var base_dmg := skill_res.get_damage(skill_level)
	
	# 如果技能需要攻击力加成
	if attacker_stats:
		var attack_bonus := attacker_stats.current_attack * 0.5  # 50% 攻击力转化
		base_dmg += attack_bonus
	
	return base_dmg


## 计算武器伤害（在射击时调用）
static func calculate_weapon_damage(weapon: WeaponData, attacker_stats: Stats = null) -> float:
	if weapon == null:
		return 0.0
	
	var base_dmg := weapon.Current_damage
	
	# 暴击判定（示例）
	if randf() < weapon.crit_rate:
		base_dmg *= weapon.crit_multiplier
	
	return base_dmg


## 格式化伤害数字显示
static func format_damage_text(damage: float, is_critical: bool = false) -> String:
	if is_critical:
		return "💥 %.0f" % damage
	else:
		return "%.0f" % damage
