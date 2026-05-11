extends Control
class_name WeaponWheelSlot

## 武器轮盘上的一个槽位（Control 容器）。
## 父节点 **WeaponWheel** 会按扇形设置本节点的 `position`（左上角坐标）。
## 建议在编辑器中为每个槽设置 `custom_minimum_size`（例如 56×56），便于布局稳定。

@export_group("显示")
@export var slot_id: int = 0  ## 由 WeaponWheel 写入，用于回传选择结果（例如 WeaponManager 槽位）
@export var weapon_name: String = "":
	set(v):
		weapon_name = v
		_apply_name_label()
	get:
		return weapon_name

@export var weapon_icon: Texture2D:
	set(v):
		weapon_icon = v
		_apply_icon_texture()
	get:
		return weapon_icon


func _ready() -> void:
	_apply_icon_texture()
	_apply_name_label()


func _apply_icon_texture() -> void:
	var icon_rect := _find_first_texture_rect()
	if icon_rect == null:
		return
	icon_rect.texture = weapon_icon


func _apply_name_label() -> void:
	var label := _find_first_label()
	if label == null:
		return
	label.text = weapon_name if not weapon_name.is_empty() else "—"


func _find_first_texture_rect() -> TextureRect:
	for c in get_children():
		if c is TextureRect:
			return c as TextureRect
	return null


func _find_first_label() -> Label:
	for c in get_children():
		if c is Label:
			return c as Label
	return null


## 供外部（如 WeaponManager）在运行时切换图标。
func set_weapon_icon(tex: Texture2D) -> void:
	weapon_icon = tex


func set_slot_payload(id: int, name: String, icon: Texture2D) -> void:
	slot_id = id
	weapon_name = name
	weapon_icon = icon
	_apply_icon_texture()
	_apply_name_label()
