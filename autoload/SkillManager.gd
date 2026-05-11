## 技能管理器（autoload）— 运行时技能字典 + 快捷栏
##
## 职责：
## - 维护已学会的 `Skill` 实例（key 为经 `SkillLookup.normalize_lookup_key` 规范化后的 `SkillResource.skill_name`）。
## - 维护玩家快捷栏数组（固定长度 `max_skill_slots`）。
## - 通过 `SkillResourceRegistry` 在存档与 API 之间翻译技能键；未注册的本地技能会在 `add_skill` 时自动回注册，
##   避免保存时丢失映射。
##
## 相关文档：`docs/SKILL_SYSTEM.md`（数据流、命名、AttackData 伤害约定）。
extends Node

## 信号
signal skill_added(skill: Skill)
signal skill_removed(skill_name: String)
signal skill_used(skill: Skill)
signal skill_bar_changed()

## 技能存储：key = canonical runtime name（规范化后的 SkillResource.skill_name）
var skills: Dictionary = {}

## 技能栏配置
@export var max_skill_slots: int = 4
var skill_bar: Array = []

## 当前施法角色（由 Player._setup_skills 在 _ready 中注入）
var character: Node3D


func _ready() -> void:
	skill_bar.resize(max_skill_slots)


## 将任意传入的技能名字符串转为 skills 字典中的规范键
func _skill_dict_key(skill_name: String) -> String:
	return SkillLookup.normalize_lookup_key(skill_name)


## 添加技能；若资源未在 SkillResourceRegistry 登记，会自动回注册，确保存档键可回写。
func add_skill(skill_resource: SkillResource, initial_level: int = 1) -> Skill:
	if skill_resource == null:
		push_warning("[SkillManager] add_skill 收到 null 资源")
		return null

	## 自动回注册：本地测试技能没经过 /game-data/skills 也能走存档路径
	if not SkillResourceRegistry.is_registered(skill_resource):
		SkillResourceRegistry.register_mapping(skill_resource.skill_name, skill_resource)

	var key: String = _skill_dict_key(skill_resource.skill_name)
	if skills.has(key):
		var existing: Skill = skills[key]
		## 场景切换或重生后 character 会指向新节点，这里必须刷新，避免 Skill 持有悬空 owner_node。
		if character != null:
			existing.owner_node = character
		return existing

	var skill := Skill.new()
	skill.skill_resource = skill_resource
	skill.current_level = initial_level
	skill.owner_node = character
	skill.skill_used.connect(_on_skill_used)
	add_child(skill)
	skills[key] = skill
	skill_added.emit(skill)
	return skill


## 移除技能
func remove_skill(skill_name: String) -> void:
	var key := _skill_dict_key(skill_name)
	if not skills.has(key):
		return
	var skill: Skill = skills[key]
	for i in range(skill_bar.size()):
		if skill_bar[i] == skill:
			skill_bar[i] = null
	skills.erase(key)
	skill.queue_free()
	skill_removed.emit(key)


## 获取技能
func get_skill(skill_name: String) -> Skill:
	return skills.get(_skill_dict_key(skill_name)) as Skill


## 使用技能
func use_skill(skill_name: String, target_position: Vector3 = Vector3.ZERO, target_node: Node3D = null) -> bool:
	var skill := get_skill(skill_name)
	if skill == null:
		return false
	return skill.use(target_position, target_node)


## 使用技能栏中的技能
func use_slot(slot_index: int, target_position: Vector3 = Vector3.ZERO, target_node: Node3D = null) -> bool:
	if slot_index < 0 or slot_index >= skill_bar.size():
		return false
	var skill = skill_bar[slot_index]
	if skill == null:
		return false
	return skill.use(target_position, target_node)


## 解析要上栏的技能：支持 SkillResource.skill_name（如 FireBall）与数据库 game.skills.name（如 火球术）
func _resolve_skill_for_bar(skill_name: String) -> Skill:
	var s := get_skill(skill_name)
	if s != null:
		return s
	var res: SkillResource = SkillResourceRegistry.get_resource_for_api_key(skill_name)
	if res == null:
		return null
	s = get_skill(res.skill_name)
	if s != null:
		return s
	if character != null:
		return add_skill(res, 1)
	return null


## 将技能添加到快捷栏
func add_to_skill_bar(skill_name: String, slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= max_skill_slots:
		return false
	var skill := _resolve_skill_for_bar(skill_name)
	if skill == null:
		var learned: Array[String] = []
		for k in skills.keys():
			learned.append(str(k))
		learned.sort()
		push_warning(
			"[SkillManager] add_to_skill_bar 失败: 槽=%d, 输入=%s, 已学会(%d)=[%s]"
			% [slot_index, SkillLookup.format_lookup_attempt(skill_name), skills.size(), ", ".join(learned)]
		)
		return false
	skill_bar[slot_index] = skill
	skill_bar_changed.emit()
	return true


## 从快捷栏移除技能
func remove_from_skill_bar(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < skill_bar.size():
		skill_bar[slot_index] = null
		skill_bar_changed.emit()


## 升级技能
func level_up_skill(skill_name: String) -> bool:
	var skill := get_skill(skill_name)
	if skill == null:
		return false
	return skill.level_up()


## 设置技能等级
func set_skill_level(skill_name: String, level: int) -> void:
	var skill := get_skill(skill_name)
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


## 切换角色 / 登出时调用：清空所有运行时技能与快捷栏，避免数据串号。
func reset_for_character() -> void:
	for skill in skills.values():
		if is_instance_valid(skill):
			skill.queue_free()
	skills.clear()
	for i in range(skill_bar.size()):
		skill_bar[i] = null
	character = null


## 信号回调
func _on_skill_used(skill: Skill) -> void:
	skill_used.emit(skill)


## 保存技能数据（字典键转换为 **game.skills.name**，便于 POST /characters/{id}/skills）
func save_skills_data() -> Dictionary:
	var data: Dictionary = {}
	for runtime_key in skills:
		var skill: Skill = skills[runtime_key]
		var api_key: String = SkillResourceRegistry.runtime_name_to_api_key(runtime_key)
		if data.has(api_key):
			push_warning("[SkillManager] save_skills_data: api_key 冲突，后写覆盖前写: %s" % api_key)
		data[api_key] = {
			"level": skill.current_level,
			"cooldown_remaining": skill.cooldown_remaining,
		}
	return data


func _apply_skill_payload(skill: Skill, payload: Variant) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return
	var d: Dictionary = payload
	skill.current_level = int(d.get("level", skill.current_level))
	if d.has("cooldown_remaining"):
		skill.cooldown_remaining = float(d["cooldown_remaining"])
		skill.is_on_cooldown = skill.cooldown_remaining > 0.0


## 加载技能数据（支持 **game.skills.name**、**skill_id** 字符串、及 **SkillLookup** 别名；未注册键会 push_warning 并跳过）
func load_skills_data(data: Dictionary) -> void:
	if character == null:
		push_warning("[SkillManager] load_skills_data: character 未设置，新增技能的 owner_node 将为空；请在调用前先设置 SkillManager.character")
	for raw_key in data:
		var key := str(raw_key)
		var payload = data[key]
		var res: SkillResource = SkillResourceRegistry.get_resource_for_api_key(key)
		if res == null:
			push_warning(
				"[SkillManager] load_skills_data: 未注册的技能键，已跳过: %s"
				% SkillLookup.format_lookup_attempt(key)
			)
			continue
		var runtime_key := _skill_dict_key(res.skill_name)
		if not skills.has(runtime_key):
			var level := 1
			if typeof(payload) == TYPE_DICTIONARY:
				level = int((payload as Dictionary).get("level", 1))
			add_skill(res, level)
		_apply_skill_payload(skills[runtime_key], payload)
