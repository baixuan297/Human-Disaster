extends Node3D
## 场景伤害：毒池 hazard。必须注入 Hazard 资源，统一走 Stats.take_damage → health_changed → UI 更新。

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var area_3d: Area3D = $Area3D

## 必填：注入 Hazard 资源（伤害、间隔、类型由此配置）
@export var hazard_data: Hazard = null
var damage_timer: Timer
var bodies_in_pool: Array = []

func _ready() -> void:
	animation_player.play("Scene")
	if hazard_data == null:
		push_warning("[poison_pool] 未注入 hazard_data，场景伤害将不生效")
		return
	# 检测站在毒池内的角色刚体（Character 层）
	if area_3d:
		area_3d.monitoring = true
		area_3d.collision_mask = CollisionLayers.LAYER_CHARACTER
	
	damage_timer = Timer.new()
	damage_timer.wait_time = hazard_data.tick_interval
	damage_timer.timeout.connect(_apply_damage)
	add_child(damage_timer)

func _on_area_3d_body_entered(body: Node3D) -> void:
	if hazard_data == null:
		return
	if _can_damage(body):
		bodies_in_pool.append(body)
	if bodies_in_pool.size() == 1:
		damage_timer.start()


func _on_area_3d_body_exited(body: Node3D) -> void:
	if body in bodies_in_pool:
		bodies_in_pool.erase(body)
		if bodies_in_pool.is_empty() and damage_timer != null:
			damage_timer.stop()


func _can_damage(body: Node3D) -> bool:
	return body.has_method("apply_attack_data") or body.has_method("take_damage")


func _apply_damage() -> void:
	if hazard_data == null:
		return
	var attack := hazard_data.create_attack_data(self)
	for body in bodies_in_pool:
		if body.has_method("apply_attack_data"):
			body.apply_attack_data(attack)
		elif body.has_method("take_damage"):
			body.take_damage(hazard_data.damage)
