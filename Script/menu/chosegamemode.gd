extends Control

## 进入游戏前预加载角色数据（位置、武器、背包等），加载完成后再切换场景
func _on_button_pressed():
	if UserManager.current_character_id.is_empty():
		SceneManager.change_scene_to_file("res://Scene/map/world.tscn")
		return
	CharacterDataManager.load_and_apply()
	CharacterDataManager.character_data_loaded.connect(_on_character_data_loaded, CONNECT_ONE_SHOT)


func _on_character_data_loaded() -> void:
	SceneManager.change_scene_to_file("res://Scene/map/world.tscn")


func _on_button_2_pressed():
	SceneManager.change_scene_to_file("res://Scene/Multiplayer/Login_menu.tscn")
