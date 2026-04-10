## CharacterGeneModuleState.gd — 角色子基因存档状态

extends Resource
class_name CharacterGeneModuleState

var module_id: int = 0
var current_level: int = 0
var points_spent: int = 0


func _init(p_mid: int = 0, p_lv: int = 0, p_spent: int = 0) -> void:
	module_id = p_mid
	current_level = p_lv
	points_spent = p_spent


func level_up(cost: int = 0) -> int:
	current_level += 1
	points_spent += cost
	return current_level


func to_dict() -> Dictionary:
	return {
		"module_id": module_id,
		"current_level": current_level,
		"points_spent": points_spent,
	}


static func from_dict(d: Dictionary) -> CharacterGeneModuleState:
	return CharacterGeneModuleState.new(
		int(d.get("module_id", 0)),
		int(d.get("current_level", 0)),
		int(d.get("points_spent", 0))
	)
