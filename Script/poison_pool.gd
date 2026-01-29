extends Node3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer

# 间隔时间
var tick_interval: float = 0.5
var damage_timer: Timer
# 记录池中的角色
var bodies_in_pool: Array = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animation_player.play("Scene")
	
	damage_timer = Timer.new()
	damage_timer.wait_time = tick_interval
	damage_timer.timeout.connect(_apply_damage)
	add_child(damage_timer)

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.has_method("take_damage"):
		bodies_in_pool.append(body)
		
	if bodies_in_pool.size() == 1:
		damage_timer.start()


func _on_area_3d_body_exited(body: Node3D) -> void:
	# 角色离开池子
	if body in bodies_in_pool:
		bodies_in_pool.erase(body)
		
		# 如果没有角色在池中，停止计时器
		if bodies_in_pool.is_empty():
			damage_timer.stop()
	
	
func _apply_damage():
	# 对池中所有角色造成伤害
	for body in bodies_in_pool:
		if body.has_method("take_damage"):
			body.take_damage()
