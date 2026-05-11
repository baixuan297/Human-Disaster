extends Control

@onready var _container: HBoxContainer = $SkillContainer


var _slot_buttons: Array[TextureButton] = []
var _slot_key_widgets: Array[Node] = []

const _SLOT_ACTIONS: Array[StringName] = [&"Skill1", &"Skill2", &"Skill3"]


func _ready() -> void:
	_collect_slots()
	_apply_pretty_style()
	_refresh_all()
	if SkillManager:
		if not SkillManager.skill_added.is_connected(_on_skills_changed):
			SkillManager.skill_added.connect(_on_skills_changed)
		if not SkillManager.skill_removed.is_connected(_on_skills_changed):
			SkillManager.skill_removed.connect(_on_skills_changed)
		if not SkillManager.skill_bar_changed.is_connected(_on_skills_changed):
			SkillManager.skill_bar_changed.connect(_on_skills_changed)


func _process(_delta: float) -> void:
	_update_cooldowns()


func _on_skills_changed(_arg = null) -> void:
	_refresh_all()


func _collect_slots() -> void:
	_slot_buttons.clear()
	_slot_key_widgets.clear()
	if _container == null:
		return
	for child in _container.get_children():
		if child is TextureButton:
			_slot_buttons.append(child)
			_slot_key_widgets.append(_find_key_widget(child))


func _find_key_widget(btn: Node) -> Node:
	# 兼容 skill_bar.tscn 中 ReferenceRect / ReferenceRect2 / ReferenceRect3 等命名
	# 以及未来你可能换成别的名字：只要挂了 key.gd（有 update_visual）就能找到
	for c in btn.get_children():
		if c != null and c.has_method("update_visual"):
			return c
	# 再兜底：递归找子节点里带 update_visual 的（Key.tscn 未来可能包一层容器）
	for c in btn.get_children():
		if c == null:
			continue
		for gc in c.get_children():
			if gc != null and gc.has_method("update_visual"):
				return gc
	return null


func _apply_pretty_style() -> void:
	# 背景卡片（直接给 HBoxContainer 加 stylebox，避免改 scene 结构）
	if _container == null:
		return
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.07, 0.09, 0.55)
	bg.border_color = Color(0.25, 0.85, 0.95, 0.18)
	bg.border_width_left = 1
	bg.border_width_right = 1
	bg.border_width_top = 1
	bg.border_width_bottom = 1
	bg.corner_radius_top_left = 18
	bg.corner_radius_top_right = 18
	bg.corner_radius_bottom_left = 18
	bg.corner_radius_bottom_right = 18
	bg.content_margin_left = 16
	bg.content_margin_right = 16
	bg.content_margin_top = 10
	bg.content_margin_bottom = 10
	_container.add_theme_stylebox_override("panel", bg)


func _refresh_all() -> void:
	_refresh_slot_icons_and_keys()
	_ensure_cooldown_widgets()
	_update_cooldowns()

func _refresh_slot_icons_and_keys() -> void:
	for i in range(_slot_buttons.size()):
		var btn := _slot_buttons[i]
		var skill: Skill = _get_skill_in_slot(i)
		if skill and skill.skill_resource and skill.skill_resource.icon:
			btn.texture_normal = skill.skill_resource.icon
			btn.modulate = Color(1, 1, 1, 1)
		else:
			# 空槽：降低透明度但仍保留按钮位
			btn.modulate = Color(1, 1, 1, 0.35)

		# 按键显示：从 InputMap 动态解析（用户在设置里改键后会自动更新）
		var key_widget := _slot_key_widgets[i] if i < _slot_key_widgets.size() else null
		if key_widget:
			var action := _resolve_action_name(_SLOT_ACTIONS[i]) if i < _SLOT_ACTIONS.size() else &""
			var label := _get_action_display(action)
			if key_widget.has_method("update_visual"):
				# key.gd
				key_widget.set("key_name", label)
				key_widget.call("update_visual")
			else:
				# 最少兼容：直接改子 Label
				var l := key_widget.get_node_or_null("Label") as Label
				if l:
					l.text = label


func _ensure_cooldown_widgets() -> void:
	for btn in _slot_buttons:
		var mask := _find_cooldown_mask(btn)
		var cd: Label = _find_cooldown_label(btn)
		if mask == null or cd == null:
			continue

		cd.visible = false
		# 确保遮罩在下、文字在上
		btn.move_child(mask, 0)
		btn.move_child(cd, btn.get_child_count() - 1)


func _update_cooldowns() -> void:
	for i in range(_slot_buttons.size()):
		var btn := _slot_buttons[i]
		var skill: Skill = _get_skill_in_slot(i)
		var mask := _find_cooldown_mask(btn)
		var label := _find_cooldown_label(btn)
		if mask == null or label == null:
			continue

		if skill == null:
			mask.visible = false
			label.visible = false
			continue

		var remaining: float = float(skill.cooldown_remaining)
		var total: float = maxf(float(skill.get_cooldown()), 0.001)
		if remaining <= 0.01:
			mask.visible = false
			label.visible = false
			continue

		mask.visible = true
		label.visible = true
		label.text = "%d" % int(ceil(remaining))

		# 简洁遮罩：从下往上盖住 (progress=1 时全盖)
		var progress := clampf(remaining / total, 0.0, 1.0)
		var h := btn.size.y * progress
		mask.offset_top = btn.size.y - h


func _find_cooldown_label(btn: TextureButton) -> Label:
	var node := btn.get_node_or_null("CD")
	if node is Label:
		return node as Label
	return null


func _find_cooldown_mask(btn: TextureButton) -> ColorRect:
	var node := btn.get_node_or_null("CDMask")
	if node is ColorRect:
		return node as ColorRect
	return null


func _get_skill_in_slot(slot_index: int) -> Skill:
	if SkillManager == null:
		return null
	if slot_index < 0 or slot_index >= SkillManager.skill_bar.size():
		return null
	var s: Variant = SkillManager.skill_bar[slot_index]
	return s as Skill


func _get_action_display(action: StringName) -> String:
	if action.is_empty():
		return ""
	if not InputMap.has_action(action):
		return String(action)
	var events := InputMap.action_get_events(action)
	for e in events:
		if e is InputEventKey:
			var ek := e as InputEventKey
			# Godot 里经常是 keycode=0 但 physical_keycode 有值（例如通过物理键位绑定）
			if ek.physical_keycode != 0:
				return OS.get_keycode_string(ek.physical_keycode)
			if ek.keycode != 0:
				return OS.get_keycode_string(ek.keycode)
			if ek.key_label != 0:
				return OS.get_keycode_string(ek.key_label)
			if ek.unicode != 0:
				return String.chr(ek.unicode)
		elif e is InputEventMouseButton:
			var mb := e as InputEventMouseButton
			return "M%d" % int(mb.button_index)
	# 若用户清空了绑定，显示 action 名避免空白
	return String(action)


func _resolve_action_name(action: StringName) -> StringName:
	# 兼容用户设置里可能写成 skill1 / SKILL1 等大小写
	if action.is_empty():
		return &""
	if InputMap.has_action(action):
		return action
	var s := String(action)
	var lower := StringName(s.to_lower())
	if InputMap.has_action(lower):
		return lower
	var upper := StringName(s.to_upper())
	if InputMap.has_action(upper):
		return upper
	return action
