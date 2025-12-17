extends Control

var pauseManager: PauseManager
var uiManager: UiManager

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pauseManager = PauseManager
	uiManager = UiManager


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_attributes_button_pressed() -> void:
	pass # Replace with function body.


func _on_weapon_button_pressed() -> void:
	pass # Replace with function body.


func _on_skill_button_pressed() -> void:
	pass # Replace with function body.


func _on_core_button_pressed() -> void:
	pass # Replace with function body.


func _on_talents_button_pressed() -> void:
	pass # Replace with function body.


func _on_profile_button_pressed() -> void:
	pass # Replace with function body.


func _on_exit_button_pressed() -> void:
	pauseManager.close_inventory()
	uiManager.close_current_ui()
