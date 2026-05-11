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
## SKILL 阶段空气墙（完成技能操作后关闭）
@onready var _skill_part: StaticBody3D = $Part/SkillPart

@onready var weapon_position: Node3D = $weapon_position
@onready var _virtual_keyboard: CanvasItem = $VirtualKeyboard
@onready var _virtual_mouse: CanvasItem = $VirtualMouse

## 教程期间 Toast 区域：顶栏全宽 / 左或右侧竖条（离开教程后恢复 GlobalMessage 场景内原布局）
@export var tutorial_toast_dock_placement: GlobalMessage.TutorialToastDockPlacement = GlobalMessage.TutorialToastDockPlacement.TOP_WIDE

## 教程内 Toast 默认停留（秒）；多行键位说明较长，单独再延长见下方常量
const TUTORIAL_TOAST_DEFAULT_HOLD := 7.5
## 欢迎语在玩家按键前不消失，设极大值并由 dismiss 关闭
const TUTORIAL_WELCOME_HOLD_UNTIL_KEY := 86400.0
const TUTORIAL_STEP_HINT_HOLD := 10.0
const TUTORIAL_EXIT_HOLD := 6.0


func _ready() -> void:
	var gm := _get_global_message()
	if gm:
		gm.push_tutorial_toast_layout(TUTORIAL_TOAST_DEFAULT_HOLD, tutorial_toast_dock_placement)
	_virtual_keyboard.visible = false
	_virtual_mouse.visible = false
	if not TutorialManager.step_completed.is_connected(_on_step_completed):
		TutorialManager.step_completed.connect(_on_step_completed)
	TutorialManager.enter_tutorial(TutorialManager.Step.WALK)
	if not TutorialManager.step_changed.is_connected(_on_tutorial_step_changed):
		TutorialManager.step_changed.connect(_on_tutorial_step_changed)
	_run_tutorial_intro_hints()


func _exit_tree() -> void:
	if TutorialManager:
		TutorialManager.exit_tutorial()
		if TutorialManager.step_completed.is_connected(_on_step_completed):
			TutorialManager.step_completed.disconnect(_on_step_completed)
		if TutorialManager.step_changed.is_connected(_on_tutorial_step_changed):
			TutorialManager.step_changed.disconnect(_on_tutorial_step_changed)
	var gm_exit := _get_global_message()
	if gm_exit:
		gm_exit.pop_tutorial_toast_layout()


func _get_global_message() -> GlobalMessage:
	var n := get_tree().root.get_node_or_null(^"GBMssage")
	return n as GlobalMessage


func _run_tutorial_intro_hints() -> void:
	await get_tree().create_timer(0.25).timeout
	TutorialManager.begin_intro_welcome_input_gate()
	GlobalMessage.emit_toast(
		"欢迎来到《人类灾难》！请跟随分区地面与区域提示，依次完成下列教程后再开始冒险。\n\n（按任意键继续）",
		"success",
		TUTORIAL_WELCOME_HOLD_UNTIL_KEY,
	)
	await TutorialManager.intro_welcome_acknowledged
	GlobalMessage.dismiss_toast()
	_virtual_keyboard.visible = true
	_virtual_mouse.visible = true
	# 初始 WALK 的 step_changed 在 connect 之前已发出，仅当玩家尚未进区推进时再补发首段键位说明
	if TutorialManager.get_current_step() == TutorialManager.Step.WALK:
		_emit_step_hint_for(TutorialManager.Step.WALK)


func _on_tutorial_step_changed(new_step: TutorialManager.Step) -> void:
	if new_step == TutorialManager.Step.FULL:
		GlobalMessage.emit_toast("教程结束，全部操作已解锁。", "success", TUTORIAL_EXIT_HOLD)
		return
	_emit_step_hint_for(new_step)


func _emit_step_hint_for(step: TutorialManager.Step) -> void:
	if step == TutorialManager.Step.FULL:
		return
	var msg := TutorialHints.build_step_message(step)
	if not msg.is_empty():
		GlobalMessage.emit_toast(msg, "info", TUTORIAL_STEP_HINT_HOLD)


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
		var p := CharacterDataManager.get_player()
		if p:
			var st: Stats = p.get("player_stats") as Stats
			if st:
				st.tutorial_completed = true
		# 未登录/无角色 ID：允许离线通过教程，不阻塞切场景
		if UserManager.current_character_id.is_empty():
			ScreenEffect.cutscene_fade_out(1.0)
			SceneManager.change_scene("training_ground")
			return
		CharacterDataManager.save_to_api(func(ok, d):
			if ok:
				ScreenEffect.cutscene_fade_out(1.0)
				SceneManager.change_scene("training_ground")
			else:
				var details := ""
				if d is Dictionary and (d as Dictionary).has("errors"):
					var errs: Variant = (d as Dictionary).get("errors", [])
					if errs is Array and not (errs as Array).is_empty():
						var parts: PackedStringArray = PackedStringArray()
						for e in errs:
							if e is Dictionary:
								parts.append("%s: %s" % [str(e.get("kind", "")), str(e.get("message", ""))])
							else:
								parts.append(str(e))
						details = "\n" + "\n".join(parts)
				GlobalMessage.emit_toast("教程完成状态同步失败，请检查网络后再次进入传送区%s" % details, "error")
		, true)
