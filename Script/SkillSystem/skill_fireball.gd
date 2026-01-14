extends Node3D

@export var speed: float = 15.0

var skill_resource: SkillResource

var direction: Vector3 = Vector3.ZERO
var target_pos: Vector3 = Vector3.ZERO


func setup(data: SkillResource) -> void:
	skill_resource = data

func set_target(target: Vector3):
	target_pos = target
	direction = (target_pos - global_position).normalized()  # 方向计算

	look_at(target_pos, Vector3.UP)
	
	rotate_y(deg_to_rad(90))

	set_process(true)  # 启用process(可选)
	


func _process(delta: float):
	if direction == Vector3.ZERO:
		return

	global_position += direction * speed * delta

	# 到达后销毁
	#if global_position.distance_to(target_pos) < 0.5:
		#queue_free()
	await get_tree().create_timer(5.0).timeout
	queue_free()


func _on_hit_area_area_entered(area: Area3D) -> void:
	if not area.is_in_group("enemy"):
		return

	var attack := AttackData.new()
	attack.source = AttackData.AttackType.SKILL
	attack.skill_data = skill_resource

	area.enemy_hit(attack)
	print("技能命中")
	print(attack.damage)

	queue_free() # 一次性技能
