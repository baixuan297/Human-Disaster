extends RayCast3D
## 相机射线：命中可交互物时在 promt 上显示 get_prompt() 文案（如「拾取 [E]」「开门 [E]」）。
##
## `player`：用于 add_exception，避免射线打到自身碰撞体。
## 挂在 CameraRigFP 子场景内时，导出常为空，会在 _ready 中通过 owner 或父链解析 CharacterBody3D。

@onready var promt = $promt
@export var player: CharacterBody3D


func _ready() -> void:
	var body := _resolve_player_body()
	if body != null:
		add_exception(body)
	else:
		push_warning(
			"[%s] 无法解析 CharacterBody3D：请在检视器绑定 player，或确保本场景实例的 owner 为玩家根。"
			% name
		)


func _resolve_player_body() -> CharacterBody3D:
	if player != null:
		return player
	var o := get_owner()
	if o is CharacterBody3D:
		return o as CharacterBody3D
	var n: Node = get_parent()
	while n != null:
		if n is CharacterBody3D:
			return n as CharacterBody3D
		n = n.get_parent()
	return null


func _physics_process(_delta: float) -> void:
	promt.text = ""
	if is_colliding():
		var detected = get_collider()
		# 继承 Interactable 的节点（门、门板等）
		if detected is Interactable:
			promt.text = detected.get_prompt()
		# 仅加入 Interactable 组并实现 get_prompt 的节点（如 WorldWeapon，不继承 Interactable）
		elif detected.is_in_group("Interactable") and detected.has_method("get_prompt"):
			promt.text = detected.get_prompt()
