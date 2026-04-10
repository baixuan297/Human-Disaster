extends RefCounted
class_name EnemyMeleeLocomotion

## 地面近战敌人：平面移动与巡逻点采样（无状态、无节点）


static func move_toward_on_plane(
	body: CharacterBody3D,
	target: Vector3,
	speed: float,
	delta: float,
	turn_lerp: float = 12.0
) -> void:
	var dir: Vector3 = target - body.global_position
	dir.y = 0.0
	if dir.length_squared() < 0.01:
		body.velocity = Vector3.ZERO
	else:
		dir = dir.normalized()
		body.velocity = dir * speed
		body.rotation.y = lerp_angle(
			body.rotation.y,
			atan2(-body.velocity.x, -body.velocity.z),
			delta * turn_lerp
		)
	body.move_and_slide()


static func pick_patrol_point(spawn_origin: Vector3, patrol_radius: float) -> Vector3:
	var angle: float = randf_range(0.0, TAU)
	var radius: float = randf_range(patrol_radius * 0.3, patrol_radius)
	return spawn_origin + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
