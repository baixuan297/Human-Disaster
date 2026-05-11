extends RefCounted
class_name TutorialHints

## 教程阶段说明 + 从 InputMap 读取的键位文案（避免写死具体键名）

const ACTION_LABELS: Dictionary = {
	"move_forward": "前进",
	"move_back": "后退",
	"move_left": "向左",
	"move_right": "向右",
	"jump": "跳跃",
	"crouch": "下蹲",
	"Run": "奔跑",
	"shoot": "开火",
	"change_weapon1": "武器槽 1",
	"change_weapon2": "武器槽 2",
	"change_hand": "切换主/副手",
	"reload": "换弹",
	"interactable": "交互",
	"next_weapon": "下一武器",
	"prev_weapon": "上一武器",
	"drop": "丢弃武器",
	"Skill1": "技能 1",
	"Skill2": "技能 2",
	"Skill3": "技能 3",
}


static func build_step_message(step: TutorialManager.Step) -> String:
	var header := _step_header(step)
	var actions: Array[StringName] = TutorialManager.get_highlight_actions_for_step(step)
	if actions.is_empty():
		return header
	var lines: PackedStringArray = PackedStringArray()
	for action in actions:
		lines.append(_format_action_line(action))
	return "%s\n%s" % [header, "\n".join(lines)]


static func _step_header(step: TutorialManager.Step) -> String:
	match step:
		TutorialManager.Step.WALK:
			return "【移动】在区域内依次使用四个方向键各一次，全部按过后可离开本区。"
		TutorialManager.Step.JUMP_CROUCH:
			return "【蹲跳与奔跑】本阶段将解锁跳跃、下蹲与奔跑；在圈内各按一次以熟悉操作。"
		TutorialManager.Step.WEAPON:
			return "【武器】练习切换武器、开火、换弹与交互；每个键各按一次即可完成本段。"
		TutorialManager.Step.SKILL:
			return "【技能】使用三个技能键各施放/触发一次，完成本段教程。"
		TutorialManager.Step.FULL:
			return "全部操作已解锁。"
	return ""


static func _format_action_line(action: StringName) -> String:
	var key := String(action)
	var label: String = ACTION_LABELS.get(key, key)
	var parts: PackedStringArray = PackedStringArray()
	for ev in InputMap.action_get_events(action):
		if ev is InputEvent:
			parts.append((ev as InputEvent).as_text().strip_edges())
	if parts.is_empty():
		return "%s（未绑定按键）" % label
	return "%s：%s" % [label, "、".join(parts)]
