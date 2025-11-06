extends Control

@onready var audio = $"Dialog_box/1/AudioStreamPlayer"

func _on__pressed():
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if audio.is_playing():
		audio.playing = false
	
