extends CharacterBody3D

var player = null
var state_machine
var health = 4

signal enemy_hit

const speed = 5.0
const attack_range = 3.5

# 用来导入人物路径
@export var player_path := "/root/World/Protagonist-FishMan"
# 用来获取玩家位置
@onready var nav_agent = $NavigationAgent3D
@onready var anim_tree = $AnimationTree

# Called when the node enters the scene tree for the first time.
func _ready():
	player = get_node(player_path)
	state_machine = anim_tree.get("parameters/playback")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# 初始速度为0
	velocity = Vector3.ZERO
	
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

	
func _hit_finished():
	# 判断角色是否在攻击范围内并且是否获得被击中反馈 攻击范围+1
	if global_position.distance_to(player.global_position) < attack_range + 1.0:
		var dir = global_position.direction_to(player.global_position)
		player.hit(dir)

func _on_area_3d_body_part_hit(dam):
	health -= dam
	emit_signal("enemy_hit")
	if health <= 0:
		delete_collision_nodes(self)
		anim_tree.set("parameters/conditions/die", true)
		await get_tree().create_timer(4.0).timeout
		queue_free()

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
