extends Node 

signal item_added(item: InventoryItem, slot_index: int)
signal item_removed(item: InventoryItem, slot_index: int)
signal item_used(item: InventoryItem)
signal inventory_changed
signal bag_changed(bag_type: String)

@export var max_slots: int = 60
@onready var item_database: ItemDatabase

var items: Array[InventoryItem] = []
## 最近一次从 API/存档恢复的原始槽列表，供静态物品表晚于背包响应时二次解析
var _last_inventory_serializable: Array = []
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
	if not item_data:
		return false
	var remaining_quantity = quantity
	
	# 首先尝试堆叠到已有物品
	for i in range(max_slots):
		if items[i] and items[i].data and items[i].data.id == item_data.id:
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
	
	# 如果可以堆叠（把 from 合入 to）
	if to_item.data and from_item.data and to_item.data.id == from_item.data.id:
		var space = to_item.data.max_stack - to_item.quantity
		if space > 0:
			var transfer := mini(space, from_item.quantity)
			to_item.quantity += transfer
			from_item.quantity -= transfer
			if from_item.quantity <= 0:
				items[from_slot] = null
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
		if item and item.data and item.data.id == item_id:
			total_quantity += item.quantity
			if total_quantity >= quantity:
				return true
	return false

func use_item(slot_index: int) -> bool:
	var item = get_item(slot_index)
	if not item or not item.data:
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
		if item and item.data and item.data.rarity == item_rarity:
			result.append(item)
	return result

# 根据类型获取物品
func get_items_of_type(item_type: ItemData.ItemType) -> Array[InventoryItem]:
	var result: Array[InventoryItem] = []
	for item in items:
		if item and item.data and item.data.item_type == item_type:
			result.append(item)
	return result

# 根据名称搜索物品
func get_items_by_name(item_name: String) -> Array[InventoryItem]:
	var result: Array[InventoryItem] = []
	if item_name.is_empty():
		return get_items_of_type(_get_item_type_from_string(current_bag_type))
	
	for item in items:
		if item and item.data and (item.data.name == item_name or item.data.name.contains(item_name)):
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

## UI 分类键（与 Inventory.tscn 下 BagContainer 子节点名一致：Weapon / Potion / …）
const BAG_WEAPON := "Weapon"
const BAG_POTION := "Potion"
const BAG_MATERIAL := "Material"
const BAG_FOOD := "Food"
const BAG_QUEST := "Quest"
const BAG_TOOL := "Tool"


func _normalize_bag_type_key(bag_type: String) -> String:
	var t := bag_type.strip_edges().to_upper()
	match t:
		"WEAPON", "POTION", "MATERIAL", "FOOD", "QUEST", "TOOL":
			return t
		_:
			push_warning("[InventoryManager] 未知背包分类: %s，回退 WEAPON" % bag_type)
			return "WEAPON"


func _bag_ui_node_name(upper: String) -> String:
	match upper:
		"WEAPON": return BAG_WEAPON
		"POTION": return BAG_POTION
		"MATERIAL": return BAG_MATERIAL
		"FOOD": return BAG_FOOD
		"QUEST": return BAG_QUEST
		"TOOL": return BAG_TOOL
		_: return BAG_WEAPON


# 切换背包类型（会清空搜索并按类型筛选）
func switch_bag(bag_type: String) -> void:
	var upper := _normalize_bag_type_key(bag_type)
	current_bag_type = upper
	current_filter_name = ""
	bag_changed.emit(_bag_ui_node_name(upper))
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
	if a == null or b == null or not a.data or not b.data:
		return false
	
	return a.data.name < b.data.name
	
func _compare_items_by_rarity(a: InventoryItem, b: InventoryItem) -> bool:
	if a == null or b == null or not a.data or not b.data:
		return false
	
	# 如果稀有度相同按照名字排序
	if a.data.rarity == b.data.rarity:
		return a.data.name < b.data.name
	return a.data.rarity > b.data.rarity

## 按物品模板 ID（与存档 id / game.items.item_id 一致）统计总数量
func count_numeric_item_id(item_id: int) -> int:
	var n := 0
	for i in range(max_slots):
		var it = items[i]
		if it == null or not it.data:
			continue
		if _coerce_slot_item_id(it.data.id) == item_id:
			n += it.quantity
	return n


## 从背包各槽位扣减指定模板 ID 的数量（用于基因材料等）
func try_consume_numeric_item_id(item_id: int, quantity: int) -> bool:
	if quantity <= 0:
		return true
	var need := quantity
	for i in range(max_slots):
		if need <= 0:
			break
		var it = items[i]
		if it == null or not it.data:
			continue
		if _coerce_slot_item_id(it.data.id) != item_id:
			continue
		var take: int = mini(it.quantity, need)
		if not remove_item(i, take):
			return false
		need -= take
	return need <= 0


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
		if items[i] and items[i].data:
			var id_val = items[i].data.id
			var id_int := int(id_val) if str(id_val).is_valid_int() else 0
			result[i] = { "id": id_int, "qty": items[i].quantity }
		else:
			result[i] = null
	return result

## 存档用：从序列化数据恢复背包（会清空当前背包再按槽位恢复）
func load_serializable_inventory(data: Array) -> void:
	if data != null:
		_last_inventory_serializable = data.duplicate(true)
	else:
		_last_inventory_serializable.clear()
	_apply_serializable_inventory(_last_inventory_serializable)


func _coerce_slot_item_id(id_val: Variant) -> int:
	if id_val == null:
		return 0
	match typeof(id_val):
		TYPE_INT:
			return id_val
		TYPE_FLOAT:
			return int(id_val)
		_:
			var s := str(id_val)
			if s.is_valid_int():
				return int(s)
			if s.is_valid_float():
				return int(float(s))
			return 0


func _resolve_item_data_for_slot(id_val: Variant) -> ItemData:
	var id_num := _coerce_slot_item_id(id_val)
	if id_num <= 0:
		return null
	var id_str := str(id_num)
	var item_data := item_database.get_item_data(id_str)
	if not item_data and GameDataManager.is_loaded():
		item_data = GameDataManager.get_item_data(id_num)
	return item_data


func _apply_serializable_inventory(data: Array) -> void:
	items.clear()
	items.resize(max_slots)
	var n := mini(data.size(), max_slots)
	for i in range(n):
		var entry = data[i]
		if entry != null and typeof(entry) == TYPE_DICTIONARY:
			var id_val = entry.get("id", "")
			var qty := int(entry.get("qty", 1))
			if id_val != null and str(id_val) != "":
				var item_data := _resolve_item_data_for_slot(id_val)
				if item_data:
					items[i] = InventoryItem.new(item_data, qty)
	inventory_changed.emit()


## ItemDatabase 从 GameDataManager 同步完成后调用：补全此前无法解析的槽位，或刷新已有槽位的 ItemData
func reapply_last_serializable_inventory() -> void:
	if not _last_inventory_serializable.is_empty():
		_apply_serializable_inventory(_last_inventory_serializable)
	else:
		_refresh_item_data_references()


func _refresh_item_data_references() -> void:
	for i in range(max_slots):
		if items[i] == null or not items[i].data:
			continue
		var id_num := _coerce_slot_item_id(items[i].data.id)
		if id_num <= 0:
			continue
		var fresh := _resolve_item_data_for_slot(id_num)
		if fresh:
			items[i] = InventoryItem.new(fresh, items[i].quantity)
	inventory_changed.emit()


## 宝箱 / 测试：发放一套与 **`StarshipBackend/PSQL_DH/game_data/items.json`**（v2.2.0）一致的物品。
## 修改 JSON 后请同步更新下列 `add_item_by_numeric_id` 的数字。
func grant_standard_test_bundle() -> void:
	add_item_by_numeric_id(1003001, 1)  # M9 Beretta
	add_item_by_numeric_id(1003009, 1)  # MP7
	add_item_by_numeric_id(1003010, 1)  # X-87
	add_item_by_numeric_id(1001010, 2)  # 9×19mm
	add_item_by_numeric_id(1001011, 2)  # 4.6mm PDW
	add_item_by_numeric_id(1001012, 2)  # X-87 能量单元
	add_item_by_numeric_id(1011005, 3)  # 神经镇静合剂
	add_item_by_numeric_id(1011006, 2)  # 螯合抗辐碘剂
	add_item_by_numeric_id(1000004, 1)  # 实验室合金钥匙
	add_item_by_numeric_id(1000005, 1)  # B-7 门禁卡
	add_item_by_numeric_id(1000006, 1)  # 身份重编码券
	add_item_by_numeric_id(1001013, 50)  # 星币
