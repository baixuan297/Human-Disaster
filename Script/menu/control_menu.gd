class_name Button_hot_key
extends Control

@onready var label = $HBoxContainer/Label
@onready var button = $HBoxContainer/Button

@export var action_name : String = "move_left"

# Called when the node enters the scene tree for the first time.
func _ready():
	set_process_unhandled_key_input(false)
	set_action_name()
	set_hot_key()
	load_keybinds()
	
func load_keybinds():
	rebind_action_key(SettingData.get_keybind(action_name))


# Quan es trobi un nom d'entrada no coincident, es mostrarà com a no assignat
# 当遇见不匹配的输入名称时会显示为未分配
func set_action_name() -> void:
	label.text = "Unassigned"
	# Anomena el text de visualització del mapa d'entrada
	# 为输入映射的显示文本命名
	match action_name:
		"move_left":
			label.text = "Move Left"
		"move_back":
			label.text = "Move Backward"
		"jump":
			label.text = "Jump"
		"move_forward":
			label.text = "Move Forward"
		"move_right":
			label.text = "Move Right"
		"Run":
			label.text = "Run"

func set_hot_key():
	var action_events = InputMap.action_get_events(action_name)
	var action_event = action_events[0]
	var action_keycode = OS.get_keycode_string(action_event.physical_keycode)
	# 将按钮的文本改为输入映射的按键
	button.text = "%s" % action_keycode
	

func _on_button_toggled(toggled_on):
	if toggled_on:
		button.text = "Clic en cualquier botón..."
		set_process_unhandled_key_input(toggled_on)
		for i in get_tree().get_nodes_in_group("hotkey"):
			if i.action_name != self.action_name:
				i.button.toggle_mode = false
				i.set_process_unhandled_key_input(false)
	else:
		for i in get_tree().get_nodes_in_group("hotkey"):
			if i.action_name != self.action_name:
				i.button.toggle_mode = true
				i.set_process_unhandled_key_input(false)
		set_hot_key()

func _unhandled_key_input(event):
	rebind_action_key(event)
	button.button_pressed = false

# volver a vincular clave de acción
func rebind_action_key(event):
	InputMap.action_erase_events(action_name)
	InputMap.action_add_event(action_name, event)
	# 绑定调用
	SettingData.set_keybind(action_name, event)
	
	set_process_unhandled_key_input(false)
	set_hot_key()
	set_action_name()
