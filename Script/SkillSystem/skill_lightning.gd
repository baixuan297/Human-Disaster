extends Node3D

## 技能配置
var skill_resource: SkillResource
var skill_level: int = 1
var caster: Node = null

var duration: float = 3.0
var tick_interval: float = 0.5  # 每 0.5 秒造成一次伤害
var timer: float = 0.0
var tick_timer: float = 0.0

@onready var aoe_shape: SphereShape3D = SphereShape3D.new()

func _ready():
	# 设置碰撞球体的半径（从技能资源获取）
	aoe_shape.radius = skill_resource.skill_range if skill_resource else 3.0

func setup(data: SkillResource, level: int, _caster: Node, _duration: float) -> void:
	skill_resource = data
	skill_level = level
	caster = _caster
	duration = _duration
	set_process(true)

func _process(delta: float):
	timer += delta
	tick_timer += delta
	
	# 周期性触发伤害
	if tick_timer >= tick_interval:
		_apply_aoe_damage()
		tick_timer = 0.0
	
	# 持续时间结束
	if timer >= duration:
		queue_free()

func _apply_aoe_damage():
	# 获取 3D 物理空间状态
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	
	query.shape = aoe_shape
	query.transform = global_transform # 在当前闪电位置进行检测
	# 建议设置 collision_mask 提高性能，只检测敌人所在的层
	query.collision_mask = 2 

	var results = space_state.intersect_shape(query)
	
	for result in results:
		var collider = result["collider"]
		
		# 兼容你之前的 Area3D 检测逻辑 (enemy_hit)
		if collider.has_method("enemy_hit"):
			var attack = AttackData.create_skill_attack(skill_resource, skill_level, caster)
			# 如果是持续伤害，可以在这里对 attack.base_damage 做缩减
			collider.enemy_hit(attack)
			
		# 或者兼容直接在 CharacterBody3D 上的 take_damage
		elif collider.has_method("take_damage"):
			collider.take_damage(skill_resource.base_damage)
