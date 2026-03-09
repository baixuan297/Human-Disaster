extends BaseEnemy

@onready var player: CharacterBody3D = \
	get_tree().get_first_node_in_group("Player")
var state_machine

const speed = 5.0
const attack_range = 3.5

# 用来获取玩家位置
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var anim_tree: AnimationTree = $AnimationTree

# Called when the node enters the scene tree for the first time.
func _ready():
	# 执行父类的 ready 逻辑（连接信号等）
	super._ready()
	state_machine = anim_tree.get("parameters/playback")

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
		#var dir = global_position.direction_to(player.global_position)
		player.take_damage()

func _on_died():
	print("💀死亡！")
	delete_collision_nodes(self)
	
	stats_node.queue_free()
	
	anim_tree.set("parameters/conditions/die", true)
	await anim_tree.animation_finished
	self.queue_free()
