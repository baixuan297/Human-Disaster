extends Node3D
## 教程场景根脚本：进入时开启教程并设为首步（仅 WASD），
## 子节点中的 TutorialZone 会在玩家进入时推进步骤（如解锁蹲跳）。
## 当本阶段操作全部完成时，关闭对应空气墙（movementPart / jumpCrouchPart / WeaponPart）。

## WALK 阶段空气墙（完成 WASD 后关闭）
@onready var _movement_part: StaticBody3D = $Part/movementPart
## JUMP_CROUCH 阶段空气墙（完成蹲跳奔跑后关闭）
@onready var _jump_crouch_part: StaticBody3D = $Part/jumpCrouchPart
## WEAPON 阶段空气墙（完成武器操作后关闭）
@onready var _weapon_part: StaticBody3D = $Part/WeaponPart
## WEAPON 阶段空气墙（完成武器操作后关闭）
@onready var _skill_part: StaticBody3D = $Part/SkillPart

@onready var weapon_position: Node3D = $weapon_position


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
		TutorialManager.Step.SKILL:
			wall = _skill_part
	if not wall:
		return
	for child in wall.get_children():
		if child is CollisionShape3D:
			child.disabled = true
		
# TODO： 改为当前一个阶段完成武器系统使用动画显现 但是这个只是暂时教学系统
## 当角色进入后显示武器
func _on_zone_weapon_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		weapon_position.visible = true

func _on_zone_weapon_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		weapon_position.visible = false

func _on_teleport_area_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		CharacterDataManager.save_to_api()
		ScreenEffect.cutscene_fade_out(1.0)
		SceneManager.change_scene("training_ground")
