extends RayCast3D
## 相机射线：命中可交互物时在 promt 上显示 get_prompt() 文案（如「拾取 [E]」「开门 [E]」）。

@onready var promt = $promt
@export var player: CharacterBody3D

func _ready():
	add_exception(player)

func _physics_process(delta):
	promt.text = ""
	if is_colliding():
		var detected = get_collider()
		# 继承 Interactable 的节点（门、门板等）
		if detected is Interactable:
			promt.text = detected.get_prompt()
		# 仅加入 Interactable 组并实现 get_prompt 的节点（如 WorldWeapon，不继承 Interactable）
		elif detected.is_in_group("Interactable") and detected.has_method("get_prompt"):
			promt.text = detected.get_prompt()
