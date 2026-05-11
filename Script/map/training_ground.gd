extends Node3D

@onready var _bot_spawn: Node = $traningBotSpawn
@onready var _teleport: Node3D = $Teleport
@onready var _teleport_area: Area3D = $Teleport/TeleportArea
@onready var _teleport_shape: CollisionShape3D = $Teleport/TeleportArea/CollisionShape3D

var _remaining_bots: int = 0
var _teleport_unlocked: bool = false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_lock_teleport()
	_bind_training_bots()


func _on_teleport_area_body_entered(body: Node3D) -> void:
	if not _teleport_unlocked:
		return
	if not (body is CharacterBody3D):
		return
	SceneManager.change_scene("game")


func _bind_training_bots() -> void:
	_remaining_bots = 0
	if not is_instance_valid(_bot_spawn):
		_unlock_teleport()
		return

	var children := _bot_spawn.get_children()
	for c in children:
		if c is Node:
			_remaining_bots += 1
			var n := c as Node
			if not n.tree_exited.is_connected(_on_training_bot_removed):
				n.tree_exited.connect(_on_training_bot_removed)

	# 兜底：没有任何 bot 时立即开放传送
	if _remaining_bots <= 0:
		_unlock_teleport()


func _on_training_bot_removed() -> void:
	if _remaining_bots <= 0:
		return
	_remaining_bots -= 1
	if _remaining_bots <= 0:
		_unlock_teleport()


func _lock_teleport() -> void:
	_teleport_unlocked = false
	if is_instance_valid(_teleport):
		_teleport.visible = false
	if is_instance_valid(_teleport_area):
		_teleport_area.monitoring = false
		_teleport_area.monitorable = false
	if is_instance_valid(_teleport_shape):
		_teleport_shape.disabled = true


func _unlock_teleport() -> void:
	_teleport_unlocked = true
	if is_instance_valid(_teleport):
		_teleport.visible = true
	if is_instance_valid(_teleport_area):
		_teleport_area.monitoring = true
		_teleport_area.monitorable = true
	if is_instance_valid(_teleport_shape):
		_teleport_shape.disabled = false
