#extends Node3D
#
#const speed = 100.0
#var velocity = Vector3.ZERO
#
#@onready var mesh = $MeshInstance3D
#@onready var ray = $RayCast3D
#@onready var particles = $GPUParticles3D
#
## 给手枪的子弹碰撞用这个来判定
#
## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
	#position += transform.basis * Vector3(0, 0, -speed) * delta
	#
	## 另一把枪因为子弹问题，所以只能使用人物的raycast来进行检测，所以在日后可能会进行改进来统一
	#if ray.is_colliding():
		#mesh.visible = false
		#particles.emitting = true
		#
		#var collider = ray.get_collider()
		#if collider.is_in_group("moveObject"):
			## 获取Ray的方向
			#var ray_direction = -ray.global_transform.basis.z.normalized()
#
			## 反向推力
			#var push_direction = ray_direction
#
			## 冲击力度
			#var force = push_direction * 10.0
			#collider.apply_central_impulse(force)
#
			## 防止多次施加，禁ray
			#ray.enabled = false
		#
		#if ray.get_collider().is_in_group("enemy"):
			#ray.get_collider().enemy_hit()
			#ray.enabled = false
		#await get_tree().create_timer(1.0).timeout
		#destroy()
		#
		#ray.enabled = false
		#
	#
		#
#func set_velocity(target):
	#look_at(target)
	#velocity = position.direction_to(target) * speed
#
#func destroy() -> void:
	#queue_free()

extends Node3D
class_name Bullet

## ═══════════════════════════════════════════════════════════════
## Bullet — 物理子弹（半自动武器用；全自动由 WeaponManager 射线即时判定）
##
## 【调用链】仅由 BaseWeapon._fire_projectile() 实例化并调用 init_with_data/set_velocity，
##           WeaponManager 与 Player 不直接引用本类。
##
## 【设计】_process 中沿朝向移动，RayCast3D 做碰撞检测，命中后应用伤害与推力。
##        比纯射线更精确：子弹实体可被墙体遮挡。
##
## 【接口】init_with_data(target, weapon_data, shooter) 推荐；set_velocity(target) 兼容旧版。
## ═══════════════════════════════════════════════════════════════


# ──────────────────────────────────────────────────────────────
#  飞行参数
# ──────────────────────────────────────────────────────────────

## 飞行速度（单位/秒）
const SPEED: float = 120.0

## 最大存活距离（超过则自动销毁，防止无限飞行）
const MAX_TRAVEL_DISTANCE: float = 200.0

## 命中后粒子效果播放等待时间
const HIT_EFFECT_WAIT: float = 0.8


# ──────────────────────────────────────────────────────────────
#  节点引用
# ──────────────────────────────────────────────────────────────

@onready var _mesh:      MeshInstance3D = $MeshInstance3D
@onready var _ray:       RayCast3D      = $RayCast3D
@onready var _particles: GPUParticles3D = $GPUParticles3D


# ──────────────────────────────────────────────────────────────
#  运行时状态
# ──────────────────────────────────────────────────────────────

## 当前携带的武器数据（init_with_data 时赋值）
var _weapon_data: WeaponData   = null

## 发射者（用于 AttackData 构造，避免子弹伤害到自己）
var _shooter: Node3D            = null

## 子弹已飞行距离（距离超限自动销毁）
var _traveled: float            = 0.0

## 是否已命中（防止多帧重复判定）
var _has_hit: bool              = false

# ═══════════════════════════════════════════════════════════════
#  生命周期
# ═══════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	if _has_hit:
		return

	var step := transform.basis * Vector3(0.0, 0.0, -SPEED) * delta
	position  += step
	_traveled += step.length()

	if _traveled > MAX_TRAVEL_DISTANCE:
		queue_free()
		return

	if _ray.is_colliding():
		_on_hit()


# ═══════════════════════════════════════════════════════════════
#  公开 API：初始化
# ═══════════════════════════════════════════════════════════════

## 【推荐】携带 WeaponData，可计算暴击与元素伤害
func init_with_data(target: Vector3, weapon_data: WeaponData, shooter: Node3D) -> void:
	_weapon_data = weapon_data
	_shooter     = shooter
	_aim_at(target)

## 【向后兼容】旧接口
func set_velocity(target: Vector3) -> void:
	_aim_at(target)


# ═══════════════════════════════════════════════════════════════
#  内部：命中
# ═══════════════════════════════════════════════════════════════

func _on_hit() -> void:
	_has_hit     = true
	_ray.enabled = false

	_mesh.visible = false
	if _particles:
		_particles.emitting = true

	var collider := _ray.get_collider()
	if collider == null:
		_wait_and_destroy()
		return

	if collider.is_in_group("enemy") and collider.has_method("enemy_hit"):
		_apply_damage_to(collider)

	if collider.is_in_group("moveObject") and collider is RigidBody3D:
		var push_dir := -_ray.global_transform.basis.z.normalized()
		collider.apply_central_impulse(push_dir * 10.0)

	_wait_and_destroy()


func _apply_damage_to(target: Node) -> void:
	if _weapon_data != null:
		# 若发射者为玩家，使用玩家暴击率与暴击倍率覆盖
		var override_crit_rate: float = -1.0
		var override_crit_mult: float = -1.0
		if _shooter and _shooter.get("player_stats"):
			var s = _shooter.player_stats
			if s:
				override_crit_rate = s.current_critical_rate
				override_crit_mult = s.current_critical_damage
		var result    := _weapon_data.calculate_damage(override_crit_rate, override_crit_mult)
		var dmg: int   = result[0]
		var is_crit: bool = result[1]

		var attack := AttackData.create_weapon_attack(_weapon_data, _shooter)
		# 暴击后的伤害写入 base_damage，EnemyBodyPart.apply_body_part_multiplier 会据此计算 final_damage
		attack.base_damage = dmg

		target.enemy_hit(attack)

		if is_crit:
			# TODO: 暴击数字 UI 反馈
			pass
	else:
		# 降级：无武器数据时直接调用
		if target.has_method("enemy_hit"):
			target.enemy_hit(null)


func _wait_and_destroy() -> void:
	await get_tree().create_timer(HIT_EFFECT_WAIT).timeout
	queue_free()


func _aim_at(target: Vector3) -> void:
	if global_position.distance_to(target) < 0.01:
		return
	look_at(target)
