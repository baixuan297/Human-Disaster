extends Node3D

const speed = 100.0
var velocity = Vector3.ZERO

@onready var mesh = $MeshInstance3D
@onready var ray = $RayCast3D
@onready var particles = $GPUParticles3D

# 给手枪的子弹碰撞用这个来判定

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	position += transform.basis * Vector3(0, 0, -speed) * delta
	
	# 另一把枪因为子弹问题，所以只能使用人物的raycast来进行检测，所以在日后可能会进行改进来统一
	if ray.is_colliding():
		mesh.visible = false
		particles.emitting = true
		
		var collider = ray.get_collider()
		if collider.is_in_group("moveObject"):
			# 获取Ray的方向
			var ray_direction = -ray.global_transform.basis.z.normalized()

			# 反向推力
			var push_direction = ray_direction

			# 冲击力度
			var force = push_direction * 10.0
			collider.apply_central_impulse(force)

			# 防止多次施加，禁ray
			ray.enabled = false
		
		if ray.get_collider().is_in_group("enemy"):
			ray.get_collider().enemy_hit()
			ray.enabled = false
		await get_tree().create_timer(1.0).timeout
		destroy()
		
		ray.enabled = false
		
	
		
func set_velocity(target):
	look_at(target)
	velocity = position.direction_to(target) * speed

func destroy() -> void:
	queue_free()
