extends CharacterBody3D

@onready var animation = $AnimationPlayer
@onready var option_dialog = $CanvasLayer/VBoxContainer
@onready var character_button = $CanvasLayer/Character_name
@onready var dialog_robot = $CanvasLayer/Dialog_robot
@onready var dialog = $CanvasLayer/VBoxContainer/dialog
@onready var adios = $CanvasLayer/VBoxContainer/adios
@onready var audio = $"CanvasLayer/Dialog_robot/Dialog_box/1/AudioStreamPlayer"
@onready var animation_text = $"CanvasLayer/Dialog_robot/Dialog_box/1/Color/MarginContainer/text/AnimationPlayer"
@export var character_name : String

func _ready():
	character_button.text = character_name
	idle_ani()
	

func _unhandled_input(event):
	if event is InputEventMouseButton:
		dialog.grab_focus()
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			dialog.grab_focus()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			adios.grab_focus()
	if event is InputEventKey:
		if event.is_action_pressed("interactable") and adios.has_focus():
			option_dialog.visible = false
		if event.is_action_pressed("interactable") and dialog.has_focus():
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			dialog_robot.visible = true
			option_dialog.visible = false
			animation_text.play("TextDisplay")
			audio.play()
		
func idle_ani():
	while true:
		animation.set_autoplay("Idle1")
		await get_tree().create_timer(30.0).timeout
		#animation.set_autoplay("")
		animation.play("Idle2")

func _on_area_3d_area_entered(area):
	character_button.visible = true

func _on_character_name_pressed():
	option_dialog.visible = true
	character_button.visible = false

func _on_area_3d_area_exited(area):
	character_button.visible = false
