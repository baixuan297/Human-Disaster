extends Camera3D

#@onready var mp7rig = $rig
#@onready var pistolrig = $rig

@onready var gunrig = $rig

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	#mp7rig.position.x = lerp(mp7rig.position.x, 0.0, delta * 5)
	#mp7rig.position.y = lerp(mp7rig.position.y, 0.0, delta * 5)
	#
	#pistolrig.position.x = lerp(pistolrig.position.x, 0.0, delta * 5)
	#pistolrig.position.y = lerp(pistolrig.position.y, 0.0, delta * 5)

	gunrig.position = Vector3(lerp(gunrig.position.x, 0.0, delta * 10), 
	lerp(gunrig.position.y, 0.0, delta * 10),
	lerp(gunrig.position.z, 0.0, delta * 10))

func sway(sway_amount):
	#mp7rig.position.x += sway_amount.x * 0.00005
	#mp7rig.position.y += sway_amount.y * 0.00005
	#
	#pistolrig.position.x += sway_amount.x * 0.00005
	#pistolrig.position.y += sway_amount.y * 0.00005
	
	
	gunrig.position.x += sway_amount.x * 0.00005
	gunrig.position.y += sway_amount.y * 0.00005
	gunrig.position.z += sway_amount.y * 0.00005
