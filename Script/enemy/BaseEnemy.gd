extends CharacterBody3D
## 给其他敌人能够集成的类
class_name BaseEnemy

## 当在世界中创建敌人实体，并且敌人被击中（子弹进入area中并且进行组的判定后）
## 那么调用敌人的身体部分的脚本（Area）进行伤害判定
signal enemy_hit

# 挂载属性资源脚本
@export var stats: Stats

@onready var health_bar = $Stats/SubViewport/health_bar
@onready var stats_node: Node3D = $Stats
var hurt_boxes: Area3D = get_node_or_null("Hurtboxes")

# Called when the node enters the scene tree for the first time.
func _ready():
	stats.health_changed.connect(_on_health_changed)
	stats.died.connect(_on_died)
	if health_bar:
		health_bar.value = (stats.current_health / stats.current_max_health) * 100.0
	
	if hurt_boxes:
		hurt_boxes.body_part_hit.connect(_on_area_3d_body_part_hit)
	
func _on_area_3d_body_part_hit(attack_data: AttackData):
	emit_signal("enemy_hit")
	stats.take_damage(attack_data)

func _on_health_changed(cur_health: float, max_health: float) -> void:
	# 你可以在这里更新血条等 UI
	if health_bar:
		health_bar.value = (stats.current_health / stats.current_max_health) * 100.0
	print("敌人当前血量: %.1f / %.1f" % [cur_health, max_health])

func _on_died():
	print("💀死亡！")
	delete_collision_nodes(self)
	if stats_node: stats_node.queue_free()
	self.queue_free()
	
		
func delete_collision_nodes(node):
	for child in node.get_children():
		if child is CollisionShape3D:
			child.queue_free()
		delete_collision_nodes(child)
