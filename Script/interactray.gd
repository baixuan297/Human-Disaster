extends RayCast3D

@onready var promt = $promt
@export var player: CharacterBody3D

func _ready():
	add_exception(player)
	
func _physics_process(delta):
	promt.text = ""
	if is_colliding():
		var detected = get_collider()
		if detected is Interactable:
			promt.text = detected.get_prompt()
