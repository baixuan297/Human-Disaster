extends RefCounted
class_name EnemyAiProfileBinding

## 将 GameDataManager 敌人 metadata.ai_profile 写入宿主节点上同名 @export 属性（依赖 Node.set）。
## 使用普通 const 字符串数组遍历；勿使用 const PackedStringArray([...])（非常量表达式）。
const _PROFILE_KEYS: Array[String] = [
	"detection_range",
	"lose_target_range",
	"attack_range",
	"attack_range_slack",
	"attack_cooldown",
	"move_speed",
	"patrol_radius",
	"patrol_wait_time",
	"stun_on_hit_chance",
	"stun_duration",
]


static func apply_from_template_id(host: Node, enemy_template_id: int) -> void:
	if enemy_template_id <= 0:
		return
	if not GameDataManager.is_loaded():
		var on_loaded := func():
			if is_instance_valid(host):
				_apply_to_host(host, GameDataManager.get_enemy(enemy_template_id))
		GameDataManager.all_data_loaded.connect(on_loaded, CONNECT_ONE_SHOT)
		return
	_apply_to_host(host, GameDataManager.get_enemy(enemy_template_id))


static func _apply_to_host(host: Node, def: Dictionary) -> void:
	if def.is_empty() or not is_instance_valid(host):
		return
	var meta: Variant = def.get("metadata", {})
	if not meta is Dictionary:
		return
	var m: Dictionary = meta as Dictionary
	var d: Dictionary = {}
	if m.get("ai_profile") is Dictionary:
		d = (m["ai_profile"] as Dictionary).duplicate()
	if d.is_empty() and m.has("vision_range"):
		host.set("detection_range", float(m["vision_range"]))
		return
	if d.is_empty():
		return
	for k in _PROFILE_KEYS:
		if d.has(k):
			host.set(k, float(d[k]))
