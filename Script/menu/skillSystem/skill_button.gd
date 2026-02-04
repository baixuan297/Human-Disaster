class_name SkillButton
extends Button

## 信号 - 当按钮被点击时发出，携带技能信息
signal skill_button_clicked(skill: Skill, button: SkillButton)

## 关联的技能对象
var linked_skill: Skill = null

## UI 节点引用（可选，如果按钮内有图标）
@onready var icon_rect: TextureRect = $icon_rect

## 设置技能数据
func setup_skill(skill: Skill) -> void:
	if skill == null:
		clear_skill()
		return
	
	linked_skill = skill
	
	# 更新按钮显示
	if icon_rect and skill.skill_resource.icon:
		icon_rect.texture = skill.skill_resource.icon
	
	# 可以添加技能名称作为 tooltip
	tooltip_text = skill.skill_resource.skill_name
	
	# 显示按钮
	visible = true
	disabled = false

## 清空技能
func clear_skill() -> void:
	linked_skill = null
	if icon_rect:
		icon_rect.texture = null
	tooltip_text = ""
	visible = false  # 或者设置为半透明/禁用状态

## 更新冷却显示（可选，后续可以添加进度条等）
#func update_cooldown(remaining: float, total: float) -> void:
	#if remaining > 0:
		#disabled = true
		## 这里可以添加冷却遮罩动画
	#else:
		#disabled = false

## 按钮点击处理
func _on_pressed() -> void:
	if linked_skill:
		skill_button_clicked.emit(linked_skill, self)
