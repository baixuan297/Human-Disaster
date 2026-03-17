class_name Interactable
extends Node3D

@export var promt_name: String = "Interact"
@export var promt_action: StringName = &"interactable"


func get_prompt() -> String:
	var key_name := ""
	for action in InputMap.action_get_events(promt_action):
		if action is InputEventKey:
			key_name = OS.get_keycode_string(action.physical_keycode)
	return promt_name + "\n\n[" + key_name + "]"


## 玩家按交互键时由 Player._handle_interaction 调用；子类或门板等可重写或转发
func interact(_player: Node = null) -> void:
	pass
