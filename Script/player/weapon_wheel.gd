extends Control
class_name WeaponWheel

## 右下角常驻武器 HUD：三槽沿扇形排布，仅负责展示与当前槽高亮（不处理 Tab 展开/鼠标选择）。

## 圆弧半径（像素）：槽位 **中心** 落在此半径上。
@export_group("扇形布局")
@export var wheel_radius: float = 140.0
## 圆心相对本控件 **本地坐标右下角** `(size.x, size.y)` 的偏移；负 x 向左、负 y 向上（屏幕内）。
@export var center_offset_from_bottom_right: Vector2 = Vector2(-72.0, -72.0)
@export_range(0.0, 360.0, 0.1, "or_greater") var angle_start_deg: float = 180.0
@export_range(0.0, 360.0, 0.1, "or_greater") var angle_end_deg: float = 270.0

## 若非空：只排布 `name.begins_with(child_name_prefix)` 的直接子节点（避免同层放背景板）。
## 固定三槽场景请设为 `Weapon`，子节点命名为 **Weapon1 / Weapon2 / Weapon3**（徒手 / 副武器 / 主武器）。
@export var child_name_prefix: String = "Weapon"

@export_group("外观")
@export var selected_scale: float = 1.15
@export var normal_scale: float = 1.00
@export var dim_modulate: Color = Color(0.65, 0.65, 0.65, 0.85)
@export var bright_modulate: Color = Color(1.0, 1.0, 1.0, 1.0)

var _selected_slot_id: int = WeaponManager.SLOT_HAND


func _ready() -> void:
	resized.connect(_on_wheel_resized)
	child_entered_tree.connect(_on_child_tree_changed)
	child_exiting_tree.connect(_on_child_tree_changed)
	visible = true
	set_process(false)
	call_deferred("layout_slots")


func _on_wheel_resized() -> void:
	layout_slots()


func _on_child_tree_changed(_node: Node) -> void:
	call_deferred("layout_slots")


func layout_slots() -> void:
	var slots := _collect_slot_controls()
	var center := _arc_center_in_local()
	var start_rad := deg_to_rad(angle_start_deg)
	var end_rad := deg_to_rad(angle_end_deg)
	var count := slots.size()
	if count == 0:
		return
	for i in range(count):
		var angle := _angle_for_index(i, count, start_rad, end_rad)
		var dir := Vector2(cos(angle), sin(angle))
		var ctrl: Control = slots[i]
		var half := _half_extent(ctrl)
		ctrl.set_position(center + dir * wheel_radius - half)


## 固定 3 项，顺序：**Weapon1=徒手、Weapon2=副武器、Weapon3=主武器**。
## 每项：`{ "slot_id": int, "name": String, "icon": Texture2D }`
func set_items(items: Array[Dictionary]) -> void:
	if items.size() != 3:
		push_warning("[WeaponWheel] set_items 需要 3 项（徒手/副武器/主武器），当前=%d" % items.size())
		return
	_ensure_slot_count(3)
	var slots := _collect_slot_controls()
	for i in range(mini(3, slots.size())):
		var ctrl := slots[i]
		ctrl.visible = true
		var d := items[i]
		var sid := int(d.get("slot_id", 0))
		var nm := str(d.get("name", ""))
		var ic: Texture2D = d.get("icon")
		if ctrl is WeaponWheelSlot:
			(ctrl as WeaponWheelSlot).set_slot_payload(sid, nm, ic)
		else:
			_try_set_payload_on_control(ctrl, sid, nm, ic)
	layout_slots()


func set_highlight_slot(slot_id: int) -> void:
	_selected_slot_id = slot_id
	var slots := _collect_slot_controls()
	var selected := _find_slot_by_id(slots, slot_id)
	if selected == null:
		selected = _find_slot_by_id(slots, WeaponManager.SLOT_HAND)
	if selected != null:
		_apply_highlight_immediate(slots, selected)


func _apply_highlight_immediate(all_slots: Array[Control], selected: WeaponWheelSlot) -> void:
	for ctrl in all_slots:
		if ctrl == null or not ctrl.visible:
			continue
		var is_sel := (ctrl is WeaponWheelSlot) and ((ctrl as WeaponWheelSlot).slot_id == selected.slot_id)
		ctrl.scale = Vector2.ONE * (selected_scale if is_sel else normal_scale)
		ctrl.modulate = bright_modulate if is_sel else dim_modulate


func _ensure_slot_count(count: int) -> void:
	var slots := _collect_slot_controls()
	if slots.size() >= count:
		return
	if slots.is_empty():
		return
	var template: Control = slots[0]
	while slots.size() < count:
		var dup := template.duplicate() as Control
		add_child(dup)
		slots.append(dup)


func _try_set_payload_on_control(ctrl: Control, slot_id: int, name: String, icon: Texture2D) -> void:
	ctrl.set_meta("slot_id", slot_id)
	for c in ctrl.get_children():
		if c is TextureRect and icon != null:
			(c as TextureRect).texture = icon
		if c is Label and not name.is_empty():
			(c as Label).text = name


func _angle_for_index(index: int, total: int, start_rad: float, end_rad: float) -> float:
	if total <= 1:
		return lerpf(start_rad, end_rad, 0.5)
	return lerpf(start_rad, end_rad, float(index) / float(total - 1))


func _arc_center_in_local() -> Vector2:
	return Vector2(size.x, size.y) + center_offset_from_bottom_right


func _collect_slot_controls() -> Array[Control]:
	var out: Array[Control] = []
	for child in get_children():
		if not (child is Control):
			continue
		if not child_name_prefix.is_empty() and not str(child.name).begins_with(child_name_prefix):
			continue
		out.append(child as Control)
	out.sort_custom(func(a: Control, b: Control) -> bool:
		return _weapon_slot_sort_key(str(a.name)) < _weapon_slot_sort_key(str(b.name))
	)
	return out


func _weapon_slot_sort_key(node_name: String) -> int:
	match node_name:
		"Weapon1":
			return 0
		"Weapon2":
			return 1
		"Weapon3":
			return 2
		_:
			return 99


func _find_slot_by_id(slots: Array[Control], slot_id: int) -> WeaponWheelSlot:
	for ctrl in slots:
		if ctrl is WeaponWheelSlot and (ctrl as WeaponWheelSlot).slot_id == slot_id:
			return ctrl as WeaponWheelSlot
	return null


func _half_extent(ctrl: Control) -> Vector2:
	var s := ctrl.size
	if s.x <= 0.0 or s.y <= 0.0:
		s = ctrl.get_combined_minimum_size()
	if s.x <= 0.0 or s.y <= 0.0:
		s = Vector2(48.0, 48.0)
	return s * 0.5
