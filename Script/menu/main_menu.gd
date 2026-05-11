extends CanvasLayer

@export var world : World

@onready var sound_effect = $Control/Button_sound
@onready var inimusic = $Control/music/Inimusic
@onready var jugar = $Control/menu/Jugar
@onready var ajuste = $Control/menu/Ajustes
@onready var ayuda = $Control/menu/Ayuda
@onready var credito = $Control/menu/Creditos
@onready var salir = $Control/menu/Salir
@onready var musicicon = $Control/music/musicicon
@onready var main = $Control

@onready var creditos_menu: Control
@onready var option_menu: Control

var loading_screen = preload("res://Scene/menu/loading.tscn")
var option_menu_scene = preload("res://Scene/menu/option_menu.tscn")
var creditos_menu_scene = preload("res://Scene/menu/creditos_menu.tscn")


func _ready() -> void:
	if UserManager.current_character_id.is_empty():
		return
	CharacterDataManager.fetch_stats_snapshot_for_menu(_on_main_menu_tutorial_state_loaded)


func _on_main_menu_tutorial_state_loaded(ok: bool) -> void:
	if not ok:
		return
	if CharacterDataManager.has_tutorial_completed():
		return
	_apply_main_menu_tutorial_lock()


func _apply_main_menu_tutorial_lock() -> void:
	var tip := "完成新手教程后开放"
	ajuste.disabled = true
	credito.disabled = true
	ayuda.disabled = true
	ajuste.tooltip_text = tip
	credito.tooltip_text = tip
	ayuda.tooltip_text = tip


func on_back_option_menu():
	main.visible = true
	option_menu.queue_free()
	
func on_back_creditos_menu():
	main.visible = true
	creditos_menu.queue_free()

func _on_jugar_mouse_entered():
	sound_effect.play(0.0)

func _on_ajustes_mouse_entered():
	sound_effect.play(0.0)

func _on_creditos_mouse_entered():
	sound_effect.play(0.0)
	
func _on_ayuda_mouse_entered():
	sound_effect.play(0.0)
	
func _on_salir_mouse_entered():
	sound_effect.play(0.0)
	
func _on_jugar_pressed():
	SceneManager.change_scene_to_file("res://Scene/menu/chosegamemode.tscn")

func _on_ajustes_pressed():
	main.visible = false
	option_menu = option_menu_scene.instantiate()
	option_menu.exit_option_menu.connect(on_back_option_menu)
	add_child(option_menu)

func _on_creditos_pressed():
	main.visible = false
	creditos_menu = creditos_menu_scene.instantiate()
	creditos_menu.exit_creditos_menu.connect(on_back_creditos_menu)
	add_child(creditos_menu)

func _on_ayuda_pressed():
	sound_effect.play(0.0)
	OS.shell_open("https://desahuman.wuaze.com/?i=1")

func _on_salir_pressed():
	sound_effect.play(0.0)
	CharacterDataManager.save_on_exit_then_quit()
	
func _on_music_pressed():
	if inimusic.is_playing():
		inimusic.playing = false
	else:
		inimusic.playing = true
