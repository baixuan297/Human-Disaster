extends Node3D
## 教程场景根脚本：进入时开启教程并设为首步（仅 WASD），
## 子节点中的 TutorialZone 会在玩家进入时推进步骤（如解锁蹲跳）。
## 当本阶段操作全部完成时，关闭对应空气墙（movementPart / jumpCrouchPart / WeaponPart）。

## WALK 阶段空气墙（完成 WASD 后关闭）
@onready var _movement_part: StaticBody3D = $movementPart
## JUMP_CROUCH 阶段空气墙（完成蹲跳奔跑后关闭）
@onready var _jump_crouch_part: StaticBody3D = $jumpCrouchPart
## WEAPON 阶段空气墙（完成武器操作后关闭）
@onready var _weapon_part: StaticBody3D = $WeaponPart


func _ready() -> void:
	TutorialManager.enter_tutorial(TutorialManager.Step.WALK)
	if not TutorialManager.step_completed.is_connected(_on_step_completed):
		TutorialManager.step_completed.connect(_on_step_completed)


func _exit_tree() -> void:
	if TutorialManager and TutorialManager.step_completed.is_connected(_on_step_completed):
		TutorialManager.step_completed.disconnect(_on_step_completed)
	TutorialManager.exit_tutorial()


## 本阶段操作全部完成：根据步骤关闭对应空气墙的碰撞
func _on_step_completed(step: TutorialManager.Step) -> void:
	var wall: StaticBody3D = null
	match step:
		TutorialManager.Step.WALK:
			wall = _movement_part
		TutorialManager.Step.JUMP_CROUCH:
			wall = _jump_crouch_part
		TutorialManager.Step.WEAPON:
			wall = _weapon_part
	if not wall:
		return
	for child in wall.get_children():
		if child is CollisionShape3D:
			child.disabled = true
	
