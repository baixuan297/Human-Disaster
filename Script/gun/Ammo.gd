extends CanvasLayer
#extends Control

@onready var CurrentAmmo = $HBoxContainer/CurrentAmmo
@onready var Reserve = $HBoxContainer/reserve

func _ready():
	$"../Protagonist-FishMan".connect("Update_Ammo" ,_on_protagonist_fish_man_update_ammo)

func _on_protagonist_fish_man_update_ammo(Ammo):
	CurrentAmmo.set_text(str(Ammo[0]))
	Reserve.set_text(str(Ammo[1]))
