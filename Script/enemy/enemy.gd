extends CharacterBody3D

@onready var player: CharacterBody3D = \
	get_tree().get_first_node_in_group("Player")
var state_machine

## 当在世界中创建敌人实体，并且敌人被击中（子弹进入area中并且进行组的判定后）
## 那么调用敌人的身体部分的脚本（Area）进行伤害判定
signal enemy_hit

const speed = 5.0
const attack_range = 3.5

# 挂载属性资源脚本
@export var stats: Stats
# 是否开始导航
#@export var nav_status: bool = false

# 用来获取玩家位置
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var health_bar = $Stats/SubViewport/health_bar
@onready var stats_node: Node3D = $Stats

# Called when the node enters the scene tree for the first time.
func _ready():
	stats.health_changed.connect(_on_health_changed)
	stats.died.connect(_on_died)
	
	state_machine = anim_tree.get("parameters/playback")
	
	health_bar.value = (stats.current_health / stats.current_max_health) * 100.0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# 初始速度为0
	velocity = Vector3.ZERO
	
	# ** 
	# 加入距离测算来决定是否启动
	match state_machine.get_current_node():
		"run":
			# 导航
			# 将玩家的全局位置提供给导航
			nav_agent.set_target_position(player.global_transform.origin)
			# 获取僵尸要到下一个位置
			var next_nav_point = nav_agent.get_next_path_position()
			# 敌人找到我们的位置
			velocity = (next_nav_point - global_transform.origin).normalized() * speed
			rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), delta * 10.0)
		"attack":
			look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
	
	# 判断
	anim_tree.set("parameters/conditions/attack", _target_in_range())
	anim_tree.set("parameters/conditions/run", !_target_in_range())
	
	move_and_slide()

func _target_in_range():
	# 判断是否在攻击范围内
	return global_position.distance_to(player.global_position) < attack_range
	
func _get_player_range() -> bool:
	return global_position.distance_to(player.global_position) >= 10

	
func _hit_finished():
	# 判断角色是否在攻击范围内并且是否获得被击中反馈 攻击范围+1
	if global_position.distance_to(player.global_position) < attack_range + 1.0:
		var dir = global_position.direction_to(player.global_position)
		player.take_damage(dir)
#
#func _on_area_3d_body_part_hit(dam):
	#health -= dam
	#emit_signal("enemy_hit")
	#if health <= 0:
		#delete_collision_nodes(self)
		#anim_tree.set("parameters/conditions/die", true)
		#await get_tree().create_timer(4.0).timeout
		#queue_free()

func _on_area_3d_body_part_hit(attack_data: AttackData):
	emit_signal("enemy_hit")
	stats.take_damage(attack_data)

func _on_health_changed(cur_health: float, max_health: float) -> void:
	# 你可以在这里更新血条等 UI
	health_bar.value = (stats.current_health / stats.current_max_health) * 100.0
	print("敌人当前血量: %.1f / %.1f" % [cur_health, max_health])

func _on_died():
	print("💀死亡！")
	delete_collision_nodes(self)
	
	stats_node.queue_free()
	
	anim_tree.set("parameters/conditions/die", true)
	await anim_tree.animation_finished
	self.queue_free()
	

func delete_collision_nodes(node):
	# 收集节点
	var delete = []

	for child in node.get_children():
		if child.name == "CollisionShape3D":
			delete.append(child)
		# 递归检查所有层级的子节点
		delete_collision_nodes(child)

	# 删除收集到的节点
	for n in delete:
		n.queue_free()
