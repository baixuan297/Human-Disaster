extends Node3D
class_name World

@onready var crosshair = $effects/crosshair
@onready var crosshairhit = $effects/crosshairhit
@onready var FPS = $UI/FPS
@onready var interactray = $"Protagonist-FishMan/firstperson/nek/head/eyes/Camera3D/Interactable"
@onready var spawns = $stage/spawns 
@onready var navigation_region = $stage/NavigationRegion3D
@onready var player: CharacterBody3D = $"Protagonist-FishMan"
@onready var _1: Marker3D = $"SpawnLocation/1"

# falling on void
var death_y: float = -20.0
var falling: bool = true
var timer: float = 0.0
# Players Health
#@onready var label: Label = $UI/Label
#@onready var progress_bar: ProgressBar = $UI/ProgressBar
#const max_health = 100
#var health = max_health

var instance
var zombie = preload("res://Scene/npc/enemy/zombie.tscn")
var alien = preload("res://Scene/npc/enemy/alien.tscn")
var terrain = preload("res://Scene/map/terrain.tscn")

## pausa
#signal toggle_game_paused(is_paused)
#var game_paused = false:
	#get:
		#return game_paused
	#set(value):
		#game_paused = value
		#get_tree().paused = game_paused
		#emit_signal("toggle_game_paused", game_paused)

# Called when the node enters the scene tree for the first time.
func _ready():
	#player.connect("player_hit", damage)
	#player.player_hit.connect(damage)
	player.player_died.connect(_on_player_died)
	

func _input(event):
	## pausa menu
	#if Input.is_action_just_pressed("ui_cancel"):
		#game_paused = !game_paused
		#
	if Input.is_action_just_pressed("interactable"):
		var collider = interactray.get_collider()
		if collider is Interactable:
			if collider.is_in_group("terrain"):
				get_tree().change_scene_to_file("res://Scene/map/terrain.tscn")


func _process(delta):
	FPS.text = "FPS: %s\n" % str(Engine.get_frames_per_second())
	if player.global_transform.origin.y < death_y:
		if not falling:
			falling = true
			timer = 0.0
		else:
			timer += delta
			if timer >= 3.0:
				_on_player_died()
	else:
		# 如果角色不在虚空，重置状态
		falling = false
		timer = 0.0
		
# 生成小怪兽
func _get_random_child(parent_node):
	var random_id = randi() % parent_node.get_child_count()
	return parent_node.get_child(random_id)
"""
# 生成僵尸
func _on_zombiespawn_timeout():
	var spawn_point = _get_random_child(spawns).global_position
	instance = zombie.instantiate()
	instance.position = spawn_point
	instance.visible = true
	instance.enemy_hit.connect(_on_enemy_hit)
	navigation_region.add_child(instance)
"""
func _on_alienspawn_timeout():
	var spawn_point = _get_random_child(spawns).global_position
	instance = alien.instantiate()
	instance.position = spawn_point
	instance.visible = true
	instance.enemy_hit.connect(_on_enemy_hit)
	navigation_region.add_child(instance)

func _on_enemy_hit():
	# 击中反馈
	crosshairhit.visible = true
	await get_tree().create_timer(0.1).timeout
	crosshairhit.visible = false
	
func _on_player_died():
	# 删除敌人
	for child in navigation_region.get_children():
		if child.is_in_group("enemy"):
			child.queue_free()
		
	#传送玩家到目标位置
	player.global_position = _1.global_position
