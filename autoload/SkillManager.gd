## 技能管理器 - 管理角色的所有技能
#class_name SkillManager
extends Node

## 信号
signal skill_added(skill: Skill)
signal skill_removed(skill_name: String)
signal skill_used(skill: Skill)

## 技能存储
var skills: Dictionary = {}  # key: skill_name, value: Skill

## 技能栏配置
@export var max_skill_slots: int = 4
#var skill_bar: Array[Skill] = []  # 快捷栏的技能
var skill_bar: Array = []

## 角色引用
var character: Node3D

func _ready():
	# 初始化技能栏
	skill_bar.resize(max_skill_slots)

## 添加技能
func add_skill(skill_resource: SkillResource, initial_level: int = 1) -> Skill:
	if skills.has(skill_resource.skill_name):
		#push_warning("技能已存在: " + skill_resource.skill_name)
		return skills[skill_resource.skill_name]
	
	# 创建技能实例
	var skill = Skill.new()
	skill.skill_resource = skill_resource
	skill.current_level = initial_level
	skill.owner_node = character
	
	# 连接信号
	skill.skill_used.connect(_on_skill_used)
	
	# 添加到场景树和字典
	add_child(skill)
	skills[skill_resource.skill_name] = skill
	
	skill_added.emit(skill)
	return skill

## 移除技能
func remove_skill(skill_name: String):
	if not skills.has(skill_name):
		return
	
	var skill = skills[skill_name]
	
	# 从技能栏中移除
	for i in range(skill_bar.size()):
		if skill_bar[i] == skill:
			skill_bar[i] = null
	
	# 移除并释放
	skills.erase(skill_name)
	skill.queue_free()
	
	skill_removed.emit(skill_name)

## 获取技能
func get_skill(skill_name: String) -> Skill:
	return skills.get(skill_name)

## 使用技能
func use_skill(skill_name: String, target_position: Vector3 = Vector3.ZERO, target_node: Node3D = null) -> bool:
	var skill = get_skill(skill_name)
	if skill == null:
		return false
	
	return skill.use(target_position, target_node)

## 使用技能栏中的技能
func use_skill_from_bar(slot_index: int, target_position: Vector3 = Vector3.ZERO, target_node: Node3D = null) -> bool:
	if slot_index < 0 or slot_index >= skill_bar.size():
		return false
	var skill = skill_bar[slot_index]
	if skill == null:
		return false
	return skill.use(target_position, target_node)


## 技能栏按槽位释放（与 use_skill_from_bar 等价，便于循环调用）
func use_slot(slot_index: int, target_position: Vector3 = Vector3.ZERO, target_node: Node3D = null) -> bool:
	return use_skill_from_bar(slot_index, target_position, target_node)

## 将技能添加到快捷栏
func add_to_skill_bar(skill_name: String, slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= max_skill_slots:
		return false
	
	var skill = get_skill(skill_name)
	#print(skill.get_damage())
	if skill == null:
		return false
	
	skill_bar[slot_index] = skill
	return true

## 从快捷栏移除技能
func remove_from_skill_bar(slot_index: int):
	if slot_index >= 0 and slot_index < skill_bar.size():
		skill_bar[slot_index] = null

## 升级技能
func level_up_skill(skill_name: String) -> bool:
	var skill = get_skill(skill_name)
	if skill == null:
		return false
	
	return skill.level_up()

## 设置技能等级
func set_skill_level(skill_name: String, level: int):
	var skill = get_skill(skill_name)
	if skill:
		skill.set_level(level)

## 获取所有技能信息
func get_all_skills_info() -> Array[Dictionary]:
	var info_array: Array[Dictionary] = []
	for skill in skills.values():
		info_array.append(skill.get_info())
	return info_array

## 获取技能栏信息
func get_skill_bar_info() -> Array[Dictionary]:
	var info_array: Array[Dictionary] = []
	for skill in skill_bar:
		if skill:
			info_array.append(skill.get_info())
		else:
			info_array.append({})
	return info_array

## 信号回调
func _on_skill_used(skill: Skill):
	skill_used.emit(skill)

## 保存技能数据
func save_skills_data() -> Dictionary:
	var data = {}
	for skill_name in skills:
		var skill = skills[skill_name]
		data[skill_name] = {
			"level": skill.current_level,
			"cooldown_remaining": skill.cooldown_remaining
		}
	return data

## 加载技能数据
func load_skills_data(data: Dictionary):
	for skill_name in data:
		if skills.has(skill_name):
			var skill = skills[skill_name]
			skill.current_level = data[skill_name]["level"]
			if data[skill_name].has("cooldown_remaining"):
				skill.cooldown_remaining = data[skill_name]["cooldown_remaining"]
				skill.is_on_cooldown = skill.cooldown_remaining > 0
