extends Node

## 技能资源注册表（autoload）：**云端/存档键** ↔ **本地 SkillResource**
##
## - `get_resource_for_api_key`：解析来自 API / 存档的键（中文名、`skill_id`、英文别名等，经 `SkillLookup`）。
## - `runtime_name_to_api_key`：供 `SkillManager.save_skills_data` 写回服务端使用的 `name`。
## - `register_from_game_data_*`：由 `GameDataManager` 在加载 `/game-data/skills` 或本地缓存后调用
##   （依赖 `metadata.res_path`）。
## - `register_mapping`：手动 / 自动回注册入口；`SkillManager.add_skill` 在资源未登记时会自动调用。
##
## 流程见 `docs/SKILL_SYSTEM.md` 第 10、12 节。

var _resources_by_runtime_name: Dictionary = {}  # String -> SkillResource
var _api_key_to_runtime: Dictionary = {}  # String -> String
var _runtime_to_api_key: Dictionary = {}  # String -> String


func _ready() -> void:
	## 避免编辑器 play 多次时 SkillLookup 的 static 同义词表残留
	SkillLookup.reset()
	register_mapping("火球术", preload("res://resource/skill/Fireball.tres"))
	register_mapping("雷电术", preload("res://resource/skill/Lightning.tres"))
	register_mapping("群体治疗术", preload("res://resource/skill/GroupHealingSkill.tres"))


## 登记 API 名 ↔ 本地 SkillResource；同时在 SkillLookup 中写入常见别名（API 名、运行时名、skill_id 字符串）。
func register_mapping(api_display_name: String, skill_res: SkillResource) -> void:
	if skill_res == null:
		push_warning("[SkillResourceRegistry] register_mapping: 收到空资源，已忽略")
		return
	var runtime: String = skill_res.skill_name.strip_edges()
	if runtime.is_empty():
		push_warning("[SkillResourceRegistry] register_mapping: 资源 skill_name 为空，已忽略")
		return
	SkillLookup.register_synonym(runtime, runtime)
	if not api_display_name.is_empty():
		SkillLookup.register_synonym(api_display_name, runtime)
	if skill_res.skill_id > 0:
		SkillLookup.register_synonym(str(skill_res.skill_id), runtime)
	_resources_by_runtime_name[runtime] = skill_res
	if not api_display_name.is_empty():
		_api_key_to_runtime[api_display_name] = runtime
		_runtime_to_api_key[runtime] = api_display_name
	elif not _runtime_to_api_key.has(runtime):
		## 无 API 名时退化为自映射，保证 save_skills_data 至少能回写 runtime key
		_runtime_to_api_key[runtime] = runtime


## 判定某 SkillResource 是否已被登记（供 SkillManager 决定是否自动回注册）。
func is_registered(skill_res: SkillResource) -> bool:
	if skill_res == null:
		return false
	var runtime: String = skill_res.skill_name.strip_edges()
	return _resources_by_runtime_name.get(runtime) == skill_res


func get_resource_for_api_key(api_key: String) -> SkillResource:
	var nk: String = SkillLookup.normalize_lookup_key(str(api_key))
	if _resources_by_runtime_name.has(nk):
		return _resources_by_runtime_name[nk]
	if _api_key_to_runtime.has(nk):
		var rt: String = _api_key_to_runtime[nk]
		return _resources_by_runtime_name.get(rt) as SkillResource
	var raw_stripped := str(api_key).strip_edges()
	if raw_stripped != nk and _api_key_to_runtime.has(raw_stripped):
		var rt2: String = _api_key_to_runtime[raw_stripped]
		return _resources_by_runtime_name.get(rt2) as SkillResource
	return null


func runtime_name_to_api_key(runtime_name: String) -> String:
	var nk: String = SkillLookup.normalize_lookup_key(String(runtime_name))
	return str(_runtime_to_api_key.get(nk, nk))


## 将 /game-data/skills 单条定义合并进映射（依赖 metadata.res_path，由 seeder 写入 DB）
func register_from_game_data_row(raw: Dictionary) -> void:
	var api_name := str(raw.get("name", ""))
	if api_name.is_empty():
		return
	var meta: Dictionary = {}
	var md: Variant = raw.get("metadata")
	if md is Dictionary:
		meta = md
	var path := str(meta.get("res_path", ""))
	if path.is_empty():
		return
	if not ResourceLoader.exists(path):
		push_warning("[SkillResourceRegistry] res_path 无效或文件不存在: %s （技能 %s）" % [path, api_name])
		return
	var loaded: Resource = load(path)
	if not (loaded is SkillResource):
		push_warning("[SkillResourceRegistry] 非 SkillResource: %s （技能 %s）" % [path, api_name])
		return
	var skill_res: SkillResource = loaded as SkillResource
	register_mapping(api_name, skill_res)


## 批量：GameDataManager 拉取静态技能表后调用
func register_from_game_data_skill_list(rows: Array) -> void:
	for row in rows:
		if row is Dictionary:
			register_from_game_data_row(row as Dictionary)
