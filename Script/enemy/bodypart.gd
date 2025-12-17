extends Area3D

@export var damage := 40

signal body_part_hit(dam, weapon)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.
	
func enemy_hit(weapon: WeaponData = null):
	#emit_signal("body_part_hit", damage)
	if weapon:
		body_part_hit.emit(weapon.Current_damage, weapon)
	else:
		body_part_hit.emit(damage, weapon)
