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
## `gain_experience` 实际增加量（已含基因经验加成）；供 HUD 合并飘字
signal experience_gained(amount_added: float)
## 成功消耗材料并完成一档 SYNC 门槛突破
signal sync_breakthrough_succeeded(gate_level: int)

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

## 与 FastAPI `DEFAULT_SYNC_BREAKTHROUGH_GATE_LEVELS` 一致；改默认须同步后端
const DEFAULT_SYNC_BREAKTHROUGH_GATES: Array[int] = [20, 25, 30]
## 留空则用 DEFAULT_SYNC_BREAKTHROUGH_GATES；可改为 [5,10,15,20,25,30] 等与 UI 每 5 级一档对齐
@export var sync_breakthrough_gate_levels: Array[int] = []
@export var sync_breakthrough_enabled: bool = true
## 门槛等级 -> [{ "item_id": int, "quantity": int }]；空数组表示该档仅需经验满即可突破
@export var sync_breakthrough_costs: Dictionary = {}
## 已达成的门槛等级（存档 / `sync_breakthroughs_completed` API）
var sync_breakthroughs_completed: Array[int] = []

## 暴击率 0.0~1.0（0.05 = 5%）
@export var base_critical_rate: float = 0.05
## 暴击伤害倍率（1.5 = 150%，即额外 50%）
@export var base_critical_damage: float = 1.50
## 闪避率 0.0~1.0
@export var base_evasion: float = 0.05

# 当前数值（玩家：经验公式 + max_level + SYNC 突破门闸；敌人：fixed_combat_level）
@export var level: int:
	get():
		if not level_derived_from_experience:
			if max_level > 0:
				return clampi(fixed_combat_level, 1, max_level)
			return maxi(fixed_combat_level, 1)
		var raw_f := get_formula_raw_level()
		if not sync_breakthrough_enabled:
			return raw_f
		return _apply_sync_gate_to_effective(raw_f)
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

# 场景伤害抗性（0.0~1.0）：基础值来自存档/API，recalculate 中叠加基因后再写入 fire_resistance 等
var base_fire_resistance: float = 0.0
var base_poison_resistance: float = 0.0
var base_thorns_resistance: float = 0.0
var base_other_resistance: float = 0.0
var fire_resistance: float = 0.0
var poison_resistance: float = 0.0
var thorns_resistance: float = 0.0
var other_resistance: float = 0.0

## 基因：固定值减伤（每击）、受击后按伤害比例回复（水螅等）
var gene_damage_reduction_flat: float = 0.0
var gene_on_hit_regen_pct: float = 0.0

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


func process_effects(delta: float) -> void:
	if not level_derived_from_experience:
		return
	var regen := float(GeneManager.get_bonuses().get("health_regen_per_sec", 0.0))
	if regen <= 0.0 or delta <= 0.0:
		return
	var amt := regen * delta
	if amt < 1e-6:
		return
	heal(amt)


func _on_health_set(new_value: float) -> void:
	current_health = clampf(new_value, 0, current_max_health)
	health_changed.emit(current_health, current_max_health)
	if current_health <= 0:
		died.emit()


func get_raw_level() -> int:
	return _compute_raw_level()


## 公式等级并应用 max_level（不含 SYNC 门闸）；基因/调试可用
func get_formula_raw_level() -> int:
	var r := _compute_raw_level()
	if max_level > 0:
		return mini(r, max_level)
	return r


func _sync_gate_levels_sorted() -> Array[int]:
	if sync_breakthrough_gate_levels.is_empty():
		return DEFAULT_SYNC_BREAKTHROUGH_GATES.duplicate()
	var out: Array[int] = []
	for x in sync_breakthrough_gate_levels:
		out.append(int(x))
	out.sort()
	return out


func _sync_first_pending_gate() -> int:
	var done := {}
	for x in sync_breakthroughs_completed:
		done[int(x)] = true
	for g in _sync_gate_levels_sorted():
		if max_level > 0 and g > max_level:
			break
		if not done.has(g):
			return g
	return -1


func _apply_sync_gate_to_effective(raw: int) -> int:
	var g := _sync_first_pending_gate()
	if g < 0:
		return raw
	if raw >= g:
		return mini(raw, g - 1)
	return raw


func _max_total_experience_allowed_for(candidate: float) -> float:
	var cap_level := _experience_cap_for_max_level()
	if not level_derived_from_experience or not sync_breakthrough_enabled:
		return cap_level
	var g := _sync_first_pending_gate()
	if g < 0:
		return cap_level
	var b := maxf(base_exp_to_next_level, 0.001)
	var raw := int(floor(max(1.0, sqrt(maxf(0.0, candidate) / b) + 0.5)))
	if max_level > 0:
		raw = mini(raw, max_level)
	if raw < g - 1:
		return cap_level
	var gate_cap = pow(float(g) - 0.5, 2.0) * b - 0.01
	return minf(cap_level, gate_cap)


func get_level_experience_segment() -> Vector2:
	if not level_derived_from_experience:
		return Vector2(0.0, 1.0)
	var b := maxf(base_exp_to_next_level, 0.001)
	var display_level := level
	var hi_cap := _max_total_experience_allowed_for(experience)
	if display_level <= 1:
		var upper_bound_level_one := pow(1.5, 2.0) * b
		return Vector2(0.0, minf(upper_bound_level_one, hi_cap))
	var segment_lower_bound := pow(float(display_level) - 0.5, 2.0) * b
	var segment_upper_bound := pow(float(display_level) + 0.5, 2.0) * b
	if max_level > 0 and display_level >= max_level:
		segment_upper_bound = _experience_cap_for_max_level()
	segment_upper_bound = minf(segment_upper_bound, hi_cap)
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
	clamped_experience = minf(clamped_experience, _max_total_experience_allowed_for(clamped_experience))
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
	gene_damage_reduction_flat = float(gene_bonuses.get("damage_reduction_flat", 0.0))
	gene_on_hit_regen_pct = float(gene_bonuses.get("on_hit_regen_pct_of_damage", 0.0))

	current_max_health += float(gene_bonuses.get("max_health_bonus", 0))
	current_attack += float(gene_bonuses.get("attack_bonus", 0))
	current_defense += float(gene_bonuses.get("defense_bonus", 0))
	current_critical_rate += float(gene_bonuses.get("crit_rate_bonus", 0.0))
	current_critical_damage += float(gene_bonuses.get("crit_damage_bonus", 0.0))
	current_evasion += float(gene_bonuses.get("evasion_bonus", 0.0))

	var qs := float(gene_bonuses.get("quantum_shared_stat_ratio", 0.0))
	if qs > 0.0:
		var share := minf(current_critical_rate, current_evasion) * qs
		current_critical_rate += share
		current_evasion += share

	fire_resistance = clampf(base_fire_resistance + float(gene_bonuses.get("fire_resistance_bonus", 0.0)), 0.0, 1.0)
	poison_resistance = clampf(base_poison_resistance + float(gene_bonuses.get("poison_resistance_bonus", 0.0)), 0.0, 1.0)
	thorns_resistance = clampf(base_thorns_resistance + float(gene_bonuses.get("thorns_resistance_bonus", 0.0)), 0.0, 1.0)
	other_resistance = clampf(base_other_resistance + float(gene_bonuses.get("other_resistance_bonus", 0.0)), 0.0, 1.0)

	var hp_ratio := 1.0 if current_max_health <= 0.0 else clampf(current_health / current_max_health, 0.0, 1.0)
	var missing := clampf(1.0 - hp_ratio, 0.0, 1.0)
	var deciles: int = mini(10, int(floor(missing * 10.0)))
	var lad := float(gene_bonuses.get("low_hp_attack_bonus_per_decile", 0.0))
	var ldp := float(gene_bonuses.get("low_hp_defense_penalty_per_decile", 0.0))
	if deciles > 0 and (lad > 0.0 or ldp > 0.0):
		current_attack *= 1.0 + lad * float(deciles)
		current_defense *= maxf(1.0 - ldp * float(deciles), 0.2)

	var lthresh := float(gene_bonuses.get("low_hp_threshold", 0.0))
	if lthresh > 0.0 and hp_ratio < lthresh:
		current_defense += float(gene_bonuses.get("low_hp_defense_bonus", 0.0))
		var lam := float(gene_bonuses.get("low_hp_all_stats_mult", 0.0))
		if lam > 0.0:
			current_attack *= 1.0 + lam
			current_defense *= 1.0 + lam
			current_max_health *= 1.0 + lam

	var lbp := float(gene_bonuses.get("low_hp_bonus_per_missing_hp_pct", 0.0))
	if lbp > 0.0:
		var miss_pct := (1.0 - hp_ratio) * 100.0
		var extra := 1.0 + lbp * miss_pct
		current_attack *= extra
		current_defense *= extra
		current_max_health *= extra

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


## 基因冷却缩短（Skill.get_cooldown 使用）
func get_skill_cooldown_multiplier() -> float:
	var cdr := float(GeneManager.get_bonuses().get("cooldown_reduction", 0.0))
	return maxf(1.0 - cdr, 0.15)


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
	if gene_damage_reduction_flat > 0.0:
		damage_after_defense = maxf(damage_after_defense - gene_damage_reduction_flat, 0.0)
	if attack_data.source == AttackData.AttackType.HAZARD:
		var hazard_resistance_value: float = _get_hazard_resistance(attack_data.hazard_sub_type)
		damage_after_defense = damage_after_defense * (1.0 - clampf(hazard_resistance_value, 0.0, 1.0))
		if damage_after_defense < 1.0:
			damage_after_defense = 1.0

	print("   当前防御: %.1f" % current_defense)
	print("   最终伤害: %.1f" % damage_after_defense)

	current_health = clampf(current_health - damage_after_defense, 0.0, current_max_health)

	if level_derived_from_experience and gene_on_hit_regen_pct > 0.0 and damage_after_defense > 0.0:
		var regen_amt := damage_after_defense * gene_on_hit_regen_pct
		if regen_amt > 1e-4:
			current_health = clampf(current_health + regen_amt, 0.0, current_max_health)

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
	var mult := 1.0 + float(GeneManager.get_bonuses().get("experience_gain_bonus", 0.0))
	experience_amount *= mult
	var total_experience_before := experience
	experience = experience + experience_amount
	var experience_actually_gained := experience - total_experience_before
	if experience_actually_gained > 0.0:
		print("%s 获得 %.1f 经验值 (当前等级 %d, 总经验 %.0f)" % [str(self), experience_actually_gained, level, experience])
		experience_gained.emit(experience_actually_gained)
	return experience_actually_gained


## 统一入口：任务/击杀等应调用本方法，便于 `source_key` 调试日志（仍走 `gain_experience` 与封顶）
func grant_experience_from_source(base_amount: float, source_key: String = "") -> float:
	var g := gain_experience(base_amount)
	if not source_key.is_empty() and g > 1e-6:
		print("[Stats][EXP] source=%s gained=%.2f" % [source_key, g])
	return g


## 供 `ExperienceRewards` 等扩展：统一走 Stats，未来可按 source 挂表倍率
func grant_experience_from_source_ctx(base_amount: float, source_key: String, _ctx: Dictionary = {}) -> float:
	return grant_experience_from_source(base_amount, source_key)


func _get_breakthrough_cost_entries(gate_level: int) -> Array:
	if sync_breakthrough_costs.has(gate_level):
		var v: Variant = sync_breakthrough_costs[gate_level]
		return v if v is Array else []
	var ks := str(gate_level)
	if sync_breakthrough_costs.has(ks):
		var v2: Variant = sync_breakthrough_costs[ks]
		return v2 if v2 is Array else []
	return []


func _has_breakthrough_materials(gate_level: int) -> bool:
	var entries := _get_breakthrough_cost_entries(gate_level)
	if entries.is_empty():
		return true
	if InventoryManager == null:
		return false
	for e in entries:
		if not e is Dictionary:
			continue
		var iid := int(e.get("item_id", 0))
		var q := int(e.get("quantity", 0))
		if iid <= 0 or q <= 0:
			continue
		if not InventoryManager.has_item(str(iid), q):
			return false
	return true


func _consume_breakthrough_materials(gate_level: int) -> bool:
	var entries := _get_breakthrough_cost_entries(gate_level)
	if entries.is_empty():
		return true
	if InventoryManager == null:
		return false
	if not _has_breakthrough_materials(gate_level):
		return false
	for e in entries:
		if not e is Dictionary:
			continue
		var iid := int(e.get("item_id", 0))
		var q := int(e.get("quantity", 0))
		if iid <= 0 or q <= 0:
			continue
		if not InventoryManager.try_consume_numeric_item_id(iid, q):
			return false
	return true


func is_at_sync_experience_cap() -> bool:
	if not sync_breakthrough_enabled or not level_derived_from_experience:
		return false
	if _sync_first_pending_gate() < 0:
		return false
	var m := _max_total_experience_allowed_for(experience)
	return experience >= m - 0.25


func is_sync_breakthrough_available() -> bool:
	if not sync_breakthrough_enabled or not level_derived_from_experience:
		return false
	var g := _sync_first_pending_gate()
	if g < 0:
		return false
	return is_at_sync_experience_cap() and _has_breakthrough_materials(g)


func get_next_sync_breakthrough_gate() -> int:
	return _sync_first_pending_gate()


## 返回空字符串表示成功；否则为可读失败原因
func attempt_sync_breakthrough_for_next_gate() -> String:
	if not level_derived_from_experience:
		return "当前角色不使用经验等级"
	if not sync_breakthrough_enabled:
		return "未启用 SYNC 突破"
	var g := _sync_first_pending_gate()
	if g < 0:
		return "当前无需突破"
	if not is_at_sync_experience_cap():
		return "尚未达到本阶段经验上限"
	if not _consume_breakthrough_materials(g):
		return "突破材料不足"
	sync_breakthroughs_completed.append(g)
	sync_breakthroughs_completed.sort()
	var b := maxf(base_exp_to_next_level, 0.001)
	var target_exp := pow(float(g) - 0.5, 2.0) * b
	experience = maxf(experience, target_exp)
	sync_breakthrough_succeeded.emit(g)
	if CharacterDataManager and CharacterDataManager.has_method("refresh_inventory_from_api"):
		CharacterDataManager.refresh_inventory_from_api()
	return ""


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
		"gene_points": GeneManager.gene_points,
		"experience": snappedf(experience, 0.01),
		"fire_resistance": snappedf(base_fire_resistance, 0.0001),
		"poison_resistance": snappedf(base_poison_resistance, 0.0001),
		"thorns_resistance": snappedf(base_thorns_resistance, 0.0001),
		"other_resistance": snappedf(base_other_resistance, 0.0001),
		"sync_breakthroughs_completed": sync_breakthroughs_completed.duplicate(),
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
	sync_breakthroughs_completed.clear()
	var sb: Variant = stats_payload.get("sync_breakthroughs_completed", [])
	if sb is Array:
		for x in sb:
			sync_breakthroughs_completed.append(int(x))
		sync_breakthroughs_completed.sort()
	if level_derived_from_experience:
		_mute_level_up_signal = true
		experience = maxf(0.0, float(stats_payload.get("experience", 0.0)))
		_mute_level_up_signal = false
	else:
		experience = 0.0
	base_fire_resistance = clampf(float(stats_payload.get("fire_resistance", 0.0)), 0.0, 1.0)
	base_poison_resistance = clampf(float(stats_payload.get("poison_resistance", 0.0)), 0.0, 1.0)
	base_thorns_resistance = clampf(float(stats_payload.get("thorns_resistance", 0.0)), 0.0, 1.0)
	base_other_resistance = clampf(float(stats_payload.get("other_resistance", 0.0)), 0.0, 1.0)
	var gp := int(stats_payload.get("gene_points", 0))
	GeneManager.set_gene_points(maxi(gp, 0))
	recalculate_stats()
	current_health = clampf(loaded_current_health, 0.0, current_max_health)
