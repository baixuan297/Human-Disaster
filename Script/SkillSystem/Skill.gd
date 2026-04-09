## Skill.gd — 单个技能运行时实例（完整修复版）
##
## 修复/新增：
##   1. [FIX]  _execute_dot_skill   — 调用 target 的 stats.apply_dot()（原调用不存在的方法）
##   2. [NEW]  _execute_debuff_skill — 通过 StatBuff + stats.add_temporary_buff() 实现减益
##   3. [NEW]  _get_target_stats()  — 统一获取目标 Stats（兼容 .stats 和 .player_stats）
##   4. [KEEP] 其他所有现有逻辑保持不变（INSTANT / PROJECTILE / AOE / BUFF）


class_name Skill
extends Node

# ── 信号 ──────────────────────────────────────────────────────────────────────
signal skill_used(skill: Skill)
signal skill_level_up(new_level: int)
signal cooldown_finished

# ── 核心属性 ──────────────────────────────────────────────────────────────────
@export var skill_resource: SkillResource

var current_level:     int   = 1
var is_on_cooldown:    bool  = false
var cooldown_remaining:float = 0.0

## 技能所有者（Player / 敌人节点）
var owner_node: Node3D


# =============================================================================
# 生命周期
# =============================================================================

func _ready() -> void:
	if skill_resource == null:
		push_error("[Skill] skill_resource 未设置!")
		return
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
func _execute_instant_skill(target_position: Vector3, target_node: Node3D) -> void:
	if target_node == null:
		return

	var attack := AttackData.create_skill_attack(skill_resource, current_level, owner_node)
	attack.final_damage = attack.base_damage

	## 暴击判定（通过施法者属性）
	var caster_stats := _get_owner_stats()
	if caster_stats and caster_stats.roll_critical():
		attack.final_damage  = caster_stats.apply_crit_multiplier(attack.final_damage)
		attack.is_critical   = true

	if target_node.has_method("apply_attack_data"):
		target_node.apply_attack_data(attack)
	elif target_node.has_method("take_damage"):
		target_node.take_damage(attack)


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
		projectile.setup(skill_resource, current_level, owner_node)
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

	if aoe_node.has_method("setup"):
		aoe_node.setup(skill_resource, current_level, owner_node, 3.0)


## ── DOT（持续伤害）────────────────────────────────────────────────────────────
## 修复：原代码调用 target_node.apply_dot()，但 Player/Enemy 身上均无此方法
## 修复后：通过 _get_target_stats() 找到 Stats Resource，调用 stats.apply_dot()
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

	if buff_area.has_method("setup"):
		buff_area.setup(skill_resource, current_level, owner_node, skill_resource.base_duration)


## ── DEBUFF（减益）─────────────────────────────────────────────────────────────
## 新增：通过 StatBuff + stats.add_temporary_buff() 实现属性减益
## 减益内容：攻击力 -25%（Multiply -0.25），防御力 -25%，持续 get_duration() 秒
## 可扩展：将减益类型/幅度配置到 SkillResource.metadata 中
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


## 获取施法者自身的 Stats
func _get_owner_stats() -> Stats:
	if owner_node == null:
		return null
	return _get_target_stats(owner_node)


## 获取地面位置（防止技能效果悬空）
func _get_ground_position(pos: Vector3) -> Vector3:
	if owner_node == null:
		return pos
	var space  := owner_node.get_world_3d().direct_space_state
	var query  := PhysicsRayQueryParameters3D.create(pos + Vector3.UP, pos + Vector3.DOWN * 5.0)
	query.collision_mask = 1
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
func get_cooldown()     -> float: return skill_resource.get_cooldown(current_level)
func get_range()        -> float: return skill_resource.get_range(current_level)
func get_duration()     -> float: return skill_resource.get_duration(current_level)


func get_info() -> Dictionary:
	var info := skill_resource.get_skill_info(current_level)
	info["cooldown_remaining"] = cooldown_remaining
	info["is_on_cooldown"]     = is_on_cooldown
	return info
