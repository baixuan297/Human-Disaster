extends Node3D
class_name World

## 主关卡根节点：玩家出生、虚空坠落、自动存档间隔、跨场景导航与敌人实例化入口。
## 与 CharacterDataManager：依赖已登录角色的 API 存档；具体加载逻辑见 CharacterDataManager.restore_to_player。

@onready var crosshair = $effects/crosshair
@onready var crosshairhit = $effects/crosshairhit
@onready var FPS = $UI/FPS
@onready var interactray = $"FishMan/firstperson/nek/head/CameraRigFP/FPCamera/Interactable"
@onready var spawns = $stage/spawns 
@onready var navigation_region = $stage/NavigationRegion3D
@onready var player: CharacterBody3D = $"FishMan"
@onready var _1: Marker3D = $"SpawnLocation/1"

@export_group("敌人生成")
@export var alien_spawn_center_path: NodePath = NodePath("stage/spawns/spawns4")
@export var alien_spawn_radius: float = 10.0
@export var alien_spawn_min_separation: float = 4.0
@export var alien_spawn_max_attempts: int = 16

# falling on void
var death_y: float = -20.0
var falling: bool = true
var timer: float = 0.0
const AUTO_SAVE_INTERVAL: float = 120.0
var _auto_save_timer: float = 0.0
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
	player.player_died.connect(_on_player_died)
	

func _input(_event):
	## pausa menu
	#if Input.is_action_just_pressed("ui_cancel"):
		#game_paused = !game_paused
		#
	if Input.is_action_just_pressed("interactable"):
		var collider = interactray.get_collider()
		if collider is Interactable:
			if collider.is_in_group("terrain"):
				CharacterDataManager.save_to_api(func(_ok, _d):
					CharacterDataManager.snapshot_before_scene_change()
					get_tree().change_scene_to_file("res://Scene/map/terrain.tscn")
				)


func _process(delta):
	FPS.text = "FPS: %s\n" % str(Engine.get_frames_per_second())
	_auto_save_timer += delta
	if _auto_save_timer >= AUTO_SAVE_INTERVAL:
		_auto_save_timer = 0.0
		CharacterDataManager.save_to_api()
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


func _rand_point_in_circle(center: Vector3, radius: float) -> Vector3:
	var a := randf_range(0.0, TAU)
	# 均匀面积采样：r 用 sqrt
	var r := sqrt(randf()) * radius
	return center + Vector3(cos(a) * r, 0.0, sin(a) * r)


func _is_spawn_point_free(p: Vector3, min_sep: float) -> bool:
	var min_sep_sq := min_sep * min_sep
	for child in navigation_region.get_children():
		if child is Node3D and child.is_in_group("enemy"):
			var d := (child as Node3D).global_position - p
			d.y = 0.0
			if d.length_squared() <= min_sep_sq:
				return false
	return true


func _pick_alien_spawn_point() -> Vector3:
	var center_node := get_node_or_null(alien_spawn_center_path) as Node3D
	var center = center_node.global_position if center_node else _get_random_child(spawns).global_position
	for _i in range(max(alien_spawn_max_attempts, 1)):
		var p := _rand_point_in_circle(center, maxf(alien_spawn_radius, 0.0))
		if _is_spawn_point_free(p, maxf(alien_spawn_min_separation, 0.0)):
			return p
	# 兜底：直接用中心点（可能会重叠，但保证能生成）
	return center
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
	var spawn_point = _pick_alien_spawn_point()
	instance = alien.instantiate()
	instance.visible = true
	navigation_region.add_child(instance)
	# 使用世界坐标：若父节点 NavigationRegion3D 有平移/旋转/缩放，必须在入树后设置 global_transform，避免继承缩放导致模型异常
	if instance is Node3D:
		(instance as Node3D).global_position = spawn_point
	# 生成点可能在空中：让敌人立即复用自身贴地逻辑再贴一次
	if instance.has_method("resnap_to_floor"):
		instance.call_deferred("resnap_to_floor")

#func _on_enemy_hit():
	## 击中反馈
	#crosshairhit.visible = true
	#await get_tree().create_timer(0.1).timeout
	#crosshairhit.visible = false
	
func _on_player_died():
	# 删除敌人
	for child in navigation_region.get_children():
		if child.is_in_group("enemy"):
			child.queue_free()
		
	#传送玩家到目标位置
	player.global_position = _1.global_position
