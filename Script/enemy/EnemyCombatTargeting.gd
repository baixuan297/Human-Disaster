extends RefCounted
class_name EnemyCombatTargeting

## 从 BaseEnemy 解析当前战斗目标：仇恨组件优先，否则 Player 组


static func resolve_combat_target(host: BaseEnemy) -> Node3D:
	if is_instance_valid(host.enemy_aggro):
		var t: Node3D = host.enemy_aggro.get_primary_target()
		if is_instance_valid(t):
			return t
	var p: Node = host.get_tree().get_first_node_in_group("Player")
	return p as Node3D


static func can_see_target(
	host: CharacterBody3D,
	target: Node3D,
	detection_range: float
) -> bool:
	if not is_instance_valid(target):
		return false
	return host.global_position.distance_to(target.global_position) <= detection_range
