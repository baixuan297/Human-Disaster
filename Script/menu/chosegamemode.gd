extends Control

func _ready() -> void:
	var btn2: BaseButton = $Button2
	btn2.disabled = true
	if UserManager.current_character_id.is_empty():
		btn2.disabled = false
		return
	CharacterDataManager.fetch_stats_snapshot_for_menu(func(ok: bool):
		if not ok:
			btn2.disabled = false
			return
		if CharacterDataManager.has_tutorial_completed():
			btn2.disabled = false
		else:
			btn2.disabled = true
			btn2.tooltip_text = "完成新手教程后解锁"
	)


## 进入游戏前预加载角色数据（位置、武器、背包等），加载完成后再切换场景
func _on_button_pressed():
	if UserManager.current_character_id.is_empty():
		SceneManager.change_scene_to_file("res://Scene/map/world.tscn")
		return
	CharacterDataManager.load_and_apply()
	CharacterDataManager.character_data_loaded.connect(_on_character_data_loaded, CONNECT_ONE_SHOT)


func _on_character_data_loaded() -> void:
	if CharacterDataManager.has_tutorial_completed():
		SceneManager.change_scene("game")
	else:
		SceneManager.change_scene("tutorial")


func _on_button_2_pressed():
	if not UserManager.current_character_id.is_empty() and not CharacterDataManager.has_tutorial_completed():
		GlobalMessage.emit_toast("请先完成新手教程", "warning")
		return
	SceneManager.change_scene_to_file("res://Scene/Multiplayer/Login_menu.tscn")
