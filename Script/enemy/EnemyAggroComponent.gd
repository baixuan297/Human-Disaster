extends Node
class_name EnemyAggroComponent

## 挂在敌人下名为 `AggroComponent` 的子节点；无此节点时回退为只追场景内 Player。

@export var threat_decay_per_second: float = 0.35
@export var threat_radius_max: float = 0.0
## 超出该距离（米）时威胁额外衰减倍率；0 表示不启用距离衰减
@export var out_of_range_decay_mult: float = 2.5

var _threat: Dictionary = {} ## int instance_id -> float
var _enemy_body: Node3D


func _ready() -> void:
	var p: Node = get_parent()
	if p is Node3D:
		_enemy_body = p as Node3D


func _process(delta: float) -> void:
	if _threat.is_empty():
		return
	var decay: float = threat_decay_per_second * delta
	var to_erase: Array = []
	for k in _threat.keys():
		var nid: int = int(k)
		if not is_instance_id_valid(nid):
			to_erase.append(k)
			continue
		var node := instance_from_id(nid) as Node
		if not is_instance_valid(node):
			to_erase.append(k)
			continue
		var mult: float = 1.0
		if threat_radius_max > 0.0 and is_instance_valid(_enemy_body) and node is Node3D:
			var dist: float = _enemy_body.global_position.distance_to((node as Node3D).global_position)
			if dist > threat_radius_max:
				mult = out_of_range_decay_mult
		var nv: float = float(_threat[k]) - decay * mult
		if nv <= 0.25:
			to_erase.append(k)
		else:
			_threat[k] = nv
	for k in to_erase:
		_threat.erase(k)


func add_threat_from_attack(attack_data: AttackData, threat_floor: float = 8.0) -> void:
	if attack_data == null:
		return
	var player_root := _find_player_root(attack_data.source_node)
	if not is_instance_valid(player_root):
		return
	var id: int = player_root.get_instance_id()
	var dmg: float = maxf(attack_data.final_damage, 1.0)
	_threat[id] = float(_threat.get(id, 0.0)) + threat_floor + dmg * 0.12


## 嘲讽 / 强制集火：给指定玩家根节点一次性大量威胁
func apply_taunt(attacker: Node, bonus: float = 420.0) -> void:
	var root := _find_player_root(attacker)
	if not is_instance_valid(root):
		return
	var id: int = root.get_instance_id()
	_threat[id] = float(_threat.get(id, 0.0)) + bonus


func get_primary_target() -> Node3D:
	var best_id: int = 0
	var best_v: float = -1.0
	## 复制键再迭代，避免在遍历中 erase 导致未定义行为
	for k in _threat.keys().duplicate():
		var nid: int = int(k)
		if not is_instance_id_valid(nid):
			_threat.erase(k)
			continue
		var node := instance_from_id(nid) as Node
		if not is_instance_valid(node):
			_threat.erase(k)
			continue
		var v: float = float(_threat[k])
		if v > best_v:
			best_v = v
			best_id = nid
	if best_id == 0:
		return null
	return instance_from_id(best_id) as Node3D


func _find_player_root(n: Node) -> Node:
	var p: Node = n
	while p != null:
		if p.is_in_group("Player"):
			return p
		p = p.get_parent()
	return null
