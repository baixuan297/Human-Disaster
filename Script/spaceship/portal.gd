extends Area3D

@onready var optionmenu = $"../../CanvasLayer"

# **

func _on_entra_pressed():
	get_tree().change_scene_to_file("res://Scene/map/world.tscn")


func _on_salir_pressed():
	optionmenu.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		optionmenu.visible = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("Player"):
		optionmenu.visible = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
