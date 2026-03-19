extends Resource
class_name Stats

##   · 移除 base_speed（已由移动组件独立管理）
##   · 新增 base_critical_rate / base_critical_damage / base_evasion
##   · recalculate_stats() 现在会叠加 GeneManager 的基因加成
##   · 提供 save_to_dict / load_from_dict 与 API 对接

# 信号
signal health_changed(cur_health: float, max_health: float)
signal died

# -- 基础数值 --
## 最大生命
@export var base_max_health: float = 100.0
## 基础攻击
@export var base_attack: float = 10.0
## 基础防御 
@export var base_defense: float = 5.0
## 基础经验
@export var base_exp_to_next_level: float = 100.0
#@export var base_speed: float = 10.00

## 暴击率 0.0~1.0（0.05 = 5%）
@export var base_critical_rate:   float = 0.05
## 暴击伤害倍率（1.5 = 150%，即额外 50%）
@export var base_critical_damage: float = 1.50
## 闪避率 0.0~1.0
@export var base_evasion:         float = 0.05

# 当前数值
@export var level: int:
	get(): return floor(max(1.0, sqrt(experience / base_exp_to_next_level) + 0.5))
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

enum BuffableStats {
	ATTACK,
	MAX_HEALTH,
	DEFENSE,
	CRITICAL_RATE,
	CRITICAL_DAMAGE,
	EVASION,
}
var stat_buffs: Array[StatBuff]

# 使用UID能够更好的使用这些文件
const STAT_CURVES: Dictionary[BuffableStats, Curve] = {
	BuffableStats.MAX_HEALTH: preload("uid://cw1g0lyq4n6ex"),
	BuffableStats.DEFENSE: preload("uid://bemi7yvk2fm5i"),
	BuffableStats.ATTACK: preload("uid://6dnmm2hlc03m")
}

## 基因加成：GeneManager.genes_changed 由 Player 连接至 recalculate_stats
## recalculate_stats 内调用 GeneManager.get_bonuses() 叠加属性

func _init() -> void:
	# 如果将当前血量赋值为最大血量，会是100（根据最大血量的值来定）， 但是如果我们在检查器中更改这个值
	# 如50 当前血量还是会按照脚本中规定的100来定，所以需要需要使用call deferred
	# 延迟调用这个函数，等到当前帧的所有初始化操作（包括从检查器中加载的变量）都完成后再执行。
	setup_stats.call_deferred()

## 属性初始化
func setup_stats() -> void:
	# 重新计算当前的属性值
	recalculate_stats()
	current_health = base_max_health 

## 添加buff
func add_buff(buff: StatBuff) -> void:
	stat_buffs.append(buff)
	recalculate_stats.call_deferred()

## 移除buff
func remove_buff(buff: StatBuff) -> void:
	stat_buffs.erase(buff)
	recalculate_stats.call_deferred()


## 添加临时 Buff，duration 秒后自动移除
## owner_node 用于创建 Timer（Stats 为 Resource 无 get_tree）
func add_temporary_buff(buff: StatBuff, duration: float, owner_node: Node) -> void:
	if owner_node == null or not owner_node.is_inside_tree():
		add_buff(buff)
		return
	add_buff(buff)
	owner_node.get_tree().create_timer(duration).timeout.connect(func():
		if buff in stat_buffs:
			remove_buff(buff)
	)


## 施加持续伤害（DOT）
## owner_node 为持有此 Stats 的节点，用于创建 Timer
func apply_dot(owner_node: Node, dps: float, tick_interval: float, duration: float, source: Node = null) -> void:
	if owner_node == null or not owner_node.is_inside_tree():
		return
	var ticks: int = maxi(1, int(duration / tick_interval))
	var damage_per_tick: float = dps
	var ticks_done := [0]  ## 用数组包装，闭包内可正确修改

	var _do_tick: Callable
	_do_tick = func():
		if ticks_done[0] >= ticks:
			return
		ticks_done[0] += 1
		var attack := AttackData.new()
		attack.source = AttackData.AttackType.SKILL
		attack.source_node = source
		attack.base_damage = damage_per_tick
		attack.final_damage = damage_per_tick
		attack.body_part_multiplier = 1.0
		take_damage(attack)
		if ticks_done[0] < ticks:
			owner_node.get_tree().create_timer(tick_interval).timeout.connect(_do_tick)

	owner_node.get_tree().create_timer(tick_interval).timeout.connect(_do_tick)


## 应用暴击倍率（供技能暴击判定使用）
func apply_crit_multiplier(damage: float) -> float:
	return damage * current_critical_damage


## 每帧处理效果（DOT/Buff 计时等，由持有者节点在 _process 中调用）
func process_effects(_delta: float) -> void:
	pass


## 设置生命
func _on_health_set(new_value: float) -> void:
	current_health = clampf(new_value, 0, current_max_health)
	health_changed.emit(current_health, current_max_health)
	if current_health <= 0:
		died.emit()

## 设置经验
func _on_experience_set(new_value: float) -> void:
	var old_level: int = level
	experience = new_value
	if not old_level == level:
		recalculate_stats()

## 重新计算属性
func recalculate_stats() -> void:
	# 根据buff的类型进行相乘或者相加 用来保存最后的修正值
	var stat_multipliers: Dictionary = {}
	var stat_addends: Dictionary = {}
	
	# 遍历玩家身上的buff
	for buff in stat_buffs:
		# 获取buff的状态名称 并且小写方便作为字典键
		var stat_name: String = BuffableStats.keys()[buff.stat].to_lower()
		# 根据增益的处理类型 比如相加或者相乘
		match buff.buff_type:
			StatBuff.BuffType.Add:
				# 检查 stat_addends 字典中是否已有该属性；
				if not stat_addends.has(stat_name):
					# 如果没有，初始化为 0.0
					stat_addends[stat_name] = 0.0
				# 然后把当前 Buff 的加成数值加上去。
				stat_addends[stat_name] += buff.buff_amount
			StatBuff.BuffType.Multiply:
				if not stat_multipliers.has(stat_name):
					stat_multipliers[stat_name] = 0.0
				stat_multipliers[stat_name] += buff.buff_amount
				
				
	
	# 计算一个 采样位置，用于从曲线中取值。
	# -0.01 的小偏移是为了避免到达 1.0 时的边界问题（Godot 的 Curve.sample(1.0) 有时会报错或返回不准确值）。
	var stat_sample_pos: float = (float(level)/100.0)-0.01
	# 曲线输出的倍率乘上基础值，得出当前等级的属性。
	current_max_health = base_max_health * STAT_CURVES[BuffableStats.MAX_HEALTH].sample(stat_sample_pos)
	current_defense = base_defense * STAT_CURVES[BuffableStats.DEFENSE].sample(stat_sample_pos)
	current_attack = base_attack * STAT_CURVES[BuffableStats.ATTACK].sample(stat_sample_pos)
		
	# 暴击和闪避不走成长曲线，直接用基础值（靠基因和装备加成）
	current_critical_rate   = base_critical_rate
	current_critical_damage = base_critical_damage
	current_evasion         = base_evasion

	# 叠加基因加成（GeneManager.get_bonuses）
	var bonuses: Dictionary = GeneManager.get_bonuses()
	current_max_health      += float(bonuses.get("max_health_bonus", 0))
	current_attack          += float(bonuses.get("attack_bonus", 0))
	current_defense         += float(bonuses.get("defense_bonus", 0))
	current_critical_rate   += float(bonuses.get("crit_rate_bonus", 0.0))
	current_critical_damage += float(bonuses.get("crit_damage_bonus", 0.0))
	current_evasion         += float(bonuses.get("evasion_bonus", 0.0))

	for stat_name in stat_multipliers:
		var cur_propety_name: String = str("current_" + stat_name)
		## Multiply: 倍率 = (1 + sum)，如 -0.25 表示 -25% → ×0.75
		var mult: float = 1.0 + stat_multipliers[stat_name]
		set(cur_propety_name, get(cur_propety_name) * maxf(mult, 0.01))
		
	for stat_name in stat_addends:
		var cur_propety_name: String = str("current_" + stat_name)
		set(cur_propety_name, get(cur_propety_name) + stat_addends[stat_name])
		
		
	current_critical_rate   = clampf(current_critical_rate,   0.0, 1.0)
	current_critical_damage = maxf(current_critical_damage, 1.0)
	current_evasion         = clampf(current_evasion,         0.0, 1.0)
	current_max_health      = maxf(current_max_health, 1.0)
	
	if current_health > current_max_health:
		current_health = current_max_health
		
		
		
## 判断是否闪避（返回 true = 成功闪避）
func roll_evasion() -> bool:
	return randf() < current_evasion

## 判断是否暴击（返回 true = 暴击）
func roll_critical() -> bool:
	return randf() < current_critical_rate

## 承受伤害（防御计算 + 死亡判定） **
func take_damage(attack_data: AttackData) -> void:
	if attack_data == null:
		push_error("Stats: 收到空的 AttackData")
		return
	# 闪避判定：成功则不受伤害
	if roll_evasion():
		print("🛡️ Stats 闪避成功，未受到伤害")
		return
	
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("🛡️ Stats 开始处理伤害")
	
	# ──────────────────────────────────────────────────────────
	# 1. 使用 AttackData 中已计算好的 final_damage
	# ──────────────────────────────────────────────────────────
	var raw_damage: float = attack_data.final_damage
	
	print("   攻击类型: %s" % AttackData.AttackType.keys()[attack_data.source])
	print("   基础伤害: %.1f" % attack_data.base_damage)
	print("   部位倍率: %.2fx" % attack_data.body_part_multiplier)
	print("   倍率后伤害: %.1f" % raw_damage)
	
	# ──────────────────────────────────────────────────────────
	# 2. 应用防御减伤
	# ──────────────────────────────────────────────────────────
	var actual_damage:float = max(raw_damage - current_defense, 0.0)
	
	print("   当前防御: %.1f" % current_defense)
	print("   最终伤害: %.1f" % actual_damage)
	
	# ──────────────────────────────────────────────────────────
	# 3. 扣除生命值
	# ──────────────────────────────────────────────────────────
	current_health = clampf(current_health - actual_damage, 0.0, current_max_health)
	
	# ──────────────────────────────────────────────────────────
	# 4. 触发信号
	# ──────────────────────────────────────────────────────────
	health_changed.emit(current_health, current_max_health)
	
	if current_health <= 0:
		print("💀 目标死亡")
		died.emit()
	
	print("   剩余生命: %.1f / %.1f" % [current_health, current_max_health])
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

## 恢复生命
func heal(amount: float) -> void:
	current_health = min(current_health + amount, current_max_health)
	print("%s 恢复 %.1f 点生命 (%.1f / %.1f)" % [str(self), amount, current_health, current_max_health])

## 增加经验
func gain_experience(amount: float) -> void:
	experience += amount
	print("%s 获得 %.1f 经验值 (当前等级 %d)" % [str(self), amount, level])



func apply_attack_data(attack_data: AttackData) -> void:
	take_damage(attack_data)
 
 
# -- 存档接口（与 APIManager 对接） --
 
## 导出为可发送给 API 的 Dictionary
## 对应 CharacterStatsSaveRequest schema
func save_to_dict() -> Dictionary:
	return {
		"max_health":      int(current_max_health),
		"current_health":  int(current_health),
		"attack":          int(current_attack),
		"defense":         int(current_defense),
		"critical_rate":   snappedf(current_critical_rate,   0.0001),
		"critical_damage": snappedf(current_critical_damage, 0.0001),
		"evasion":         snappedf(current_evasion,         0.0001),
	}
 
## 从 API 返回的 Dictionary 恢复属性（登录后调用一次）
## 恢复基础数值后调用 recalculate_stats（含 GeneManager.get_bonuses 基因加成）
func load_from_dict(data: Dictionary) -> void:
	if data.is_empty():
		return

	var new_max_hp := float(data.get("max_health", base_max_health))
	var new_cur_hp := float(data.get("current_health", new_max_hp))

	base_max_health      = new_max_hp
	base_attack          = float(data.get("attack",   base_attack))
	base_defense         = float(data.get("defense",  base_defense))
	base_critical_rate   = float(data.get("critical_rate",   0.05))
	base_critical_damage = float(data.get("critical_damage", 1.50))
	base_evasion         = float(data.get("evasion",         0.05))
	recalculate_stats()
	current_health = clampf(new_cur_hp, 0.0, current_max_health)
