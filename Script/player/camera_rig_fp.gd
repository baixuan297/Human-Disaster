extends Node3D
class_name CameraRigFP

## 第一人称相机架子场景根（`CameraRigFP.tscn`）。
## - 行走颠簸（bob）由 CameraController 修改**本节点** `position`，不直接动 FPCamera。
## - 子节点 **%FPCamera**（Camera3D）承载瞄准/交互射线等；**Weapon_manager** 在玩家根节点，由 WeaponManager 脚本按路径绑定本相机。

@onready var fp_camera: Camera3D = %FPCamera


func _ready() -> void:
	if fp_camera == null:
		push_error("CameraRigFP: 缺少唯一名节点 %FPCamera（应为 Camera3D）")
		return


## 第一人称相机（与当前激活的 Viewport 相机一致时即 FP 模式）
func get_fp_camera() -> Camera3D:
	return fp_camera


func get_weapon_manager() -> WeaponManager:
	var n: Node = self
	while n != null:
		if n is CharacterBody3D:
			return n.get_node_or_null("Weapon_manager") as WeaponManager
		n = n.get_parent()
	return null


## 重置 bob 造成的本地位移（例如过场、传送后）
func reset_local_offset() -> void:
	position = Vector3.ZERO
