extends Node 

signal item_added(item: InventoryItem, slot_index: int)
signal item_removed(item: InventoryItem, slot_index: int)
signal item_used(item: InventoryItem)
signal inventory_changed
signal bag_changed(bag_type: String)

@export var max_slots: int = 60
@onready var item_database: ItemDatabase

var items: Array[InventoryItem] = []
var current_bag_type: String = "WEAPON"
var current_filter_name: String = ""
var current_sort_mode: SortMode = SortMode.NONE
# true为正序，false为倒序
var current_sort_order: bool = true

enum SortMode {
	NONE,
	BY_RARITY,
	BY_NAME
}

func _ready():
	item_database = ItemDatabase.new()
	add_child(item_database)
	
	# 初始化背包槽位
	items.resize(max_slots)

func add_item(item_data: ItemData, quantity: int = 1) -> bool:
	var remaining_quantity = quantity
	
	# 首先尝试堆叠到已有物品
	for i in range(max_slots):
		if items[i] and items[i].data.id == item_data.id:
			var available_space = item_data.max_stack - items[i].quantity
			if available_space > 0:
				var amount_to_add = min(available_space, remaining_quantity)
				items[i].quantity += amount_to_add
				remaining_quantity -= amount_to_add
				item_added.emit(items[i], i)
				
				if remaining_quantity <= 0:
					inventory_changed.emit()
					return true
	
	# 如果还有剩余，放入空槽位
	while remaining_quantity > 0:
		var empty_slot = find_empty_slot()
		if empty_slot == -1:
			inventory_changed.emit()
			return false  # 背包已满
		
		var amount_to_add = min(item_data.max_stack, remaining_quantity)
		var new_item = InventoryItem.new(item_data, amount_to_add)
		items[empty_slot] = new_item
		remaining_quantity -= amount_to_add
		item_added.emit(new_item, empty_slot)
		
	inventory_changed.emit()
	return true
	
# 使用字符串ID添加物品
func add_item_by_id(item_id: String, quantity: int = 1) -> bool:
	var item_data = item_database.get_item_data(item_id)
	if item_data:
		return add_item(item_data, quantity)
	else:
		print("物品不存在: ", item_id)
		return false

# 使用数字ID添加物品
func add_item_by_numeric_id(item_id: int, quantity: int = 1) -> bool:
	var item_data = item_database.get_item_data_by_id(item_id)
	if item_data:
		return add_item(item_data, quantity)
	else:
		print("物品不存在，ID: ", item_id)
		return false

func remove_item(slot_index: int, quantity: int) -> bool:
	if slot_index < 0 or slot_index >= max_slots or not items[slot_index]:
		return false
	var item = items[slot_index]
	if item.quantity < quantity:
		return false
	
	item.quantity -= quantity
	item_removed.emit(item, slot_index)
	
	if item.quantity <= 0:
		items[slot_index] = null
	
	inventory_changed.emit()
	return true

func delete_item(slot_index: int):
	items[slot_index] = null
	inventory_changed.emit()
	
func move_item(from_slot: int, to_slot: int) -> bool:
	if from_slot < 0 or from_slot >= max_slots or to_slot < 0 or to_slot >= max_slots:
		return false
	
	if from_slot == to_slot:
		return true
	
	var from_item = items[from_slot]
	var to_item = items[to_slot]
	
	if not from_item:
		return false
	
	# 如果目标槽位为空，直接移动
	if not to_item:
		items[to_slot] = from_item
		items[from_slot] = null
		inventory_changed.emit()
		return true
	
	# 如果可以堆叠
	if from_item.can_stack_with(to_item):
		var remaining = from_item.stack_with(to_item)
		if remaining <= 0:
			items[from_slot] = null
		else:
			from_item.quantity = remaining
		inventory_changed.emit()
		return true
	
	# 交换位置
	items[from_slot] = to_item
	items[to_slot] = from_item
	inventory_changed.emit()
	return true

func find_empty_slot() -> int:
	for i in range(max_slots):
		if not items[i]:
			return i
	return -1

func has_item(item_id: String, quantity: int = 1) -> bool:
	var total_quantity = 0
	for item in items:
		if item and item.data.id == item_id:
			total_quantity += item.quantity
			if total_quantity >= quantity:
				return true
	return false

func use_item(slot_index: int) -> bool:
	var item = get_item(slot_index)
	if not item:
		return false
	
	item_used.emit(item)
	
	# 材料和任务物品使用后减少数量
	if item.data.item_type == ItemData.ItemType.MATERIAL or item.data.item_type == ItemData.ItemType.QUEST:
		return remove_item(slot_index, 1)
	
	return true

func clear():
	items.clear()
	items.resize(max_slots)
	inventory_changed.emit()

func get_item(slot_index: int) -> InventoryItem:
	if slot_index < 0 or slot_index >= max_slots:
		return null
	return items[slot_index]

# 获取所有物品
func get_all_items() -> Array[InventoryItem]:
	var result: Array[InventoryItem] = []
	for item in items:
		if item:
			result.append(item)
	return result

# 根据稀有度获取物品
func get_items_of_rarity(item_rarity: ItemData.ItemRarity) -> Array[InventoryItem]:
	var result: Array[InventoryItem] = []
	for item in items:
		if item and item.data.rarity == item_rarity:
			result.append(item)
	return result

# 根据类型获取物品
func get_items_of_type(item_type: ItemData.ItemType) -> Array[InventoryItem]:
	var result: Array[InventoryItem] = []
	for item in items:
		if item and item.data.item_type == item_type:
			result.append(item)
	return result

# 根据名称搜索物品
func get_items_by_name(item_name: String) -> Array[InventoryItem]:
	var result: Array[InventoryItem] = []
	if item_name.is_empty():
		return get_items_of_type(_get_item_type_from_string(current_bag_type))
	
	for item in items:
		if item and (item.data.name == item_name or item.data.name.contains(item_name)):
			result.append(item)
	return result

# 获取当前背包的物品 考虑过滤和排序
func get_current_bag_items() -> Array[InventoryItem]:
	var result: Array[InventoryItem] = []
	
	# 先根据背包类型获取物品
	if not current_filter_name.is_empty():
		# 如果有名称过滤，就搜索
		result = get_items_by_name(current_filter_name)
	else:
		# 否则按类型获取
		var item_type = _get_item_type_from_string(current_bag_type)
		result = get_items_of_type(item_type)
	
	# 应用排序
	if current_sort_mode != SortMode.NONE:
		result = _apply_sorting(result)
	
	return result

# 切换背包类型
func switch_bag(bag_type: String):
	current_bag_type = bag_type.to_upper()
	# 切换背包时清空搜索
	current_filter_name = "" 
	bag_changed.emit(bag_type)
	inventory_changed.emit()

# 设置名称过滤
func set_name_filter(filter_text: String):
	current_filter_name = filter_text
	inventory_changed.emit()

# 设置排序模式
func set_sort_mode(mode: SortMode):
	current_sort_mode = mode
	inventory_changed.emit()

# 切换排序顺序
func toggle_sort_order():
	current_sort_order = !current_sort_order
	inventory_changed.emit()

# 根据传入的字符串来返还数据类型
func _get_item_type_from_string(type_string: String) -> ItemData.ItemType:
	match type_string.to_upper():
		"WEAPON":
			return ItemData.ItemType.WEAPON
		"POTION":
			return ItemData.ItemType.POTION
		"MATERIAL":
			return ItemData.ItemType.MATERIAL
		"FOOD":
			return ItemData.ItemType.FOOD
		"QUEST":
			return ItemData.ItemType.QUEST
		"TOOL":
			return ItemData.ItemType.TOOL
		_:
			return ItemData.ItemType.WEAPON

# 应用排序
func _apply_sorting(items_list: Array[InventoryItem]) -> Array[InventoryItem]:
	var sorted_list = items_list.duplicate()
	
	match current_sort_mode:
		SortMode.BY_RARITY:
			sorted_list.sort_custom(_compare_items_by_rarity)
		SortMode.BY_NAME:
			sorted_list.sort_custom(_compare_items_by_name)
	
	if not current_sort_order:
		sorted_list.reverse()
	
	return sorted_list

func _compare_items_by_name(a: InventoryItem, b: InventoryItem) -> bool:
	if a == null or b == null:
		return false
	
	return a.data.name < b.data.name
	
func _compare_items_by_rarity(a: InventoryItem, b: InventoryItem) -> bool:
	if a == null or b == null:
		return false
	
	# 如果稀有度相同按照名字排序
	if a.data.rarity == b.data.rarity:
		return a.data.name < b.data.name
	return a.data.rarity > b.data.rarity

# 查找物品在背包中的索引
func find_item_index(item: InventoryItem) -> int:
	if not item:
		return -1
	
	for i in range(max_slots):
		if items[i] and items[i] == item:
			return i
	return -1

## 存档用：导出可序列化的背包数据（按槽位，空槽为 null）
## id 必须为 int，后端 game.items 以 item_id (int) 校验
func get_serializable_inventory() -> Array:
	var result: Array = []
	result.resize(max_slots)
	for i in range(max_slots):
		if items[i]:
			var id_val = items[i].data.id
			var id_int := int(id_val) if str(id_val).is_valid_int() else 0
			result[i] = { "id": id_int, "qty": items[i].quantity }
		else:
			result[i] = null
	return result

## 存档用：从序列化数据恢复背包（会清空当前背包再按槽位恢复）
func load_serializable_inventory(data: Array) -> void:
	clear()
	var n = mini(data.size(), max_slots)
	for i in range(n):
		var entry = data[i]
		if entry != null and typeof(entry) == TYPE_DICTIONARY:
			var id_val = entry.get("id", "")
			var qty = int(entry.get("qty", 1))
			var id_str := str(id_val) if id_val != null and id_val != "" else ""
			if id_str != "":
				var item_data = item_database.get_item_data(id_str)
				if not item_data and GameDataManager.is_loaded():
					item_data = GameDataManager.get_item_data(int(id_val))
				if item_data:
					items[i] = InventoryItem.new(item_data, qty)
	inventory_changed.emit()
