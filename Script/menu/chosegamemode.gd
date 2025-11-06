extends Control
	
func _on_button_pressed():
	SceneManager.change_scene_to_file("res://Scene/map/world.tscn")


func _on_button_2_pressed():
	SceneManager.change_scene_to_file("res://Scene/Multiplayer/Login_menu.tscn")
