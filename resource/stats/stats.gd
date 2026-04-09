extends Resource
class_name Stats

##   · 移除 base_speed（已由移动组件独立管理）
##   · 新增 base_critical_rate / base_critical_damage / base_evasion
##   · recalculate_stats() 现在会叠加 GeneManager 的基因加成
##   · 提供 save_to_dict / load_from_dict 与 API 对接
##   · 玩家：level_derived_from_experience = true，等级由总经验推导；敌人：false，仅用 fixed_combat_level

# 信号
signal health_changed(current_health: float, maximum_health: float)
signal died
## 经验或等级变化时发出（total_experience, current_level）— 供属性 UI、HUD 刷新
signal experience_changed(total_experience: float, current_level: int)
## 仅当等级数字上升时发出（新等级）；降级或读档压级不会触发
signal character_level_up(new_level: int)

# -- 基础数值 --
## 最大生命
@export var base_max_health: float = 100.0
## 基础攻击
@export var base_attack: float = 10.0
## 基础防御
@export var base_defense: float = 5.0
## 经验缩放：总经验与等级关系见 docs/EXPERIENCE_SYSTEM.md（仅当 level_derived_from_experience 时生效）
@export var base_exp_to_next_level: float = 100.0
## 角色等级上限（参与属性曲线与经验封顶）。≤0 表示不封顶（单机调试用）
@export var max_level: int = 30
## 为 true：等级由累计经验公式计算（玩家）。为 false：等级仅由 fixed_combat_level 决定（敌人，不获得经验）
@export var level_derived_from_experience: bool = true
## 当 level_derived_from_experience 为 false 时使用的战斗等级（与经验无关）
@export var fixed_combat_level: int = 1

## 暴击率 0.0~1.0（0.05 = 5%）
@export var base_critical_rate: float = 0.05
## 暴击伤害倍率（1.5 = 150%，即额外 50%）
@export var base_critical_damage: float = 1.50
## 闪避率 0.0~1.0
@export var base_evasion: float = 0.05

# 当前数值（玩家：由经验推导并受 max_level 限制；敌人：fixed_combat_level）
@export var level: int:
	get():
		if not level_derived_from_experience:
			if max_level > 0:
				return clampi(fixed_combat_level, 1, max_level)
			return maxi(fixed_combat_level, 1)
		var raw_level_from_experience := _compute_raw_level()
		if max_level <= 0:
			return raw_level_from_experience
		return mini(raw_level_from_experience, max_level)
@export var experience: float = 0.0:
	set = _on_experience_set
@export var current_health: float = 0.0:
	set = _on_health_set

# -- 最终计算值（由 recalculate_stats 填入）--
var current_max_health: float = 100.0
var current_attack: float = 10.0
var current_defense: float = 5.0
var current_critical_rate: float = 0.05
var current_critical_damage: float = 1.50
var current_evasion: float = 0.05

# 场景伤害抗性（0.0~1.0，从 API 加载，对应 Hazard.HazardType）
var fire_resistance: float = 0.0
var poison_resistance: float = 0.0
var thorns_resistance: float = 0.0
var other_resistance: float = 0.0

enum BuffableStats {
	ATTACK,
	MAX_HEALTH,
	DEFENSE,
	CRITICAL_RATE,
	CRITICAL_DAMAGE,
	EVASION,
}
var stat_buffs: Array[StatBuff]
## 读档 / API 注入经验时抑制 character_level_up，避免登录误弹升级提示
var _mute_level_up_signal: bool = false

const STAT_CURVES: Dictionary[BuffableStats, Curve] = {
	BuffableStats.MAX_HEALTH: preload("uid://cw1g0lyq4n6ex"),
	BuffableStats.DEFENSE: preload("uid://bemi7yvk2fm5i"),
	BuffableStats.ATTACK: preload("uid://6dnmm2hlc03m")
}

func _init() -> void:
	setup_stats.call_deferred()


func setup_stats() -> void:
	recalculate_stats()
	current_health = base_max_health


func add_buff(stat_buff: StatBuff) -> void:
	stat_buffs.append(stat_buff)
	recalculate_stats.call_deferred()


func remove_buff(stat_buff: StatBuff) -> void:
	stat_buffs.erase(stat_buff)
	recalculate_stats.call_deferred()


func add_temporary_buff(stat_buff: StatBuff, duration: float, owner_node: Node) -> void:
	if owner_node == null or not owner_node.is_inside_tree():
		add_buff(stat_buff)
		return
	add_buff(stat_buff)
	owner_node.get_tree().create_timer(duration).timeout.connect(func():
		if stat_buff in stat_buffs:
			remove_buff(stat_buff)
	)


func apply_dot(owner_node: Node, damage_per_second: float, tick_interval: float, duration: float, source: Node = null) -> void:
	if owner_node == null or not owner_node.is_inside_tree():
		return
	var total_ticks: int = maxi(1, int(duration / tick_interval))
	var damage_each_tick: float = damage_per_second
	var ticks_completed := [0]

	var tick_callback: Callable
	tick_callback = func():
		if ticks_completed[0] >= total_ticks:
			return
		ticks_completed[0] += 1
		var attack_data := AttackData.new()
		attack_data.source = AttackData.AttackType.SKILL
		attack_data.source_node = source
		attack_data.base_damage = damage_each_tick
		attack_data.final_damage = damage_each_tick
		attack_data.body_part_multiplier = 1.0
		take_damage(attack_data)
		if ticks_completed[0] < total_ticks:
			owner_node.get_tree().create_timer(tick_interval).timeout.connect(tick_callback)

	owner_node.get_tree().create_timer(tick_interval).timeout.connect(tick_callback)


func apply_crit_multiplier(damage: float) -> float:
	return damage * current_critical_damage


func process_effects(_delta: float) -> void:
	pass


func _on_health_set(new_value: float) -> void:
	current_health = clampf(new_value, 0, current_max_health)
	health_changed.emit(current_health, current_max_health)
	if current_health <= 0:
		died.emit()


func get_raw_level() -> int:
	return _compute_raw_level()


func get_level_experience_segment() -> Vector2:
	if not level_derived_from_experience:
		return Vector2(0.0, 1.0)
	var experience_denominator_safe := maxf(base_exp_to_next_level, 0.001)
	var display_level := level
	if display_level <= 1:
		var upper_bound_level_one := pow(1.5, 2.0) * experience_denominator_safe
		return Vector2(0.0, upper_bound_level_one)
	var segment_lower_bound := pow(float(display_level) - 0.5, 2.0) * experience_denominator_safe
	var segment_upper_bound := pow(float(display_level) + 0.5, 2.0) * experience_denominator_safe
	if max_level > 0 and display_level >= max_level:
		segment_upper_bound = _experience_cap_for_max_level()
	return Vector2(segment_lower_bound, maxf(segment_upper_bound, segment_lower_bound + 1e-6))


func _compute_raw_level() -> int:
	var experience_denominator_safe := maxf(base_exp_to_next_level, 0.001)
	return int(floor(max(1.0, sqrt(experience / experience_denominator_safe) + 0.5)))


func _experience_cap_for_max_level() -> float:
	if max_level <= 0:
		return INF
	var experience_denominator_safe := maxf(base_exp_to_next_level, 0.001)
	return maxf(0.0, pow(float(max_level) + 0.5, 2.0) * experience_denominator_safe - 0.01)


func _on_experience_set(new_value: float) -> void:
	if not level_derived_from_experience:
		experience = 0.0
		experience_changed.emit(experience, level)
		return
	var previous_level: int = level
	var clamped_experience := maxf(0.0, new_value)
	if max_level > 0:
		clamped_experience = minf(clamped_experience, _experience_cap_for_max_level())
	experience = clamped_experience
	var updated_level: int = level
	if previous_level != updated_level:
		recalculate_stats()
		if updated_level > previous_level and not _mute_level_up_signal:
			character_level_up.emit(updated_level)
	experience_changed.emit(experience, updated_level)


func recalculate_stats() -> void:
	var stat_multipliers: Dictionary = {}
	var stat_addends: Dictionary = {}

	for stat_buff in stat_buffs:
		var stat_key: String = BuffableStats.keys()[stat_buff.stat].to_lower()
		match stat_buff.buff_type:
			StatBuff.BuffType.Add:
				if not stat_addends.has(stat_key):
					stat_addends[stat_key] = 0.0
				stat_addends[stat_key] += stat_buff.buff_amount
			StatBuff.BuffType.Multiply:
				if not stat_multipliers.has(stat_key):
					stat_multipliers[stat_key] = 0.0
				stat_multipliers[stat_key] += stat_buff.buff_amount

	var curve_sample_position: float = (float(level) / 100.0) - 0.01
	current_max_health = base_max_health * STAT_CURVES[BuffableStats.MAX_HEALTH].sample(curve_sample_position)
	current_defense = base_defense * STAT_CURVES[BuffableStats.DEFENSE].sample(curve_sample_position)
	current_attack = base_attack * STAT_CURVES[BuffableStats.ATTACK].sample(curve_sample_position)

	current_critical_rate = base_critical_rate
	current_critical_damage = base_critical_damage
	current_evasion = base_evasion

	var gene_bonuses: Dictionary = GeneManager.get_bonuses()
	current_max_health += float(gene_bonuses.get("max_health_bonus", 0))
	current_attack += float(gene_bonuses.get("attack_bonus", 0))
	current_defense += float(gene_bonuses.get("defense_bonus", 0))
	current_critical_rate += float(gene_bonuses.get("crit_rate_bonus", 0.0))
	current_critical_damage += float(gene_bonuses.get("crit_damage_bonus", 0.0))
	current_evasion += float(gene_bonuses.get("evasion_bonus", 0.0))

	for stat_key in stat_multipliers:
		var current_property_name: String = "current_" + stat_key
		var multiplier_total: float = 1.0 + stat_multipliers[stat_key]
		set(current_property_name, get(current_property_name) * maxf(multiplier_total, 0.01))

	for stat_key in stat_addends:
		var current_property_name: String = "current_" + stat_key
		set(current_property_name, get(current_property_name) + stat_addends[stat_key])

	current_critical_rate = clampf(current_critical_rate, 0.0, 1.0)
	current_critical_damage = maxf(current_critical_damage, 1.0)
	current_evasion = clampf(current_evasion, 0.0, 1.0)
	current_max_health = maxf(current_max_health, 1.0)

	if current_health > current_max_health:
		current_health = current_max_health


func roll_evasion() -> bool:
	return randf() < current_evasion


func roll_critical() -> bool:
	return randf() < current_critical_rate


func take_damage(attack_data: AttackData) -> void:
	if attack_data == null:
		push_error("Stats: 收到空的 AttackData")
		return
	if roll_evasion():
		print("🛡️ Stats 闪避成功，未受到伤害")
		return

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("🛡️ Stats 开始处理伤害")

	var scaled_damage: float = attack_data.final_damage

	var attack_type_label: String = AttackData.AttackType.keys()[attack_data.source]
	if attack_data.source == AttackData.AttackType.HAZARD and attack_data.hazard_sub_type >= 0:
		attack_type_label += "(%s)" % attack_data.get_hazard_type_name()
	print("   攻击类型: %s" % attack_type_label)
	print("   基础伤害: %.1f" % attack_data.base_damage)
	print("   部位倍率: %.2fx" % attack_data.body_part_multiplier)
	print("   倍率后伤害: %.1f" % scaled_damage)

	var damage_after_defense: float = max(scaled_damage - current_defense, 0.0)
	if attack_data.source == AttackData.AttackType.HAZARD:
		var hazard_resistance_value: float = _get_hazard_resistance(attack_data.hazard_sub_type)
		damage_after_defense = damage_after_defense * (1.0 - clampf(hazard_resistance_value, 0.0, 1.0))
		if damage_after_defense < 1.0:
			damage_after_defense = 1.0

	print("   当前防御: %.1f" % current_defense)
	print("   最终伤害: %.1f" % damage_after_defense)

	current_health = clampf(current_health - damage_after_defense, 0.0, current_max_health)

	health_changed.emit(current_health, current_max_health)

	if current_health <= 0:
		print("💀 目标死亡")
		died.emit()

	print("   剩余生命: %.1f / %.1f" % [current_health, current_max_health])
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")


func _get_hazard_resistance(hazard_sub_type: int) -> float:
	match hazard_sub_type:
		0: return fire_resistance
		1: return poison_resistance
		2: return thorns_resistance
		3: return other_resistance
		_: return 0.0


func heal(heal_amount: float) -> void:
	current_health = min(current_health + heal_amount, current_max_health)
	health_changed.emit(current_health, current_max_health)
	print("%s 恢复 %.1f 点生命 (%.1f / %.1f)" % [str(self), heal_amount, current_health, current_max_health])


func gain_experience(experience_amount: float) -> float:
	if not level_derived_from_experience:
		return 0.0
	if experience_amount <= 0.0:
		return 0.0
	var total_experience_before := experience
	experience = experience + experience_amount
	var experience_actually_gained := experience - total_experience_before
	if experience_actually_gained > 0.0:
		print("%s 获得 %.1f 经验值 (当前等级 %d, 总经验 %.0f)" % [str(self), experience_actually_gained, level, experience])
	return experience_actually_gained


func apply_attack_data(attack_data: AttackData) -> void:
	take_damage(attack_data)


func save_to_dict() -> Dictionary:
	return {
		"max_health": int(base_max_health),
		"current_health": int(current_health),
		"attack": int(base_attack),
		"defense": int(base_defense),
		"critical_rate": snappedf(base_critical_rate, 0.0001),
		"critical_damage": snappedf(base_critical_damage, 0.0001),
		"evasion": snappedf(base_evasion, 0.0001),
		"experience": snappedf(experience, 0.01),
		"fire_resistance": snappedf(fire_resistance, 0.0001),
		"poison_resistance": snappedf(poison_resistance, 0.0001),
		"thorns_resistance": snappedf(thorns_resistance, 0.0001),
		"other_resistance": snappedf(other_resistance, 0.0001),
	}


func load_from_dict(serialized_stats: Dictionary) -> void:
	if serialized_stats.is_empty():
		return
	var stats_payload: Dictionary = serialized_stats.duplicate(true)
	stats_payload.erase("loadout")

	var loaded_max_health := float(stats_payload.get("max_health", base_max_health))
	var loaded_current_health := float(stats_payload.get("current_health", loaded_max_health))

	base_max_health = loaded_max_health
	base_attack = float(stats_payload.get("attack", base_attack))
	base_defense = float(stats_payload.get("defense", base_defense))
	base_critical_rate = float(stats_payload.get("critical_rate", 0.05))
	base_critical_damage = float(stats_payload.get("critical_damage", 1.50))
	base_evasion = float(stats_payload.get("evasion", 0.05))
	if level_derived_from_experience:
		_mute_level_up_signal = true
		experience = maxf(0.0, float(stats_payload.get("experience", 0.0)))
		_mute_level_up_signal = false
	else:
		experience = 0.0
	fire_resistance = clampf(float(stats_payload.get("fire_resistance", 0.0)), 0.0, 1.0)
	poison_resistance = clampf(float(stats_payload.get("poison_resistance", 0.0)), 0.0, 1.0)
	thorns_resistance = clampf(float(stats_payload.get("thorns_resistance", 0.0)), 0.0, 1.0)
	other_resistance = clampf(float(stats_payload.get("other_resistance", 0.0)), 0.0, 1.0)
	recalculate_stats()
	current_health = clampf(loaded_current_health, 0.0, current_max_health)
