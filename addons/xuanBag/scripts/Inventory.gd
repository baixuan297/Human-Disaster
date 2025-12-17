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
	
	# 初始化显示武器背包
	inventory_manager.switch_bag("Weapon")
	
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

func connect_signals():
	# 连接到背包管理器的信号
	if inventory_manager:
		inventory_manager.item_added.connect(_on_item_added)
		inventory_manager.item_removed.connect(_on_item_removed)
		inventory_manager.inventory_changed.connect(_on_inventory_changed)
		inventory_manager.bag_changed.connect(_on_bag_changed)

func _on_inventory_changed():
	update_display()

func _on_item_added(item: InventoryItem, slot_index: int):
	if slot_index < item_slots.size():
		#var actual_item = inventory_manager.get_item(slot_index)
		item_slots[slot_index].set_item(item)

func _on_item_removed(item: InventoryItem, slot_index: int):
	if slot_index < item_slots.size():
		#var actual_item = inventory_manager.get_item(slot_index)
		item_slots[slot_index].set_item(item)

func _on_bag_changed(bag_type: String):
	# 更新标题
	bag_name.text = "Bag / %s" % bag_type
	# 高亮当前选中的背包
	_highlight_selected_bag(bag_type)
	# 清空搜索框
	text_edit.text = ""
	# 更新显示
	update_display()

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

func _on_item_dropped(from_slot: ItemSlot, to_slot: ItemSlot):
	# 获取显示列表
	var display_items = inventory_manager.get_current_bag_items()
	
	# 获取实际的物品索引
	if from_slot.slot_index < display_items.size() and to_slot.slot_index < display_items.size():
		var from_item = display_items[from_slot.slot_index]
		var to_item = display_items[to_slot.slot_index] if to_slot.slot_index < display_items.size() else null
		
		var actual_from = inventory_manager.find_item_index(from_item)
		var actual_to = inventory_manager.find_item_index(to_item) if to_item else -1
		
		if actual_from >= 0 and actual_to >= 0:
			inventory_manager.move_item(actual_from, actual_to)

# 背包类型按钮
func _on_weapon_pressed():
	inventory_manager.switch_bag("Weapon")

func _on_potion_pressed():
	inventory_manager.switch_bag("Potion")

func _on_material_pressed():
	inventory_manager.switch_bag("Material")

func _on_food_pressed():
	inventory_manager.switch_bag("Food")

func _on_quest_pressed():
	inventory_manager.switch_bag("Quest")

func _on_tool_pressed():
	inventory_manager.switch_bag("Tool")

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
	visible = false
	PauseManager.close_inventory()
	UiManager.close_current_ui()

func toggle_visibility():
	visible = not visible

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

func _update_item_info(item: InventoryItem):
	if item:
		item_info.visible = true
		var data = item.data
		item_info_icon.texture = data.icon
		item_info_name.text = data.name
		var item_type_name = ItemData.ItemType.keys()[data.item_type]
		item_info_type.text = item_type_name
		item_info_desc.text = data.description
		# 物品使用说明
		#if item_info_use:
			#item_info_use.text = data.get("use_description", "")
	else:
		item_info.visible = false

func _highlight_selected_bag(bag_type: String):
	# 重置所有背包的选中颜色
	for node in get_tree().get_nodes_in_group("bagSelectColor"):
		if node is ColorRect:
			node.color.a = 0.2
	
	# 高亮当前选中的背包
	var node_path = "Panel/Bottom/BagContainer/%s/ColorRect" % bag_type
	if has_node(node_path):
		var rect = get_node(node_path) as ColorRect
		if rect:
			rect.color.a = 1.0

func _get_displayed_item(slot_index: int) -> InventoryItem:
	# 获取当前显示的物品
	var display_items = inventory_manager.get_current_bag_items()
	if slot_index >= 0 and slot_index < display_items.size():
		return display_items[slot_index]
	return null
