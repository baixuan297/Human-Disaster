extends Node3D


var direction = Vector2.ZERO
var mouse_position = Vector2.ZERO

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
 
func _unhandled_input(event):
	if event is InputEventMouseMotion:
		mouse_position.x = -event.global_position.x * 0.009 + 13
		mouse_position.y = -event.global_position.y * 0.009 + 13
		global_position.x = mouse_position.x

func _physics_process(delta):
	direction = lerp(direction, (Vector2(mouse_position.x, mouse_position.y)).normalized(), delta * 0.1)
	
