class_name OptionInfo
extends Control

@onready var tabcontainer = $TabContainer

signal Exit_Options_Menu

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	option_menu_input()
	
func change_tab(tab : int):
	tabcontainer.set_current_tab(tab)

func option_menu_input():
	if Input.is_action_just_pressed("move_right") or Input.is_action_just_pressed("ui_right"):
		if tabcontainer.current_tab >= tabcontainer.get_tab_count() - 1:
			change_tab(0)
			return
		
		var next_tab = tabcontainer.current_tab + 1
		change_tab(next_tab)
		
	if Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("ui_left"):
		if tabcontainer.current_tab == 0:
			change_tab(tabcontainer.get_tab_count() - 1)
			
		var previous_tab = tabcontainer.current_tab - 1
		change_tab(previous_tab)
	
	if Input.is_action_just_pressed("ui_cancel"):
		Exit_Options_Menu.emit()
