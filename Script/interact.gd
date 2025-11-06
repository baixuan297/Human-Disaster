class_name Interactable
extends Node3D

@export var promt_name = "Interact"
@export var promt_action = "interactable"

func get_promt():
	var key_name = ""
	for  action in InputMap.action_get_events(promt_action):
		if action is InputEventKey:
			key_name = OS.get_keycode_string(action.physical_keycode)
	return promt_name + "\n\n[" +  key_name + "]"
