## 技能UI主控制器 - 负责协调按钮和信息面板
extends Control

## 动画配置
@export var button_animation_duration: float = 0.3
@export var animation_curve: Tween.TransitionType = Tween.TRANS_BACK 
@export var animation_ease: Tween.EaseType = Tween.EASE_OUT

## 节点引用
@onready var skill_tree_button: Button = $skillTreeButton
@onready var skill_info_panel: Panel = $SkillInfoBg

## 技能按钮容器（或者直接引用）
@onready var skill_buttons_node: Control = $skill_buttons_node

## 数据引用
var character: Node3D  # 角色引用
var skill_manager: SkillManager  # 技能管理器引用

## 运行时数据
var skill_buttons: Array[SkillButton] = []
var is_expanded: bool = false
var current_selected_button: SkillButton = null

func _ready() -> void:
	# 收集所有技能按钮
	_collect_skill_buttons()
	
	# 初始化按钮状态
	_initialize_buttons()
	
	var player = get_tree().get_first_node_in_group("Player")
	setup_character(player)


## 设置角色引用（从外部调用）
func setup_character(_char: Node3D) -> void:
	if not _char:
		return
	character = _char
	
	# 获取角色的技能管理器
	skill_manager = character.get_node_or_null("SkillManager")
	
	if skill_manager == null:
		push_error("角色没有 SkillManager 节点!")
		return
	
	# 加载角色技能到按钮
	_load_character_skills()

## 收集技能按钮
func _collect_skill_buttons() -> void:
	skill_buttons.clear()
	
	var search_parent = skill_buttons_node if skill_buttons_node else self
	
	for child in search_parent.get_children():
		if child is SkillButton:
			skill_buttons.append(child)
			# 连接按钮信号
			child.skill_button_clicked.connect(_on_skill_button_clicked)
		elif child is Button and child != skill_tree_button:
			# 如果是普通按钮，可以尝试转换（但建议使用 SkillButton）
			push_warning("发现普通 Button，建议改用 SkillButton: " + child.name)

## 初始化按钮状态
func _initialize_buttons() -> void:
	for btn in skill_buttons:
		# 保存目标位置
		btn.set_meta("target_pos", btn.position)
		
		# 初始状态：在主按钮中心
		if skill_tree_button:
			btn.position = skill_tree_button.position + skill_tree_button.size / 2 - btn.size / 2
		
		btn.scale = Vector2.ZERO
		btn.modulate.a = 0.0
		btn.visible = false

## 加载角色技能到按钮
func _load_character_skills() -> void:
	if skill_manager == null:
		return
	print_debug("正确加载技能到技能面板中")
	var available_skills = skill_manager.skills.values()
	
	# 遍历按钮，分配技能
	for i in range(skill_buttons.size()):
		var btn = skill_buttons[i]
		
		if i < available_skills.size():
			# 有对应技能，设置数据
			btn.setup_skill(available_skills[i])
		else:
			# 没有技能，清空/隐藏
			btn.clear_skill()

## 展开/收起按钮动画
func _animate_buttons() -> void:
	var tween = create_tween().set_parallel(true)
	
	for btn in skill_buttons:
		# 只动画有技能的按钮
		if btn.linked_skill == null and not is_expanded:
			continue
		
		var target_pos: Vector2
		var target_scale: Vector2
		var target_alpha: float
		
		if is_expanded:
			target_pos = btn.get_meta("target_pos")
			target_scale = Vector2.ONE
			target_alpha = 1.0
			btn.visible = true
		else:
			if skill_tree_button:
				target_pos = skill_tree_button.position + skill_tree_button.size / 2 - btn.size / 2
			else:
				target_pos = btn.position
			target_scale = Vector2.ZERO
			target_alpha = 0.0
		
		tween.tween_property(btn, "position", target_pos, button_animation_duration)\
			.set_trans(animation_curve).set_ease(animation_ease)
		
		tween.tween_property(btn, "scale", target_scale, button_animation_duration)\
			.set_trans(animation_curve).set_ease(animation_ease)
		
		tween.tween_property(btn, "modulate:a", target_alpha, button_animation_duration * 0.8)
	
	# 收起时隐藏信息面板
	if not is_expanded:
		if skill_info_panel and skill_info_panel.has_method("hide_panel"):
			skill_info_panel.hide_panel()
		current_selected_button = null
		
		# 动画结束后隐藏按钮
		tween.chain().tween_callback(func():
			if not is_expanded:
				for btn in skill_buttons:
					if btn.linked_skill == null:
						btn.visible = false
		)

## 主按钮点击
func _on_skill_tree_button_pressed() -> void:
	is_expanded = !is_expanded
	_animate_buttons()

## 技能按钮点击
func _on_skill_button_clicked(skill: Skill, button: SkillButton) -> void:
	# 如果点击的是同一个按钮，切换显示/隐藏
	if current_selected_button == button:
		if skill_info_panel and skill_info_panel.has_method("hide_panel"):
			skill_info_panel.hide_panel()
		current_selected_button = null
	else:
		# 显示新技能信息
		if skill_info_panel and skill_info_panel.has_method("show_skill_info"):
			skill_info_panel.show_skill_info(skill)
		current_selected_button = button

## 刷新显示（当技能升级等情况）
func refresh_ui() -> void:
	if skill_manager:
		_load_character_skills()
	
	# 如果当前有选中的技能，刷新信息面板
	if current_selected_button and current_selected_button.linked_skill:
		if skill_info_panel and skill_info_panel.has_method("show_skill_info"):
			skill_info_panel.show_skill_info(current_selected_button.linked_skill)
