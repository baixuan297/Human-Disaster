## Skill — 单个技能运行时实例；由 SkillManager 创建并作为其子节点管理生命周期。
##
## 职责：冷却计时、等级换算、分发到具体 SkillType 的执行函数。
## 数据来源：所有静态属性从 `skill_resource` 读取，见 `docs/SKILL_SYSTEM.md`。
class_name Skill
extends Node

# ── 信号 ──────────────────────────────────────────────────────────────────────
signal skill_used(skill: Skill)
signal skill_level_up(new_level: int)
signal cooldown_finished

# ── 核心属性 ──────────────────────────────────────────────────────────────────
@export var skill_resource: SkillResource

var current_level: int = 1
var is_on_cooldown: bool = false
var cooldown_remaining: float = 0.0

## 技能所有者（Player / 敌人节点）；SkillManager.add_skill 会在复用时刷新此引用
var owner_node: Node3D


# =============================================================================
# 生命周期
# =============================================================================

func _ready() -> void:
	if skill_resource == null:
		push_error("[Skill] skill_resource 未设置!")
		return
	if OS.is_debug_build():
		print("🔧 技能初始化: %s | CD: %.1fs" % [skill_resource.skill_name, get_cooldown()])


func _process(delta: float) -> void:
	if is_on_cooldown:
		cooldown_remaining -= delta
		if cooldown_remaining <= 0.0:
			is_on_cooldown     = false
			cooldown_remaining = 0.0
			cooldown_finished.emit()


# =============================================================================
# 公共接口
# =============================================================================

func use(target_position: Vector3 = Vector3.ZERO, target_node: Node3D = null) -> bool:
	if not can_use():
		return false

	_execute_skill(target_position, target_node)
	start_cooldown()
	skill_used.emit(self)
	return true


func can_use() -> bool:
	return not is_on_cooldown


func start_cooldown() -> void:
	is_on_cooldown     = true
	cooldown_remaining = get_cooldown()


func level_up() -> bool:
	if current_level >= skill_resource.max_level:
		return false
	current_level += 1
	skill_level_up.emit(current_level)
	return true


func set_level(level: int) -> void:
	current_level = clamp(level, 1, skill_resource.max_level)


# =============================================================================
# 技能执行分发
# =============================================================================

func _execute_skill(target_position: Vector3, target_node: Node3D) -> void:
	match skill_resource.skill_type:
		SkillResource.SkillType.INSTANT:
			_execute_instant_skill(target_position, target_node)
		SkillResource.SkillType.PROJECTILE:
			_execute_projectile_skill(target_position)
		SkillResource.SkillType.AOE:
			_execute_aoe_skill(target_position)
		SkillResource.SkillType.DOT:
			_execute_dot_skill(target_node)
		SkillResource.SkillType.BUFF:
			_execute_buff_skill(target_position)
		SkillResource.SkillType.DEBUFF:
			_execute_debuff_skill(target_node)

	_play_effects()


# =============================================================================
# 各技能类型实现
# =============================================================================

## ── INSTANT（瞬发）────────────────────────────────────────────────────────────
func _execute_instant_skill(_target_position: Vector3, target_node: Node3D) -> void:
	if target_node == null:
		return
	var attack := _build_skill_attack_with_modifiers(target_node)
	dispatch_attack(target_node, attack)


## ── PROJECTILE（投射物）──────────────────────────────────────────────────────
func _execute_projectile_skill(target_position: Vector3) -> void:
	if skill_resource.cast_effect == null or owner_node == null:
		push_warning("[Skill:%s] 缺少 cast_effect 或 owner_node" % skill_resource.skill_name)
		return

	var projectile: Node3D = skill_resource.cast_effect.instantiate()
	owner_node.get_parent().add_child(projectile)

	var hand_node: Marker3D = owner_node.get_node_or_null("Hand_node")
	projectile.global_position = hand_node.global_position if hand_node else owner_node.global_position

	if projectile.has_method("setup"):
		projectile.setup(skill_resource, current_level, owner_node, get_duration())
	if projectile.has_method("set_target"):
		projectile.set_target(target_position)


## ── AOE（范围伤害）────────────────────────────────────────────────────────────
func _execute_aoe_skill(target_position: Vector3) -> void:
	if skill_resource.cast_effect == null:
		push_warning("[Skill:%s] 缺少 cast_effect" % skill_resource.skill_name)
		return

	var aoe_node: Node3D = skill_resource.cast_effect.instantiate()
	owner_node.get_parent().add_child(aoe_node)
	aoe_node.global_position = _get_ground_position(target_position)

	## duration<=0 时效果脚本内部会退化为默认值（见 skill_lightning / skill_group_healing）
	var duration: float = get_duration()
	if duration <= 0.0:
		duration = skill_resource.base_duration
	if aoe_node.has_method("setup"):
		aoe_node.setup(skill_resource, current_level, owner_node, duration)


## ── DOT（持续伤害）────────────────────────────────────────────────────────────
## 通过 _get_target_stats() 找到目标的 Stats Resource，调用 stats.apply_dot() 挂载 DOT。
func _execute_dot_skill(target_node: Node3D) -> void:
	if target_node == null:
		push_warning("[Skill:%s] DOT 目标为 null" % skill_resource.skill_name)
		return

	var target_stats := _get_target_stats(target_node)
	if target_stats == null:
		push_warning("[Skill:%s] 目标 [%s] 无 Stats，无法施加 DOT" % [
			skill_resource.skill_name, target_node.name
		])
		return

	## 将总伤害均分到每次 tick
	var duration:      float = get_duration()
	var tick_interval: float = 1.0                              ## 每秒 tick 一次
	var ticks:         float = maxf(duration / tick_interval, 1.0)
	var dps:           float = get_damage() / ticks

	target_stats.apply_dot(target_node, dps, tick_interval, duration, owner_node)

	print("☠️  [Skill:%s] DOT 施加：%.1f/tick × %.0f 秒 → [%s]" % [
		skill_resource.skill_name, dps, duration, target_node.name
	])


## ── BUFF（增益区域/自身）─────────────────────────────────────────────────────
func _execute_buff_skill(target_position: Vector3) -> void:
	if skill_resource.cast_effect == null:
		return

	var buff_area: Node3D = skill_resource.cast_effect.instantiate()
	owner_node.get_parent().add_child(buff_area)
	buff_area.global_position = _get_ground_position(target_position)

	var duration: float = get_duration()
	if duration <= 0.0:
		duration = skill_resource.base_duration
	if buff_area.has_method("setup"):
		buff_area.setup(skill_resource, current_level, owner_node, duration)


## ── DEBUFF（减益）─────────────────────────────────────────────────────────────
## 通过 StatBuff + stats.add_temporary_buff() 临时削弱目标属性。
## 当前硬编码为攻防 -25%；后续可按 SkillResource.metadata 配置减益项。
func _execute_debuff_skill(target_node: Node3D) -> void:
	if target_node == null:
		push_warning("[Skill:%s] DEBUFF 目标为 null" % skill_resource.skill_name)
		return

	var target_stats := _get_target_stats(target_node)
	if target_stats == null:
		push_warning("[Skill:%s] 目标 [%s] 无 Stats，无法施加 DEBUFF" % [
			skill_resource.skill_name, target_node.name
		])
		return

	var duration: float = get_duration()

	## 攻击力减益（负乘数 = 减少）
	var atk_debuff := StatBuff.make_multiply(
		Stats.BuffableStats.ATTACK,
		-0.25   ## -25% 攻击力，可后续改为从 skill_resource 读取
	)
	## 防御力减益
	var def_debuff := StatBuff.make_multiply(
		Stats.BuffableStats.DEFENSE,
		-0.25
	)

	target_stats.add_temporary_buff(atk_debuff, duration, target_node)
	target_stats.add_temporary_buff(def_debuff, duration, target_node)

	print("🔻 [Skill:%s] DEBUFF 施加：ATK/DEF -25%% 持续 %.1f 秒 → [%s]" % [
		skill_resource.skill_name, duration, target_node.name
	])

	## 可选：生成视觉特效
	if skill_resource.hit_effect and target_node:
		var vfx: Node3D = skill_resource.hit_effect.instantiate()
		target_node.add_child(vfx)


# =============================================================================
# 辅助：伤害构造 / 派发（供瞬发及将来其他类型复用）
# =============================================================================

## 构造一个考虑暴击、标签、基因加成的技能攻击包。`base_damage` 与 `final_damage` 同步推进。
func _build_skill_attack_with_modifiers(target_node: Node3D) -> AttackData:
	var attack := AttackData.create_skill_attack(skill_resource, current_level, owner_node)
	var caster_stats := _get_owner_stats()
	if caster_stats and caster_stats.roll_critical():
		attack.final_damage = caster_stats.apply_crit_multiplier(attack.final_damage)
		attack.is_critical = true
	if caster_stats and target_node != null and target_node.has_method("get_combat_tags"):
		var tags: Array = target_node.get_combat_tags()
		attack.final_damage = GeneManager.apply_outgoing_damage_vs_tags(attack.final_damage, tags)
	if attack.is_critical and caster_stats and target_node != null:
		var target_stats := _get_target_stats(target_node)
		if target_stats:
			attack.final_damage += GeneManager.get_crit_bonus_damage_from_target_current_hp(target_stats.current_health)
	## 与 final_damage 对齐，防止 apply_body_part_multiplier 误伤或其他消费者只读 base_damage
	attack.base_damage = attack.final_damage
	return attack


## 统一把攻击派发给目标：优先 apply_attack_data，其次 take_damage / enemy_hit。
## 投射物 / AOE / INSTANT 都应通过此函数派发，避免各处重复的 has_method 分支。
static func dispatch_attack(target: Node, attack: AttackData) -> void:
	if target == null or not is_instance_valid(target):
		return
	if target.has_method("apply_attack_data"):
		target.apply_attack_data(attack)
	elif target.has_method("take_damage"):
		target.take_damage(attack)
	elif target.has_method("enemy_hit"):
		target.enemy_hit(attack)


# =============================================================================
# 辅助：获取 Stats Resource（兼容 enemy.stats 和 Player.player_stats）
# =============================================================================

## 从目标节点取出 Stats Resource
## 优先查 .stats（BaseEnemy），其次查 .player_stats（Player）
func _get_target_stats(target: Node3D) -> Stats:
	var s = target.get("stats")
	if s is Stats:
		return s
	s = target.get("player_stats")
	if s is Stats:
		return s
	return null


## 获取施法者自身的 Stats（兼顾 owner_node 已释放的场景）
func _get_owner_stats() -> Stats:
	if owner_node == null or not is_instance_valid(owner_node):
		return null
	return _get_target_stats(owner_node)


## 获取地面位置（防止技能效果悬空）
func _get_ground_position(pos: Vector3) -> Vector3:
	if owner_node == null:
		return pos
	var space  := owner_node.get_world_3d().direct_space_state
	var query  := PhysicsRayQueryParameters3D.create(pos + Vector3.UP, pos + Vector3.DOWN * 5.0)
	query.collision_mask = CollisionLayers.MASK_WORLD
	var result := space.intersect_ray(query)
	return result.position if result else pos


## 播放施法音效
func _play_effects() -> void:
	if skill_resource.cast_sound == null or owner_node == null:
		return
	var audio := AudioStreamPlayer3D.new()
	audio.stream = skill_resource.cast_sound
	owner_node.add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)


# =============================================================================
# 属性读取（代理 SkillResource）
# =============================================================================

func get_damage()       -> float: return skill_resource.get_damage(current_level)
func get_attack_power() -> float: return skill_resource.get_attack_power(current_level)
func get_cooldown() -> float:
	var base_cd: float = skill_resource.get_cooldown(current_level)
	var owner_stats := _get_owner_stats()
	if owner_stats and owner_stats.has_method("get_skill_cooldown_multiplier"):
		return base_cd * owner_stats.get_skill_cooldown_multiplier()
	return base_cd
func get_range()        -> float: return skill_resource.get_range(current_level)
func get_duration()     -> float: return skill_resource.get_duration(current_level)


func get_info() -> Dictionary:
	var info := skill_resource.get_skill_info(current_level)
	info["cooldown_remaining"] = cooldown_remaining
	info["is_on_cooldown"]     = is_on_cooldown
	return info
