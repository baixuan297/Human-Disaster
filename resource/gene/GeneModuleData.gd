## GeneModuleData.gd — 子基因模板（挂在主基因下）
## 与后端 game.gene_modules / genes.json 的 modules[] 对齐

extends Resource
class_name GeneModuleData

var module_id: int = 0
var parent_gene_id: int = 0
## 所属子基因线路（与后端 `game.gene_modules.line_id` 一致，默认 main）
var line_id: String = "main"
var code: String = ""
var display_name: String = ""
var description: String = ""
var sort_order: int = 0
var max_level: int = 1
var prerequisite_module_ids: Array[int] = []
var unlock_gene_points: int = 0
var upgrade_gene_points_per_level: int = 0
## 每项 { "item_id": int, "quantity": int }
var unlock_materials: Array = []
## 数组的数组：第 k 项为 等级 k+1 → k+2 所需材料
var upgrade_materials_per_level: Array = []
var level_effects: Array = []


static func from_dict(d: Dictionary) -> GeneModuleData:
	var m := GeneModuleData.new()
	m.module_id = int(d.get("module_id", 0))
	m.parent_gene_id = int(d.get("parent_gene_id", 0))
	m.line_id = str(d.get("line_id", "main")).strip_edges()
	if m.line_id.is_empty():
		m.line_id = "main"
	m.code = str(d.get("code", ""))
	m.display_name = str(d.get("name", ""))
	m.description = str(d.get("description", ""))
	m.sort_order = int(d.get("sort_order", 0))
	m.max_level = int(d.get("max_level", 1))
	m.unlock_gene_points = int(d.get("unlock_gene_points", 0))
	m.upgrade_gene_points_per_level = int(d.get("upgrade_gene_points_per_level", 0))
	var pre = d.get("prerequisite_module_ids", [])
	if pre is Array:
		for x in pre:
			m.prerequisite_module_ids.append(int(x))
	var um = d.get("unlock_materials", [])
	if um is Array:
		m.unlock_materials = um.duplicate(true)
	var up = d.get("upgrade_materials_per_level", [])
	if up is Array:
		m.upgrade_materials_per_level = up.duplicate(true)
	var le = d.get("level_effects", [])
	if le is Array:
		m.level_effects = le.duplicate(true)
	return m


func get_effect_at_level(level: int) -> Dictionary:
	for effect in level_effects:
		if int(effect.get("level", 0)) == level:
			return effect
	return {}


func get_bonuses_at_level(level: int) -> Dictionary:
	var effect := get_effect_at_level(level)
	var bonuses := {}
	var skip_keys := ["level", "description"]
	for key in effect:
		if str(key) not in skip_keys:
			bonuses[key] = effect[key]
	return bonuses


func materials_for_upgrade_from_level(from_level: int) -> Array:
	if not upgrade_materials_per_level is Array:
		return []
	var idx := from_level - 1
	if idx < 0 or idx >= upgrade_materials_per_level.size():
		return []
	var step: Variant = upgrade_materials_per_level[idx]
	return step if step is Array else []
