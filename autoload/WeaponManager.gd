#class_name WeaponManager
extends Node

var current_weapon: Node3D

func equip_weapon(weapon_scene: PackedScene, weapon_data: WeaponData):
	if current_weapon:
		current_weapon.queue_free()

	current_weapon = weapon_scene.instantiate()
	current_weapon.data = weapon_data

	self.add_child(current_weapon)

func attack(_owner) -> void:
	if current_weapon == null:
		print("Current weapon was null")
		return
	current_weapon.attack(_owner)
