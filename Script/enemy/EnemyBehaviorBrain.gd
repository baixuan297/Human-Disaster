extends RefCounted
class_name EnemyBehaviorBrain

## 数据驱动的 AI 路由：行为树 ID、`ai_behavior_packs` 与 FSM 共存。
## `bt:*` 包表示应由行为树驱动（接入 Godot 行为树插件或自研 BT 后在此加载资源）；
## `fsm:*` 包表示由当前脚本状态机（如 enemy.gd）处理。


static func get_behavior_tree_id(enemy_def: Dictionary) -> String:
	return str(enemy_def.get("behavior_tree_id", "")).strip_edges()


static func get_ai_behavior_packs(enemy_def: Dictionary) -> PackedStringArray:
	var p: Variant = enemy_def.get("ai_behavior_packs", [])
	var out := PackedStringArray()
	if p is Array:
		for x in p:
			out.append(str(x))
	return out


static func wants_behavior_tree(enemy_def: Dictionary) -> bool:
	var bt := get_behavior_tree_id(enemy_def)
	if bt != "":
		return true
	for s in get_ai_behavior_packs(enemy_def):
		if str(s).begins_with("bt:") or str(s).begins_with("behavior_tree:"):
			return true
	return false


## 若尚未挂载 BT，是否继续用默认 FSM（enemy.gd）
static func fallback_fsm_when_bt_missing(enemy_def: Dictionary) -> bool:
	return true
