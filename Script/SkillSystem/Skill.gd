## 管理单个技能
# ** 以后可能做个多技能搭配
# 用来实现技能的释放逻辑
class_name Skill
extends Node

## 信号
signal skill_used(skill: Skill)
signal skill_level_up(new_level: int)
signal cooldown_finished

## 技能资源
@export var skill_resource: SkillResource

## 运行时属性
var current_level: int = 1
var is_on_cooldown: bool = false
var cooldown_remaining: float = 0.0

## 技能所有者
var owner_node: Node3D

func _ready():
	if skill_resource == null:
		push_error("技能没有设置 skill_resource!")
		return

func _process(delta):
	# 更新冷却时间
	if is_on_cooldown:
		cooldown_remaining -= delta
		if cooldown_remaining <= 0:
			is_on_cooldown = false
			cooldown_remaining = 0.0
			cooldown_finished.emit()

## 使用技能
func use(target_position: Vector3 = Vector3.ZERO, target_node: Node3D = null) -> bool:
	if not can_use():
		return false
	
	# 执行技能效果
	_execute_skill(target_position, target_node)
	
	# 开始冷却
	start_cooldown()
	
	# 发出信号
	skill_used.emit(self)
	
	return true

## 检查是否可以使用
func can_use() -> bool:
	return not is_on_cooldown

## 开始冷却
func start_cooldown():
	is_on_cooldown = true
	cooldown_remaining = get_cooldown()

## 技能升级
func level_up() -> bool:
	if current_level >= skill_resource.max_level:
		return false
	
	current_level += 1
	skill_level_up.emit(current_level)
	return true

## 设置技能等级
func set_level(level: int):
	current_level = clamp(level, 1, skill_resource.max_level)

## 执行技能效果
func _execute_skill(target_position: Vector3, target_node: Node3D):
	match skill_resource.skill_type:
		SkillResource.SkillType.INSTANT:
			_execute_instant_skill(target_position, target_node)
		SkillResource.SkillType.PROJECTILE:
			_execute_projectile_skill(target_position)
		SkillResource.SkillType.AOE:
			_execute_aoe_skill(target_position)
		SkillResource.SkillType.DOT:
			_execute_dot_skill(target_node)
		SkillResource.SkillType.BUFF:
			_execute_buff_skill(target_node)
	
	# 播放特效和音效
	_play_effects()

## 瞬发技能
func _execute_instant_skill(target_position: Vector3, target_node: Node3D):
	if target_node and target_node.has_method("take_damage"):
		var damage = get_damage()
		target_node.take_damage(damage)

## 投射物技能
func _execute_projectile_skill(target_position: Vector3):
	if skill_resource.cast_effect and owner_node:
		var projectile: Node3D = skill_resource.cast_effect.instantiate()
		owner_node.get_parent().add_child(projectile)
		var hand_node: Marker3D = owner_node.get_node("Hand_node")
		projectile.setup(skill_resource)  # **
		projectile.global_position = hand_node.global_position
		
		
				
		# 设置投射物属性（假设投射物有这些方法）
		if projectile.has_method("set_damage"):
			projectile.set_damage(get_damage())
		if projectile.has_method("set_target"):
			projectile.set_target(target_position)

## 范围伤害技能
func _execute_aoe_skill(target_position: Vector3):
	# 在目标位置创建伤害区域
	var space_state = owner_node.get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = get_range()
	query.shape = sphere_shape
	query.transform = Transform3D(Basis(), target_position)
	
	var results = space_state.intersect_shape(query)
	for result in results:
		var collider = result["collider"]
		if collider.has_method("take_damage"):
			collider.take_damage(get_damage())

## 持续伤害技能
func _execute_dot_skill(target_node: Node3D):
	if target_node and target_node.has_method("apply_dot"):
		target_node.apply_dot(get_damage(), get_duration())

## 增益技能
func _execute_buff_skill(target_node: Node3D):
	if target_node and target_node.has_method("apply_buff"):
		target_node.apply_buff(get_attack_power(), get_duration())

## 播放特效
func _play_effects():
	# 播放施法特效
	if skill_resource.cast_effect and owner_node:
		var effect = skill_resource.cast_effect.instantiate()
		owner_node.add_child(effect)
	
	# 播放音效
	if skill_resource.cast_sound and owner_node:
		var audio_player = AudioStreamPlayer3D.new()
		audio_player.stream = skill_resource.cast_sound
		owner_node.add_child(audio_player)
		audio_player.play()
		audio_player.finished.connect(audio_player.queue_free)

## 获取当前技能属性
func get_damage() -> float:
	return skill_resource.get_damage(current_level)

func get_attack_power() -> float:
	return skill_resource.get_attack_power(current_level)

func get_cooldown() -> float:
	return skill_resource.get_cooldown(current_level)

func get_range() -> float:
	return skill_resource.get_range(current_level)

func get_duration() -> float:
	return skill_resource.get_duration(current_level)

## 获取技能信息
func get_info() -> Dictionary:
	var info = skill_resource.get_skill_info(current_level)
	info["cooldown_remaining"] = cooldown_remaining
	info["is_on_cooldown"] = is_on_cooldown
	return info
