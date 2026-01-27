extends Panel

## UI节点
@onready var icon_rect: TextureRect = $SkillInfo/skillIcon
@onready var skill_name: Label = $SkillInfo/skillTitle
@onready var desc_label: RichTextLabel = $SkillInfo/skillDesc

# Skill Attribute
@onready var attr_vbox: VBoxContainer = $SkillInfo/attrVbox
@onready var damage_value: Label = $SkillInfo/attrVbox/damage/damage_value
@onready var attack_power_value: Label = $SkillInfo/attrVbox/attack_power/attack_power_value
@onready var cooldown_value: Label = $SkillInfo/attrVbox/cooldown/cooldown_value
@onready var range_value: Label = $SkillInfo/attrVbox/range/range_value

@onready var upgrade_btn: Button = $upgradeButton

## 动画配置
@export var animation_duration: float = 0.4
@export var slide_offset: float = 30.0

## 当前显示的技能
var current_skill: Skill = null
var original_y: float = 0.0

func _ready() -> void:
	# 记录原始位置
	original_y = position.y
	# 初始隐藏
	hide_panel()

## 显示技能信息
func show_skill_info(skill: Skill) -> void:
	if skill == null:
		hide_panel()
		return
	
	current_skill = skill
	
	# 更新UI内容
	_update_ui_content()
	
	# 播放显示动画
	_play_show_animation()

## 隐藏面板
func hide_panel() -> void:
	var tween = create_tween().set_parallel(true)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
	
	tween.tween_property(self, "position:y", original_y - slide_offset, animation_duration)
	tween.tween_property(self, "modulate:a", 0.0, animation_duration)
	
	tween.chain().tween_callback(func():
		visible = false
		current_skill = null
	)

## 更新UI内容
func _update_ui_content() -> void:
	var skill_res = current_skill.skill_resource
	var level = current_skill.current_level
	
	# 基础信息
	if icon_rect:
		icon_rect.texture = skill_res.icon
	
	if skill_name:
		skill_name.text = "%s (Lv.%d) " % [skill_res.skill_name, level]
	
	if desc_label:
		desc_label.text = skill_res.description
	
	# 属性数值
	if damage_value:
		damage_value.text = "%.0f " % current_skill.get_damage()
	
	if attack_power_value:
		attack_power_value.text = "%.0f " % current_skill.get_attack_power()
	
	if cooldown_value:
		cooldown_value.text = "%.1fs " % current_skill.get_cooldown()
	
	if range_value:
		range_value.text = "%.1fm " % current_skill.get_range()
	
	# 升级按钮状态
	if upgrade_btn:
		upgrade_btn.disabled = (level >= skill_res.max_level)
		upgrade_btn.text = "Upgrade" if level < skill_res.max_level else "Max Level"

## 播放显示动画
func _play_show_animation() -> void:
	visible = true
	modulate.a = 0.0
	position.y = original_y - slide_offset
	
	var tween = create_tween().set_parallel(true)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
	
	tween.tween_property(self, "position:y", original_y, animation_duration)
	tween.tween_property(self, "modulate:a", 1.0, animation_duration)
	

# --- 信号处理：点击升级 ---
func _on_upgrade_button_pressed() -> void:
	if not current_skill: return
	
	# 1. (重要) 检查外部资源（金币/技能点）
	# 这里假设你有一个 PlayerStats 单例或者类似的管理类
	# if not PlayerStats.has_enough_points(1):
	#     print("技能点不足！")
	#     return
	
	# 2. 执行升级
	# 调用 Skill.gd 的 level_up() 方法 
	var success = current_skill.level_up()
	
	if success:
		# 3. 扣除资源 (示例)
		# PlayerStats.consume_points(1)
		
		# 4. 刷新 UI 显示新等级的数据
		_update_ui_content()
		
		# 播放升级音效等
		print("技能升级成功！当前等级: ", current_skill.current_level)
	else:
		print("升级失败（可能已达最大等级）")


func _on_skill_attr_button_pressed() -> void:
	_swich_skill_content(false)


func _on_skill_desc_button_pressed() -> void:
	_swich_skill_content(true)
	
func _swich_skill_content(hideen: bool) -> void:
	if hideen:
		desc_label.visible = true
		attr_vbox.visible = false
	else:
		attr_vbox.visible = true
		desc_label.visible = false
