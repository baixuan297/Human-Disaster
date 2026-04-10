extends RefCounted
class_name EnemyAnimationConditions

## 封装 AnimationTree 条件路径，避免散落魔法字符串

var _tree: AnimationTree


func _init(tree: AnimationTree) -> void:
	_tree = tree


func set_condition(cond: StringName, value: bool) -> void:
	if is_instance_valid(_tree):
		_tree.set("parameters/conditions/%s" % String(cond), value)
