extends Node3D

@export var speed: float = 15.0

var direction: Vector3 = Vector3.ZERO
var target_pos: Vector3 = Vector3.ZERO


func set_target(target: Vector3):
	target_pos = target
	direction = (target_pos - global_position).normalized()  # 方向计算

	look_at(target_pos, Vector3.UP)

	set_process(true)  # 启用process(可选)
	


func _process(delta: float):
	if direction == Vector3.ZERO:
		return

	global_position += direction * speed * delta

	# 到达后销毁
	if global_position.distance_to(target_pos) < 0.5:
		queue_free()
