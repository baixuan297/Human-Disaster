extends Node3D

@export var data: WeaponData
var can_fire: bool = true

func attack(_owner) -> void:
	if not can_fire:
		return
	can_fire = false

	#fire_projectile(_owner)

	await get_tree().create_timer(data.fire_rate).timeout
	can_fire = true


#func fire_projectile(_owner):
	#var bullet = data.projectile_scene.instantiate()
	##bullet.global_transform = $Muzzle.global_transform
	#bullet.position = $muzzle_ray.global_position
	#
	#get_tree().current_scene.add_child(bullet)
	#
	#if _owner.has_method("get_aim_target"):
		#var target_position = _owner.get_aim_target(0)
		#bullet.set_velocity(target_position)
	
	#bullet.direction = _owner.get_aim_direction()
	#add_child(bullet)
