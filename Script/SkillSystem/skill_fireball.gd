extends Node3D

@export var speed: float = 15.0

## 技能配置（由 Skill.gd 传入）
var skill_resource: SkillResource
var skill_level: int = 1
var caster: Node = null
## 方向和目标
var direction: Vector3 = Vector3.ZERO
var target_pos: Vector3 = Vector3.ZERO


## 设置火球数据（由 Skill._execute_projectile_skill 调用）
func setup(data: SkillResource, level: int = 1, _caster: Node = null) -> void:
	skill_resource = data
	skill_level = level
	caster = _caster

func set_target(target: Vector3):
	target_pos = target
	# 方向计算
	direction = (target_pos - global_position).normalized()

	# 确认方向
	look_at(target_pos, Vector3.UP)
	rotate_y(deg_to_rad(90))

	set_process(true)
	

## 生命周期
func _process(delta: float):
	if direction == Vector3.ZERO:
		return

	global_position += direction * speed * delta

	# 到达后销毁
	#if global_position.distance_to(target_pos) < 0.5:
		#queue_free()
	await get_tree().create_timer(5.0).timeout
	queue_free()

func _ready() -> void:
	# _ready 中创建销毁定时器
	var timer := get_tree().create_timer(5.0)
	timer.timeout.connect(_on_lifetime_expired)


func _on_lifetime_expired() -> void:
	queue_free()


func _on_hit_area_area_entered(area: Area3D) -> void:
	if not area.is_in_group("enemy"):
		return

	var attack := AttackData.create_skill_attack(skill_resource, skill_level, caster)
	
	# 在这里已经计算了 base_damage，但 final_damage 需要等部位倍率
	# 由 EnemyBodyPart.enemy_hit() 调用 apply_body_part_multiplier()
	
	# 传递给敌人身体部位
	if area.has_method("enemy_hit"):
		area.enemy_hit(attack)
	
	# 调试输出
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("🔥 火球命中！")
	print("   技能: %s (Lv.%d)" % [skill_resource.skill_name, skill_level])
	print("   基础伤害: %.1f" % attack.base_damage)
	print("   最终伤害: %.1f (在 Stats 中计算)" % attack.final_damage)
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	
	# 一次性技能，命中后销毁
	queue_free()
