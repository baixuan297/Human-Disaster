### 管理单个技能
## ** 以后可能做个多技能搭配
## 用来实现技能的释放逻辑
#class_name Skill
#extends Node
#
### 信号
#signal skill_used(skill: Skill)
#signal skill_level_up(new_level: int)
#signal cooldown_finished
#
### 技能资源
#@export var skill_resource: SkillResource
#
### 运行时属性
#var current_level: int = 1
#var is_on_cooldown: bool = false
#var cooldown_remaining: float = 0.0
#
### 技能所有者
#var owner_node: Node3D
#
#func _ready():
	#if skill_resource == null:
		#push_error("技能没有设置 skill_resource!")
		#return
#
#func _process(delta):
	## 更新冷却时间
	#if is_on_cooldown:
		#cooldown_remaining -= delta
		#if cooldown_remaining <= 0:
			#is_on_cooldown = false
			#cooldown_remaining = 0.0
			#cooldown_finished.emit()
#
### 使用技能
#func use(target_position: Vector3 = Vector3.ZERO, target_node: Node3D = null) -> bool:
	#if not can_use():
		#return false
	#
	## 执行技能效果
	#_execute_skill(target_position, target_node)
	#
	## 开始冷却
	#start_cooldown()
	#
	## 发出信号
	#skill_used.emit(self)
	#
	#return true
#
### 检查是否可以使用
#func can_use() -> bool:
	#return not is_on_cooldown
#
### 开始冷却
#func start_cooldown():
	#is_on_cooldown = true
	#cooldown_remaining = get_cooldown()
#
### 技能升级
#func level_up() -> bool:
	#if current_level >= skill_resource.max_level:
		#return false
	#
	#current_level += 1
	#skill_level_up.emit(current_level)
	#return true
#
### 设置技能等级
#func set_level(level: int):
	#current_level = clamp(level, 1, skill_resource.max_level)
#
### 执行技能效果
#func _execute_skill(target_position: Vector3, target_node: Node3D):
	#match skill_resource.skill_type:
		#SkillResource.SkillType.INSTANT:
			#_execute_instant_skill(target_position, target_node)
		#SkillResource.SkillType.PROJECTILE:
			#_execute_projectile_skill(target_position)
		#SkillResource.SkillType.AOE:
			#_execute_aoe_skill(target_position)
		#SkillResource.SkillType.DOT:
			#_execute_dot_skill(target_node)
		#SkillResource.SkillType.BUFF:
			#_execute_buff_skill(target_node)
	#
	## 播放特效和音效
	#_play_effects()
#
### 瞬发技能
#func _execute_instant_skill(target_position: Vector3, target_node: Node3D):
	#if target_node and target_node.has_method("take_damage"):
		#var damage = get_damage()
		#target_node.take_damage(damage)
#
### 投射物技能
#func _execute_projectile_skill(target_position: Vector3):
	#if skill_resource.cast_effect and owner_node:
		#var projectile: Node3D = skill_resource.cast_effect.instantiate()
		#owner_node.get_parent().add_child(projectile)
		#var hand_node: Marker3D = owner_node.get_node("Hand_node")
		#projectile.setup(skill_resource)  # **
		#projectile.global_position = hand_node.global_position
		#
		#
				#
		## 设置投射物属性（假设投射物有这些方法）
		#if projectile.has_method("set_damage"):
			#projectile.set_damage(get_damage())
		#if projectile.has_method("set_target"):
			#projectile.set_target(target_position)
#
### 范围伤害技能
#func _execute_aoe_skill(target_position: Vector3):
	## 在目标位置创建伤害区域
	#var space_state = owner_node.get_world_3d().direct_space_state
	#var query = PhysicsShapeQueryParameters3D.new()
	#var sphere_shape = SphereShape3D.new()
	#sphere_shape.radius = get_range()
	#query.shape = sphere_shape
	#query.transform = Transform3D(Basis(), target_position)
	#
	#var results = space_state.intersect_shape(query)
	#for result in results:
		#var collider = result["collider"]
		#if collider.has_method("take_damage"):
			#collider.take_damage(get_damage())
#
### 持续伤害技能
#func _execute_dot_skill(target_node: Node3D):
	#if target_node and target_node.has_method("apply_dot"):
		#target_node.apply_dot(get_damage(), get_duration())
#
### 增益技能
#func _execute_buff_skill(target_node: Node3D):
	#if target_node and target_node.has_method("apply_buff"):
		#target_node.apply_buff(get_attack_power(), get_duration())
#
### 播放特效
#func _play_effects():
	## 播放施法特效
	#if skill_resource.cast_effect and owner_node:
		#var effect = skill_resource.cast_effect.instantiate()
		#owner_node.add_child(effect)
	#
	## 播放音效
	#if skill_resource.cast_sound and owner_node:
		#var audio_player = AudioStreamPlayer3D.new()
		#audio_player.stream = skill_resource.cast_sound
		#owner_node.add_child(audio_player)
		#audio_player.play()
		#audio_player.finished.connect(audio_player.queue_free)
#
### 获取当前技能属性
#func get_damage() -> float:
	#return skill_resource.get_damage(current_level)
#
#func get_attack_power() -> float:
	#return skill_resource.get_attack_power(current_level)
#
#func get_cooldown() -> float:
	#return skill_resource.get_cooldown(current_level)
#
#func get_range() -> float:
	#return skill_resource.get_range(current_level)
#
#func get_duration() -> float:
	#return skill_resource.get_duration(current_level)
#
### 获取技能信息
#func get_info() -> Dictionary:
	#var info = skill_resource.get_skill_info(current_level)
	#info["cooldown_remaining"] = cooldown_remaining
	#info["is_on_cooldown"] = is_on_cooldown
	#return info

## 管理单个技能
class_name Skill
extends Node

## ════════════════════════════════════════════════════════════
## 信号
## ════════════════════════════════════════════════════════════
signal skill_used(skill: Skill)
signal skill_level_up(new_level: int)
signal cooldown_finished

## ════════════════════════════════════════════════════════════
## 核心属性
## ════════════════════════════════════════════════════════════
@export var skill_resource: SkillResource

var current_level: int = 1
var is_on_cooldown: bool = false
var cooldown_remaining: float = 0.0

var owner_node: Node3D  # 技能所有者（玩家/敌人）


## ════════════════════════════════════════════════════════════
## 生命周期
## ════════════════════════════════════════════════════════════

func _ready() -> void:
	if skill_resource == null:
		push_error("技能没有设置 skill_resource!")
		return

	# 调试
	print("🔧 技能初始化: %s | 冷却: %.1fs" % [skill_resource.skill_name, get_cooldown()])


func _process(delta: float) -> void:
	# 更新冷却时间
	if is_on_cooldown:
		cooldown_remaining -= delta
		if cooldown_remaining <= 0:
			is_on_cooldown = false
			cooldown_remaining = 0.0
			# 调试
			print("✅ %s 冷却结束！可以再次使用" % skill_resource.skill_name)
			cooldown_finished.emit()
			


## ════════════════════════════════════════════════════════════
## 核心方法
## ════════════════════════════════════════════════════════════

## 使用技能
func use(target_position: Vector3 = Vector3.ZERO, target_node: Node3D = null) -> bool:
	# 调试
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("🎯 尝试使用技能: %s" % skill_resource.skill_name)
	print("   当前冷却状态: %s" % ("冷却中" if is_on_cooldown else "可用"))
	print("   冷却剩余时间: %.2fs" % cooldown_remaining)
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
func start_cooldown() -> void:
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
func set_level(level: int) -> void:
	current_level = clamp(level, 1, skill_resource.max_level)


## ════════════════════════════════════════════════════════════
## 技能执行逻辑（核心修改）
## ════════════════════════════════════════════════════════════

func _execute_skill(target_position: Vector3, target_node: Node3D) -> void:
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
			#_execute_buff_skill(target_node)
			_execute_buff_skill(target_position)
	
	# 播放特效和音效
	_play_effects()


## ──────────────────────────────────────────────────────────
## 投射物技能（关键修改）
## ──────────────────────────────────────────────────────────
func _execute_projectile_skill(target_position: Vector3) -> void:
	if skill_resource.cast_effect == null or owner_node == null:
		push_warning("技能缺少 cast_effect 或 owner_node")
		return
	
	# 1. 实例化投射物
	var projectile: Node3D = skill_resource.cast_effect.instantiate()
	owner_node.get_parent().add_child(projectile)
	
	# 2. 设置发射位置
	var hand_node: Marker3D = owner_node.get_node_or_null("Hand_node")
	if hand_node:
		projectile.global_position = hand_node.global_position
	else:
		projectile.global_position = owner_node.global_position
	
	# 3. 【关键修改】传递完整数据：技能资源 + 等级 + 施法者
	if projectile.has_method("setup"):
		projectile.setup(skill_resource, current_level, owner_node)
	
	# 4. 设置目标位置
	if projectile.has_method("set_target"):
		projectile.set_target(target_position)
	
	# 【移除】不再在这里设置伤害，由投射物碰撞时动态计算
	# if projectile.has_method("set_damage"):
	#     projectile.set_damage(get_damage())


## ──────────────────────────────────────────────────────────
## 瞬发技能（参考修改）
## ──────────────────────────────────────────────────────────
func _execute_instant_skill(target_position: Vector3, target_node: Node3D) -> void:
	if target_node == null or not target_node.has_method("take_damage"):
		return
	
	# 创建攻击数据
	var attack := AttackData.create_skill_attack(skill_resource, current_level, owner_node)
	
	# 瞬发技能直接命中，无部位判定（或根据需求添加）
	attack.final_damage = attack.base_damage
	
	# 传递给目标（假设目标有统一的受击接口）
	if target_node.has_method("apply_attack_data"):
		target_node.apply_attack_data(attack)
	elif target_node.has_method("take_damage"):
		# 兼容旧接口
		target_node.take_damage(get_damage())


## 范围伤害技能
# TODO: 更新为能够给所有范围技能使用 并且更新范围指标 因为范围现在由雷电技能的area控制
		# 并不是由skill resource中的range
func _execute_aoe_skill(target_position: Vector3) -> void:
	if skill_resource.cast_effect == null:
		print("Not found AOE Skill: ", skill_resource.skill_name)
		return
	
	# --- 修正位置：确保在地面上 ---
	#var ground_pos = target_position
	#var space_state = owner_node.get_world_3d().direct_space_state
	#
	## 从敌人中心点向上偏移一点开始向下探测，防止敌人陷在地里探测不到
	#var ray_start = target_position + Vector3.UP * 2.0 
	#var ray_end = target_position + Vector3.DOWN * 5.0
	#
	#var ray_query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	## 建议设置射线只检测地形层（例如层 1），避免撞到敌人自己的碰撞盒
	## ray_query.collision_mask = 1 
	#
	#var ray_result = space_state.intersect_ray(ray_query)
	#
	#if ray_result:
		#ground_pos = ray_result.position # 修正为地面的确切坐标
	
	# 1. 实例化技能特效
	var AOE_skill_node: Node3D = skill_resource.cast_effect.instantiate()
	owner_node.get_parent().add_child(AOE_skill_node)
	
	# 2. 设置位置（在目标敌人的地面）
	var ground_pos := _get_ground_position(target_position)
	AOE_skill_node.global_position = ground_pos
	
	# 3. 初始化数据
	if AOE_skill_node.has_method("setup"):
		# 传递：技能资源, 等级, 施法者
		AOE_skill_node.setup(skill_resource, current_level, owner_node, 3.0)
		
	#var space_state = owner_node.get_world_3d().direct_space_state
	#var query = PhysicsShapeQueryParameters3D.new()
	#var sphere_shape = SphereShape3D.new()
	#sphere_shape.radius = get_range()
	#query.shape = sphere_shape
	#query.transform = Transform3D(Basis(), target_position)
	#
	#var results = space_state.intersect_shape(query)
	#for result in results:
		#var collider = result["collider"]
		#if collider.has_method("take_damage"):
			#collider.take_damage(get_damage())


## ──────────────────────────────────────────────────────────
## 持续伤害技能
## ──────────────────────────────────────────────────────────
func _execute_dot_skill(target_node: Node3D) -> void:
	if target_node and target_node.has_method("apply_dot"):
		target_node.apply_dot(get_damage(), get_duration())


## ──────────────────────────────────────────────────────────
## 增益技能
## ──────────────────────────────────────────────────────────
#func _execute_buff_skill(target_node: Node3D) -> void:
	#if target_node and target_node.has_method("apply_buff"):
		#target_node.apply_buff(get_attack_power(), get_duration())
func _execute_buff_skill(target_position: Vector3) -> void:
	# 检查技能资源
	#var is_aoe = skill_resource.is_aoe # 假设你在资源里定义了这个布尔值
	
	#if not is_aoe:
		## --- 单体/个体逻辑：直接作用于施法者自己 ---
		#if owner_node.has_method("apply_buff"):
			## 传递技能资源、等级和施法者本身
			#owner_node.apply_buff(skill_resource, current_level, owner_node)
	#else:
		# --- 范围逻辑：生成一个持续的 Buff 区域 ---
		if skill_resource.cast_effect == null:
			return
			
		var buff_area = skill_resource.cast_effect.instantiate()
		owner_node.get_parent().add_child(buff_area)
		
		# 同样使用射线探测确保生成在地面（复用之前的逻辑）
		buff_area.global_position = _get_ground_position(target_position)
		
		if buff_area.has_method("setup"):
			# 传递数据，持续时间由资源决定
			buff_area.setup(skill_resource, current_level, owner_node, skill_resource.base_duration)

## 辅助函数：获取地面位置
func _get_ground_position(pos: Vector3) -> Vector3:
	var space_state = owner_node.get_world_3d().direct_space_state
	var ray_query = PhysicsRayQueryParameters3D.create(pos + Vector3.UP, pos + Vector3.DOWN * 5.0)
	ray_query.collision_mask = 1
	var result = space_state.intersect_ray(ray_query)
	return result.position if result else pos

## ──────────────────────────────────────────────────────────
## 播放特效
## ──────────────────────────────────────────────────────────
func _play_effects() -> void:
	# 播放施法特效（注意：这里不应播放投射物特效）
	# cast_effect 已经在 _execute_projectile_skill 中使用
	
	# 播放音效
	if skill_resource.cast_sound and owner_node:
		var audio_player = AudioStreamPlayer3D.new()
		audio_player.stream = skill_resource.cast_sound
		owner_node.add_child(audio_player)
		audio_player.play()
		audio_player.finished.connect(audio_player.queue_free)


## ════════════════════════════════════════════════════════════
## 获取当前技能属性
## ════════════════════════════════════════════════════════════

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


## ════════════════════════════════════════════════════════════
## 获取技能信息
## ════════════════════════════════════════════════════════════

func get_info() -> Dictionary:
	var info = skill_resource.get_skill_info(current_level)
	info["cooldown_remaining"] = cooldown_remaining
	info["is_on_cooldown"] = is_on_cooldown
	return info
