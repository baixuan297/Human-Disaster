extends RefCounted
class_name EnemySkillExecutor

## 敌人技能数据：优先读 API 顶层 `skills`，兼容 `metadata.skills`。
## skill_type：MELEE_BOOST | AOE | CONTROL | SPECIAL | SUMMON — 执行逻辑由 BaseEnemy 子类 / BT 节点逐步实现


static func get_skill_entries(enemy_def: Dictionary) -> Array:
	var top: Variant = enemy_def.get("skills", [])
	if top is Array and not (top as Array).is_empty():
		return top as Array
	var meta: Variant = enemy_def.get("metadata", {})
	if meta is Dictionary:
		var inner: Variant = (meta as Dictionary).get("skills", [])
		if inner is Array:
			return inner as Array
	return []


static func filter_by_skill_type(entries: Array, skill_type: String) -> Array:
	var u := skill_type.to_upper()
	return entries.filter(func(e):
		if not e is Dictionary:
			return false
		return str((e as Dictionary).get("skill_type", "")).to_upper() == u
	)


static func read_skill_ids(enemy_def: Dictionary) -> Array:
	return get_skill_entries(enemy_def)
