extends Node

## 击杀时按 [method GameDataManager.get_enemy] 的 [code]drops[/code] Roll，直接进背包（后续可改为掉落地物）。

func process_enemy_death(enemy: BaseEnemy, _killer_hint: Node = null) -> void:
	if not is_instance_valid(enemy):
		return
	var tid: int = enemy.enemy_template_id
	if tid <= 0:
		return
	var def: Dictionary = GameDataManager.get_enemy(tid)
	if def.is_empty():
		return
	var drops: Variant = def.get("drops", [])
	if drops == null or not drops is Array:
		return
	if _resolve_loot_recipient(enemy.get_last_damage_attacker()) == null:
		return
	var gained_kinds: int = 0
	for row in drops:
		if row is Dictionary and _roll_one_drop(row as Dictionary):
			gained_kinds += 1
	if gained_kinds > 0:
		GlobalMessage.emit_toast("获得了战利品！", "success")


func _resolve_loot_recipient(from_node: Node) -> Node:
	var n: Node = from_node
	while n != null:
		if n.is_in_group("Player"):
			return n
		n = n.get_parent()
	return get_tree().get_first_node_in_group("Player")


func _roll_one_drop(row: Dictionary) -> bool:
	var iid: int = int(row.get("item_id", 0))
	if iid <= 0:
		return false
	var rate: float = float(row.get("drop_rate", 0.0))
	if rate <= 0.0:
		return false
	if randf() > rate:
		return false
	var mn: int = maxi(1, int(row.get("min_qty", 1)))
	var mx: int = maxi(mn, int(row.get("max_qty", 1)))
	var qty: int = randi_range(mn, mx)
	if InventoryManager:
		return InventoryManager.add_item_by_numeric_id(iid, qty)
	return false
