## BaseEnemy.gd — 所有敌人的基类
##
## 架构：Stats 为血量唯一来源，伤害统一走 stats.take_damage(AttackData)
##   Hurtboxes.body_part_hit → _on_area_3d_body_part_hit → stats.take_damage
##   stats.health_changed → _on_health_changed → 更新血条 UI
##   stats.died → _on_died → 清理并 queue_free
##
## 扩展：apply_dot()、apply_debuff() 供 Skill.gd 的 DOT/DEBUFF 调用

extends CharacterBody3D
class_name BaseEnemy

# ── 信号 ─────────────────────────────────────────────────────────────────────
## 被命中时发出（供 WeaponManager / UI 等监听）
signal enemy_hit

# ── 节点引用 ──────────────────────────────────────────────────────────────────
@export var stats: Stats
## 击杀时奖励给「最后一击」来源（沿节点树向上查找 Player 组）的经验
@export var experience_reward: float = 25.0

@onready var health_bar = $Stats/SubViewport/health_bar
@onready var stats_node: Node3D = $Stats          ## 头顶血条容器

# Hurtboxes 在 _ready 内安全获取，子类可覆盖
var hurt_boxes: Area3D
## 最后一次有效伤害的来源（武器/技能发起者），用于结算经验
var _last_damage_attacker: Node = null


# ═══════════════════════════════════════════════════════════════════
# 生命周期
# ═══════════════════════════════════════════════════════════════════

func _ready() -> void:
	# 连接属性信号
	stats.health_changed.connect(_on_health_changed)
	stats.died.connect(_on_died)

	# 初始化血条（0~100 百分比显示）
	if health_bar:
		health_bar.max_value = 100.0
		health_bar.value = _health_percent()

	# 连接部位碰撞（安全获取，子类也可手动 setup）
	hurt_boxes = get_node_or_null("Hurtboxes")
	if hurt_boxes:
		hurt_boxes.body_part_hit.connect(_on_area_3d_body_part_hit)


# ═══════════════════════════════════════════════════════════════════
# 受击路径
# ═══════════════════════════════════════════════════════════════════

func _on_area_3d_body_part_hit(attack_data: AttackData) -> void:
	enemy_hit.emit()
	_record_last_attacker(attack_data)
	stats.take_damage(attack_data)


# ═══════════════════════════════════════════════════════════════════
# 属性 / 死亡信号回调（子类可 override）
# ═══════════════════════════════════════════════════════════════════

func _on_health_changed(cur_health: float, max_health: float) -> void:
	if health_bar:
		health_bar.value = _health_percent()
	print("敌人当前血量: %.1f / %.1f" % [cur_health, max_health])


func _on_died() -> void:
	print("💀 敌人死亡")
	_grant_experience_to_killer()
	delete_collision_nodes(self)
	if stats_node:
		stats_node.queue_free()
	queue_free()


# ═══════════════════════════════════════════════════════════════════
# DOT（持续伤害）—— 由 Skill.gd._execute_dot_skill() 调用
# ═══════════════════════════════════════════════════════════════════

## 对自身施加持续伤害效果
## damage_per_tick : 每跳伤害（已扣防御前）
## total_ticks     : 总跳数
## tick_interval   : 每跳间隔（秒）
## source          : 施法者（用于追踪，可为 null）
func apply_dot(
	damage_per_tick: float,
	total_ticks:     int,
	tick_interval:   float = 1.0,
	source:          Node  = null
) -> void:
	if total_ticks <= 0 or damage_per_tick <= 0.0:
		return

	var ticks_done := [0]  ## 用数组包装，闭包内可正确修改

	# 使用 SceneTreeTimer 驱动 tick，避免在 Resource 里创建 Timer 节点
	var _do_tick: Callable  # 前向声明，闭包内可递归调用

	_do_tick = func():
		if not is_instance_valid(self):
			return
		if stats == null:
			return

		ticks_done[0] += 1

		_set_last_attacker_node(source)

		# 构造无部位倍率的技能攻击数据
		var attack := AttackData.new()
		attack.source        = AttackData.AttackType.SKILL
		attack.source_node   = source
		attack.base_damage   = damage_per_tick
		attack.final_damage  = damage_per_tick  # DOT 不走部位倍率
		attack.body_part_multiplier = 1.0

		stats.take_damage(attack)

		# 还有剩余 tick 则继续安排
		if ticks_done[0] < total_ticks:
			get_tree().create_timer(tick_interval).timeout.connect(_do_tick)

	# 第一跳延迟 tick_interval 触发
	get_tree().create_timer(tick_interval).timeout.connect(_do_tick)

	print("🟠 DOT 挂载：%.1f 伤害 × %d 跳，每 %.1fs" % [damage_per_tick, total_ticks, tick_interval])


# ═══════════════════════════════════════════════════════════════════
# DEBUFF（属性减益）—— 由 Skill.gd._execute_debuff_skill() 调用
# ═══════════════════════════════════════════════════════════════════

## 对自身施加属性减益
## stat_type  : 被影响的属性（Stats.BuffableStats 枚举值）
## amount     : 减益量（Add 类型传负数；Multiply 类型传负偏移，如 -0.3 = ×0.7）
## buff_type  : Add 或 Multiply
## duration   : 持续时间（秒），0 = 永久
func apply_debuff(
	stat_type: Stats.BuffableStats,
	amount:    float,
	buff_type: StatBuff.BuffType = StatBuff.BuffType.Multiply,
	duration:  float = 5.0
) -> void:
	if stats == null:
		return

	# 创建减益 StatBuff
	var debuff := StatBuff.new(stat_type, amount, buff_type)
	debuff.source_node = null  # 来自技能，不绑定特定节点

	stats.add_buff(debuff)
	print("🔵 DEBUFF 挂载：%s  amount=%.2f  持续 %.1fs" % [
		Stats.BuffableStats.keys()[stat_type], amount, duration
	])

	# duration > 0 才安排自动移除
	if duration > 0.0:
		get_tree().create_timer(duration).timeout.connect(func():
			if is_instance_valid(self) and stats != null:
				stats.remove_buff(debuff)
				print("🔵 DEBUFF 移除：%s" % Stats.BuffableStats.keys()[stat_type])
		)


# ═══════════════════════════════════════════════════════════════════
# 工具
# ═══════════════════════════════════════════════════════════════════

## 兼容旧接口：poison_pool 等调用 take_damage() 时使用
## 使用固定伤害构造 AttackData 并走 stats.take_damage
func take_damage(amount: float = 10.0) -> void:
	var attack := AttackData.new()
	attack.source = AttackData.AttackType.WEAPON
	attack.source_node = null
	attack.base_damage = amount
	attack.final_damage = amount
	attack.body_part_multiplier = 1.0
	apply_attack_data(attack)


## 外部可调用：直接接收 AttackData（如技能瞬发命中）
func apply_attack_data(attack_data: AttackData) -> void:
	if attack_data == null:
		return
	enemy_hit.emit()
	_record_last_attacker(attack_data)
	stats.take_damage(attack_data)


func _set_last_attacker_node(src: Node) -> void:
	if src != null and is_instance_valid(src):
		_last_damage_attacker = src


func _record_last_attacker(attack_data: AttackData) -> void:
	if attack_data == null:
		return
	_set_last_attacker_node(attack_data.source_node)


func _grant_experience_to_killer() -> void:
	if experience_reward <= 0.0:
		return
	var node: Node = _last_damage_attacker
	while node != null:
		if node.is_in_group("Player"):
			var ps: Variant = node.get("playerStats")
			if ps is Stats:
				(ps as Stats).gain_experience(experience_reward)
			return
		node = node.get_parent()


## 递归清除碰撞体（死亡时防止尸体继续挡路）
func delete_collision_nodes(node: Node) -> void:
	for child in node.get_children():
		if child is CollisionShape3D:
			child.queue_free()
		delete_collision_nodes(child)


## 血量百分比（0~100），供血条使用
func _health_percent() -> float:
	if stats.current_max_health <= 0.0:
		return 0.0
	return (stats.current_health / stats.current_max_health) * 100.0
