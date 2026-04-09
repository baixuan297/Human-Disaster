extends Control
class_name InventoryUI

# Top
@onready var bag_name: Label = $Panel/Top/HBoxContainer/bagName
@onready var text_edit: TextEdit = $Panel/Top/HBoxContainer/TextEdit

# Mid
@onready var grid_container: GridContainer = $Panel/Mid/HBoxContainer/ScrollContainer/GridContainer
@onready var item_info_name: Label = $Panel/Mid/HBoxContainer/Item_info/itemInfo_name
@onready var item_info_type: Label = $Panel/Mid/HBoxContainer/Item_info/itemInfo_type
@onready var item_info_use: Label = $Panel/Mid/HBoxContainer/Item_info/itemInfo_use
@onready var item_info_desc: Label = $Panel/Mid/HBoxContainer/Item_info/itemInfo_desc
@onready var item_info_icon: TextureRect = $Panel/Mid/HBoxContainer/Item_info/itemInfo_icon
@onready var item_info: VBoxContainer = $Panel/Mid/HBoxContainer/Item_info

# ItemDelete
var item_delete_scene := preload("res://addons/xuanBag/scene/item_delete.tscn")
var item_delete : Control

# UI状态
var item_slots: Array[ItemSlot] = []
var selected_slot_index: int = -1
var inventory_manager: Node

func _ready():
	# **
	PauseManager.open_inventory()
	
	# 添加到组中方便调用
	add_to_group("inventory_ui")
	inventory_manager = InventoryManager
	
	setup_slots()
	connect_signals()
	_wire_bag_type_buttons()
	
	# 初始化显示武器背包
	inventory_manager.switch_bag(InventoryManager.BAG_WEAPON)
	
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup_slots():
	# 清除所有格子
	for child in grid_container.get_children():
		child.queue_free()
	
	item_slots.clear()
	
	# 创建物品格
	for i in range(inventory_manager.max_slots):
		var slot = preload("res://addons/xuanBag/scene/item_slot.tscn").instantiate()
		slot.setup(i)
		grid_container.add_child(slot)
		item_slots.append(slot)

		# 连接操作信号
		slot.item_clicked.connect(_on_item_clicked)
		slot.item_right_clicked.connect(_on_item_right_clicked)
		slot.item_dropped.connect(_on_item_dropped)

func connect_signals() -> void:
	if not inventory_manager:
		return
	# inventory_changed 做完整 update_display，不再单独连 item_added/item_removed
	# 旧代码 _on_item_added/_on_item_removed 用原始 slot_index 更新 UI 槽，
	# 但 UI 展示的是按类型筛选后的列表，index 不对应，会导致刷错格子。
	if not inventory_manager.inventory_changed.is_connected(_on_inventory_changed):
		inventory_manager.inventory_changed.connect(_on_inventory_changed)
	if not inventory_manager.bag_changed.is_connected(_on_bag_changed):
		inventory_manager.bag_changed.connect(_on_bag_changed)


func _wire_bag_type_buttons() -> void:
	var bc := get_node_or_null("Panel/Bottom/BagContainer")
	if bc == null:
		push_warning("[InventoryUI] 未找到 Panel/Bottom/BagContainer，底部分类按钮无法绑定")
		return
	_try_connect_pressed(bc, InventoryManager.BAG_WEAPON, _on_weapon_pressed)
	_try_connect_pressed(bc, InventoryManager.BAG_POTION, _on_potion_pressed)
	_try_connect_pressed(bc, InventoryManager.BAG_MATERIAL, _on_material_pressed)
	_try_connect_pressed(bc, InventoryManager.BAG_FOOD, _on_food_pressed)
	_try_connect_pressed(bc, InventoryManager.BAG_QUEST, _on_quest_pressed)
	_try_connect_pressed(bc, InventoryManager.BAG_TOOL, _on_tool_pressed)


func _try_connect_pressed(root: Node, child_name: String, handler: Callable) -> void:
	var btn := root.get_node_or_null(child_name)
	if btn is BaseButton:
		if not btn.pressed.is_connected(handler):
			btn.pressed.connect(handler)
		btn.focus_mode = Control.FOCUS_NONE
	else:
		push_warning("[InventoryUI] 底栏缺少按钮: %s" % child_name)

func _on_inventory_changed() -> void:
	update_display()


func _on_bag_changed(bag_type: String) -> void:
	bag_name.text = "Bag / %s" % bag_type
	_highlight_selected_bag(bag_type)
	_clear_search_bar_silently()
	# 不再在这里调 update_display()——switch_bag 之后的 inventory_changed 会触发


func _clear_search_bar_silently() -> void:
	if text_edit == null:
		return
	if text_edit.text_changed.is_connected(_on_text_edit_text_changed):
		text_edit.text_changed.disconnect(_on_text_edit_text_changed)
	text_edit.text = ""
	if not text_edit.text_changed.is_connected(_on_text_edit_text_changed):
		text_edit.text_changed.connect(_on_text_edit_text_changed)

func _on_item_clicked(slot: ItemSlot):
	selected_slot_index = slot.slot_index
	var item = _get_displayed_item(slot.slot_index)
	_update_item_info(item)

func _on_item_right_clicked(slot: ItemSlot):
	# 获取显示列表中的物品对应的索引
	var display_items = inventory_manager.get_current_bag_items()
	if slot.slot_index < display_items.size():
		var item = display_items[slot.slot_index]
		# 找到这个物品在背包中的位置
		var actual_index = inventory_manager.find_item_index(item)
		if actual_index >= 0:
			# 使用物品
			inventory_manager.use_item(actual_index)

func _on_item_dropped(from_slot: ItemSlot, to_slot: ItemSlot) -> void:
	var display_items = inventory_manager.get_current_bag_items()
	if from_slot.slot_index >= display_items.size():
		return

	var from_item: InventoryItem = display_items[from_slot.slot_index]
	var actual_from = inventory_manager.find_item_index(from_item)
	if actual_from < 0:
		return

	var actual_to := -1
	if to_slot.slot_index < display_items.size():
		var to_item: InventoryItem = display_items[to_slot.slot_index]
		if to_item:
			actual_to = inventory_manager.find_item_index(to_item)

	if actual_to < 0:
		actual_to = inventory_manager.find_empty_slot()
	if actual_to < 0:
		return

	inventory_manager.move_item(actual_from, actual_to)

# 背包类型按钮（与 InventoryManager 常量一致，避免拼写漂移）
func _on_weapon_pressed() -> void:
	inventory_manager.switch_bag(InventoryManager.BAG_WEAPON)

func _on_potion_pressed() -> void:
	inventory_manager.switch_bag(InventoryManager.BAG_POTION)

func _on_material_pressed() -> void:
	inventory_manager.switch_bag(InventoryManager.BAG_MATERIAL)

func _on_food_pressed() -> void:
	inventory_manager.switch_bag(InventoryManager.BAG_FOOD)

func _on_quest_pressed() -> void:
	inventory_manager.switch_bag(InventoryManager.BAG_QUEST)

func _on_tool_pressed() -> void:
	inventory_manager.switch_bag(InventoryManager.BAG_TOOL)

# 搜索物品
func _on_text_edit_text_changed():
	var search_text = text_edit.text
	inventory_manager.set_name_filter(search_text)

# 物品排序功能
func _on_classify_item_selected(index: int):
	match index:
		0:
			inventory_manager.set_sort_mode(InventoryManager.SortMode.BY_RARITY)
		1:
			inventory_manager.set_sort_mode(InventoryManager.SortMode.BY_NAME)
		_:
			inventory_manager.set_sort_mode(InventoryManager.SortMode.NONE)

func _on_sort_pressed():
	# 切换排序顺序
	inventory_manager.toggle_sort_order()

# 删除物品
func _on_delete_pressed():
	item_delete = item_delete_scene.instantiate()
	add_child(item_delete)
	item_delete.deleted.connect(_on_delete_item_pressed)
	item_delete.cancelled.connect(_on_cancel_pressed)

func _on_delete_item_pressed() -> void:
	
	if selected_slot_index >= 0:
		# 获取当前背包物品
		var display_items = inventory_manager.get_current_bag_items()
		if selected_slot_index < display_items.size():
			# 获取物品
			var item = display_items[selected_slot_index]
			var actual_index = inventory_manager.find_item_index(item)
			if actual_index >= 0:
				# 判断物品位置后，删除物品
				inventory_manager.delete_item(actual_index)
				# 重置选中坐标
				selected_slot_index = -1
				# 更新为无
				#await get_tree().create_timer(1.0).timeout
				_update_item_info(null)
				item_delete.queue_free()

func _on_cancel_pressed() -> void:
	item_delete.queue_free()

func _on_close_button_pressed():
	_cleanup()
	PauseManager.close_inventory()
	UiManager.close_current_ui()


func _cleanup() -> void:
	visible = false
	ItemSlot.current_selected_slot = null

func toggle_visibility():
	visible = not visible

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		ItemSlot.current_selected_slot = null


func _input(event):
	if event.is_action_pressed("ui_cancel") and visible:
		PauseManager.close_inventory()

func update_display():
	# 获取当前应该显示的物品列表
	var display_items = inventory_manager.get_current_bag_items()
	
	# 清空所有槽位
	for i in range(item_slots.size()):
		item_slots[i].set_item(null)
	
	# 显示物品
	for i in range(display_items.size()):
		if i < item_slots.size():
			item_slots[i].set_item(display_items[i])

func _update_item_info(item: InventoryItem) -> void:
	if item and item.data:
		item_info.visible = true
		var data = item.data
		item_info_icon.texture = data.icon
		item_info_name.text = data.name
		var item_type_name: String = ItemData.ItemType.keys()[data.item_type]
		item_info_type.text = item_type_name
		item_info_desc.text = data.description
		# 物品使用说明
		#if item_info_use:
			#item_info_use.text = data.get("use_description", "")
	else:
		item_info.visible = false

func _highlight_selected_bag(bag_type: String) -> void:
	var root := get_node_or_null("Panel/Bottom/BagContainer")
	if root == null:
		return
	var names: Array[String] = [
		InventoryManager.BAG_WEAPON,
		InventoryManager.BAG_POTION,
		InventoryManager.BAG_MATERIAL,
		InventoryManager.BAG_FOOD,
		InventoryManager.BAG_QUEST,
		InventoryManager.BAG_TOOL,
	]
	for n in names:
		var cr := root.get_node_or_null(n + "/ColorRect") as ColorRect
		if cr:
			cr.color.a = 0.2
	var sel := root.get_node_or_null(bag_type + "/ColorRect") as ColorRect
	if sel:
		sel.color.a = 1.0

func _get_displayed_item(slot_index: int) -> InventoryItem:
	# 获取当前显示的物品
	var display_items = inventory_manager.get_current_bag_items()
	if slot_index >= 0 and slot_index < display_items.size():
		return display_items[slot_index]
	return null


func _on_button_pressed() -> void:
	print("im worling")
