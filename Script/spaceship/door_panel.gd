extends Interactable
## 门板节点用：将交互转发给父节点（Door 根）的 interact，由门脚本统一处理开关与音效

func _ready() -> void:
	add_to_group("door")

func interact(player: Node = null) -> void:
	var door := get_parent()
	if door != null and door.has_method("interact"):
		door.interact(player)
