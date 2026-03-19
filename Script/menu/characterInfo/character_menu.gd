extends Control

@onready var skill_ui: Control = $Panel/SkillUI


var pauseManager: PauseManager
var uiManager: UiManager

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pauseManager = PauseManager
	uiManager = UiManager
	
	pauseManager.open_characterInfo()
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	skill_ui.visible = false

func _on_attributes_button_pressed() -> void:
	skill_ui.visible = false


func _on_weapon_button_pressed() -> void:
	pass # Replace with function body.


func _on_skill_button_pressed() -> void:
	skill_ui.visible = true

func _on_core_button_pressed() -> void:
	pass # Replace with function body.


func _on_talents_button_pressed() -> void:
	pass # Replace with function body.


func _on_profile_button_pressed() -> void:
	pass # Replace with function body.


func _on_exit_button_pressed() -> void:
	print("closing...")
	pauseManager.close_characterInfo()
	uiManager.close_current_ui()
