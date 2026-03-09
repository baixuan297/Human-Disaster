extends Node
## 教程管理器：控制教程步骤并限制玩家可用的操作
##
## 用法：
## - 教程场景加载时调用 enter_tutorial(STEP_xxx)，离开时调用 exit_tutorial()
## - 玩家进入某个 Area3D 时调用 advance_to_step(STEP_xxx) 解锁新操作
## - Player 在输入与物理帧中通过 is_action_allowed() 判断是否响应操作

enum Step {
	## 仅移动：WASD + 鼠标视角
	WALK,
	## 移动 + 蹲跳：WASD、跳跃、下蹲、奔跑
	JUMP_CROUCH,
	## 使用武器
	WEAPON,
	## 使用技能
	SKILL,
	## 全部操作解锁
	FULL,
}

const ACTIONS_WALK: Array[StringName] = [
	&"move_forward",
	&"move_back",
	&"move_left",
	&"move_right",
]

## 在 WALK 基础上增加的操作
const ACTIONS_JUMP_CROUCH_EXTRA: Array[StringName] = [
	&"jump",
	&"crouch",
	&"Run",
]

const ACTIONS_WEAPON: Array[StringName] = [
	&"shoot",
	&"change_weapon1",
	&"change_weapon2",
	&"change_hand",
	&"reload",
	&"interactable",
	&"next_weapon",
	&"prev_weapon",
]

const ACTIONS_SKILL: Array[StringName] = [
	&"Skill1",
	&"Skill2",
	&"Skill3",
]

var _current_step: Step = Step.FULL
var _in_tutorial: bool = false
## 本阶段已按过的 action 集合（key=action, value=true），用于判断 step_completed
var _pressed_actions_this_step: Dictionary = {}
## 本阶段是否已发出 step_completed，避免重复发射
var _step_completed_emitted: bool = false

## 步骤变化时发出（键盘 UI 监听后重置“已按”状态，仅本阶段键高亮）
signal step_changed(new_step: Step)
## 本阶段所有操作已完成时发出（TutorialController 用于关闭对应空气墙）
signal step_completed(step: Step)


func _ready() -> void:
	pass


func _process(_delta: float) -> void:
	## 每帧检测本阶段操作是否全部完成
	_check_step_completion()


## 进入教程模式，并设置初始步骤
func enter_tutorial(initial_step: Step = Step.WALK) -> void:
	_in_tutorial = true
	_current_step = initial_step
	_reset_step_completion_state()
	step_changed.emit(_current_step)


## 离开教程场景时调用，恢复全部操作
func exit_tutorial() -> void:
	_in_tutorial = false
	_current_step = Step.FULL
	step_changed.emit(_current_step)


## 是否处于教程模式
func is_in_tutorial() -> bool:
	return _in_tutorial


## 当前教程步骤
func get_current_step() -> Step:
	return _current_step


## 推进到指定步骤（例如玩家进入“蹲跳区域”时调用）
func advance_to_step(step: Step) -> void:
	if step > _current_step:
		_current_step = step
		_reset_step_completion_state()
		step_changed.emit(_current_step)


## 步骤切换时重置：清空已按记录，允许新阶段再次检测完成
func _reset_step_completion_state() -> void:
	_pressed_actions_this_step.clear()
	_step_completed_emitted = false


## 检测本阶段所有操作是否已完成，若完成则发出 step_completed
func _check_step_completion() -> void:
	if not _in_tutorial or _step_completed_emitted:
		return
	var actions: Array[StringName] = get_highlight_actions_for_current_step()
	if actions.is_empty():
		return
	# 记录本帧刚按下的 action
	for action in actions:
		if Input.is_action_just_pressed(action):
			_pressed_actions_this_step[action] = true
	# 若仍有未按过的 action，则未完成
	for action in actions:
		if not _pressed_actions_this_step.get(action, false):
			return
	step_completed.emit(_current_step)
	_step_completed_emitted = true


## 返回“仅本阶段需要高亮”的 action 列表（供键盘 UI 用）
## 进入下一阶段后，前一阶段的按键不再高亮，只高亮本阶段新引入的按键
func get_highlight_actions_for_current_step() -> Array[StringName]:
	if not _in_tutorial:
		return []
	match _current_step:
		Step.WALK:
			return ACTIONS_WALK.duplicate()
		Step.JUMP_CROUCH:
			return ACTIONS_JUMP_CROUCH_EXTRA.duplicate()
		Step.WEAPON:
			return ACTIONS_WEAPON.duplicate()
		Step.SKILL:
			return ACTIONS_SKILL.duplicate()
		Step.FULL:
			return []
	return []


## 判断某 action 是否属于“本阶段高亮”集合（仅本阶段新教的键高亮，前阶段键回归默认）
func is_action_highlighted_this_step(action: StringName) -> bool:
	return action in get_highlight_actions_for_current_step()


## 判断某操作在当前步骤是否允许
## 用于移动：move_forward / move_back / move_left / move_right
## 用于蹲跳：jump / crouch / Run
## 用于武器：shoot / reload / change_weapon1~2 / change_hand
## 用于技能：Skill1~3
## 其他：change_person / interactable / rightclick / free_look 等
func is_action_allowed(action: StringName) -> bool:
	if not _in_tutorial:
		return true

	match _current_step:
		Step.WALK:
			return action in ACTIONS_WALK
		Step.JUMP_CROUCH:
			return action in ACTIONS_WALK or action in ACTIONS_JUMP_CROUCH_EXTRA
		Step.WEAPON:
			return action in ACTIONS_WALK or action in ACTIONS_JUMP_CROUCH_EXTRA \
			 or action in ACTIONS_WEAPON
		Step.SKILL:
			return action in ACTIONS_WALK or action in ACTIONS_JUMP_CROUCH_EXTRA \
			 or action in ACTIONS_WEAPON or action in ACTIONS_SKILL
		Step.FULL:
			return true
	return false


## 鼠标视角在教程中始终允许（否则无法看路）
func is_look_allowed() -> bool:
	return true
