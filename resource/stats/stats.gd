extends Resource
class_name Stats

#var _current_health: float = 0
#@export var current_health: float:
	#get: return _current_health
	#set(value):
		#_current_health = clampf(value, 0, current_max_health)
		#health_changed.emit(_current_health, current_max_health)
		#if _current_health <= 0:
			#died.emit()
#var _experience: float = 0
#@export var experience: float:
	#get: return _experience
	#set(value):
		#var old_level = level
		#_experience = value
		#if level != old_level:
			#recalculate_stats()

# 基础数值
@export var base_max_health: float = 100
@export var base_attack: float = 10
@export var base_defense: float = 5
@export var base_exp_to_next_level: float = 100
@export var base_speed: float = 10
# 当前数值
@export var level: int:
	get(): return floor(max(1.0, sqrt(experience / base_exp_to_next_level) + 0.5))
@export var experience: float = 0: 
	set = _on_experience_set
@export var current_health: float = 0: 
	set = _on_health_set

var current_max_health: float = 100
var current_attack: float = 10
var current_defense: float = 5.0

enum BuffableStats {
	ATTACK,
	MAX_HEALTH,
	DEFENSE,
}
var stat_buffs: Array[StatBuff]

# 使用UID能够更好的使用这些文件
const STAT_CURVES: Dictionary[BuffableStats, Curve] = {
	BuffableStats.MAX_HEALTH: preload("uid://cw1g0lyq4n6ex"),
	BuffableStats.DEFENSE: preload("uid://bemi7yvk2fm5i"),
	BuffableStats.ATTACK: preload("uid://6dnmm2hlc03m")
}

signal health_changed(cur_health, max_health)
signal died
#signal leveled_up(new_level)

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
		var stat_name: String = BuffableStats.keys()[buff.stats].to_lower()
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
				
				# 最后如果小于 0，则强制归 0（防止出现负数导致属性倒扣）
				if stat_multipliers[stat_name] < 0.0:
					stat_multipliers[stat_name] = 0.0
				
	
	# 计算一个 采样位置，用于从曲线中取值。
	# -0.01 的小偏移是为了避免到达 1.0 时的边界问题（Godot 的 Curve.sample(1.0) 有时会报错或返回不准确值）。
	var stat_sample_pos: float = (float(level)/100.0)-0.01
	# 曲线输出的倍率乘上基础值，得出当前等级的属性。
	current_max_health = base_max_health * STAT_CURVES[BuffableStats.MAX_HEALTH].sample(stat_sample_pos)
	current_defense = base_defense * STAT_CURVES[BuffableStats.DEFENSE].sample(stat_sample_pos)
	current_attack = base_attack * STAT_CURVES[BuffableStats.ATTACK].sample(stat_sample_pos)
		
	for stat_name in stat_multipliers:
		var cur_propety_name: String = str("current_" + stat_name)
		set(cur_propety_name, get(cur_propety_name) * stat_multipliers[stat_name])
		
	for stat_name in stat_addends:
		var cur_propety_name: String = str("current_" + stat_name)
		set(cur_propety_name, get(cur_propety_name) + stat_addends[stat_name])
		
## 承受伤害（防御计算 + 死亡判定） **
func take_damage(attack_data: AttackData) -> void:
	if attack_data == null:
		push_error("Stats: 收到空的 AttackData")
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
	current_health = clampf(current_health - actual_damage, 0, current_max_health)
	
	# ──────────────────────────────────────────────────────────
	# 4. 触发信号
	# ──────────────────────────────────────────────────────────
	health_changed.emit(current_health, current_max_health)
	
	if current_health <= 0:
		print("💀 目标死亡")
		died.emit()
	
	print("   剩余生命: %.1f / %.1f" % [current_health, current_max_health])
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

# 可以用来当做帅帅的延迟伤害一起爆发 **
func apply_attack_data(attack_data: AttackData) -> void:
	take_damage(attack_data)
	
#func take_damage(attack_data: DamageEvent) -> void:
	## 计算基础伤害
	#var damage: float = attack_data.damage
	#print("敌人收到的伤害为", damage)
#
	## 如果是武器攻击，用武器数据修正伤害
	#if attack_data.source == AttackData.AttackType.WEAPON and attack_data.weapon_data:
		#var weapon := attack_data.weapon_data
		#damage = weapon.Current_damage
		#print("攻击者的武器伤害为", damage)
#
		## 命中部位倍率（只对武器生效）
		#damage *= attack_data.body_part_multiplier
		#print("命中部位倍率后伤害为", damage)
#
	## 如果是技能攻击，直接使用技能伤害（不吃部位倍率）
	#if attack_data.source == AttackData.AttackType.SKILL and attack_data.skill_data:
		#damage = attack_data.skill_data.base_damage
		#print("技能伤害为", damage, "im the real damage")
#
	## 计算收到的伤害，并且使用max防止伤害是负数的
	#var actual_damage = max(damage - current_defense, 0.0)
	#print("最终的伤害为", actual_damage)
#
	## 处理闪避与暴击
	##var is_crit := false
	##if weapon:
		## 先判断闪避
		##if randf() < base_dodge_rate:
			##print("⚡ %s 闪避了攻击！" % str(self))
			##return
##
		### 暴击判定
		##if randf() < weapon.base_crit_rate:
			##actual_damage *= attacker.base_crit_damage
			##is_crit = true
#
	## 结算伤害
	#current_health = clampf(current_health - actual_damage, 0, current_max_health)
#
	## 输出信息
	##if is_crit:
		##print("💥 暴击！")
	#print("%s 受到 %.1f 点伤害，剩余 %.1f / %.1f" 
		#% [str(self), actual_damage, current_health, current_max_health])
#
	## 触发信号
	#health_changed.emit(current_health, current_max_health)
#
	#if current_health <= 0:
		#print("💀 %s 死亡" % str(self))
		#died.emit()



## 恢复生命
func heal(amount: float) -> void:
	current_health = min(current_health + amount, current_max_health)
	print("%s 恢复 %.1f 点生命 (%.1f / %.1f)" % [str(self), amount, current_health, current_max_health])

## 增加经验
func gain_experience(amount: float) -> void:
	experience += amount
	print("%s 获得 %.1f 经验值 (当前等级 %d)" % [str(self), amount, level])
