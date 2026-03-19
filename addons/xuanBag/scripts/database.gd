extends Node
class_name ItemDatabase

## ItemDatabase — 物品定义本地缓存
##
## 数据源：先加载 res://addons/xuanBag/data/*.json，再通过 GameDataManager 同步（网络优先）
## 字段兼容：create_item_data_from_dict 支持 name/description/icon_path 与 item_name/item_desc/item_icon

var items_data: Dictionary = {}
var icons_cache: Dictionary = {}

# ── 生命周期 ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	# 优先从本地 JSON 文件夹加载（旧系统兼容）
	load_json_from_folder()
	# 如果 GameDataManager 已加载完成，再从它同步（覆盖/补充，网络数据优先）
	if GameDataManager.is_loaded():
		register_from_game_data_manager()
	else:
		GameDataManager.all_data_loaded.connect(register_from_game_data_manager)

# ── 从 GameDataManager 批量注册（网络数据优先级高于本地 JSON）──────────────────

func register_from_game_data_manager() -> void:
	var all_items: Array = GameDataManager.get_all_items()
	for raw in all_items:
		var item := create_item_data_from_dict(raw)
		if item:
			var key := str(int(raw.get("item_id", 0)))
			items_data[key] = item
			if item.icon:
				icons_cache[key] = item.icon
	print("[ItemDatabase] 从 GameDataManager 同步 %d 个物品" % all_items.size())

# ── 从本地 JSON 文件加载（兼容旧系统）───────────────────────────────────────

func load_items_from_json(file_path: String) -> void:
	# 检查
	if not FileAccess.file_exists(file_path):
		print("物品数据文件不存在: ", file_path)
		return
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("无法打开物品数据文件: ", file_path)
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("JSON解析错误: ", json.error_string)
		return
	
	var data = json.data
	#print(data)

	# 检查数据格式
	if typeof(data) == TYPE_ARRAY:
		for item_data in data:
			var item = create_item_data_from_dict(item_data)
			if item:
				var key := str(int(item_data.get("item_id", item_data.get("id", 0))))
				items_data[key] = item
				if item.icon:
					icons_cache[key] = item.icon
	elif typeof(data) == TYPE_DICTIONARY and data.has("items"):
		for item_data in data["items"]:
			var item = create_item_data_from_dict(item_data)
			if item:
				var key := str(int(item_data.get("item_id", item_data.get("id", 0))))
				items_data[key] = item
				if item.icon:
					icons_cache[key] = item.icon
	else:
		print("JSON文件格式错误：不支持的数据格式")
		return
	
	#print("成功加载 ", items_data.size(), " 个物品数据")

func create_item_data_from_dict(d: Dictionary) -> ItemData:
	if d.is_empty():
		return null

	var item := ItemData.new()

	# ── ID（兼容 item_id / id）────────────────────────────────────────────────
	var raw_id = d.get("item_id", d.get("id", 0))
	item.id = str(int(raw_id))

	# ── 名称（新字段 name，兼容旧字段 item_name）────────────────────────────
	item.name = d.get("name", d.get("item_name", ""))

	# ── 描述（新字段 description，兼容旧字段 item_desc）────────────────────
	item.description = d.get("description", d.get("item_desc", ""))

	# ── 堆叠
	item.max_stack = int(d.get("max_stack", 1))
	item.sell_price = 0
	item.buy_price = 0

	# ── 物品类型（兼容 ARMOR → POTION 的旧映射）────────────────────────────
	var type_str: String = d.get("item_type", "MATERIAL")
	match type_str.to_upper():
		"FOOD":     item.item_type = ItemData.ItemType.FOOD
		"WEAPON":   item.item_type = ItemData.ItemType.WEAPON
		"POTION":   item.item_type = ItemData.ItemType.POTION
		"ARMOR":    item.item_type = ItemData.ItemType.POTION  # 旧数据兼容
		"TOOL":     item.item_type = ItemData.ItemType.TOOL
		"MATERIAL": item.item_type = ItemData.ItemType.MATERIAL
		"QUEST":    item.item_type = ItemData.ItemType.QUEST
		_:          item.item_type = ItemData.ItemType.MATERIAL

	# ── 稀有度 ─────────────────────────────────────────────────────────────
	var rarity_str: String = d.get("rarity", "COMMON")
	match rarity_str.to_upper():
		"COMMON":     item.rarity = ItemData.ItemRarity.COMMON
		"UNCOMMON":   item.rarity = ItemData.ItemRarity.UNCOMMON
		"RARE":       item.rarity = ItemData.ItemRarity.RARE
		"EPIC":       item.rarity = ItemData.ItemRarity.EPIC
		"LEGENDARY":  item.rarity = ItemData.ItemRarity.LEGENDARY
		_:            item.rarity = ItemData.ItemRarity.COMMON

	# ── 图标（新字段 icon_path，兼容旧字段 item_icon）──────────────────────
	var icon_path: String = d.get("icon_path", d.get("item_icon", ""))
	if icon_path != "" and icon_path != null:
		# 检查是否有文件扩展名，如果没有就尝试常见格式 
		var file_extensions = [".png", ".jpg", ".jpeg", ".svg"]
		var loaded = false
		
		if not icon_path.get_extension():
			# 没有扩展名，尝试常见格式
			for ext in file_extensions:
				var full_path = icon_path + ext
				if ResourceLoader.exists(full_path):
					item.icon = load(full_path)
					loaded = true
					break
		else:
			# 有扩展名，直接加载
			if ResourceLoader.exists(icon_path):
				item.icon = load(icon_path)
				loaded = true
		
		if not loaded:
			push_warning("[ItemDatabase] 图标文件不存在: " + icon_path)
	
	return item

func get_item_data(item_id: String) -> ItemData:
	return items_data.get(item_id, null)

func get_item_data_by_id(item_id: int) -> ItemData:
	return items_data.get(str(item_id), null)

func has_item(item_id: String) -> bool:
	return items_data.has(item_id)

func has_item_by_id(item_id: int) -> bool:
	return items_data.has(str(item_id))

func get_all_items() -> Dictionary:
	return items_data

func get_items_by_type(item_type: ItemData.ItemType) -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item in items_data.values():
		if item.item_type == item_type:
			result.append(item)
	return result

#func reload_items():
	#items_data.clear()
	#icons_cache.clear()
	##load_items_from_json("res://addons/xuanBag/data/items.json")
	#load_json_from_folder()
	
func load_json_from_folder():
	var folder_path: String = "res://addons/xuanBag/data/"
	var dir := DirAccess.open(folder_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			load_items_from_json(folder_path + file_name)
			#print(folder_path + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		print("无法打开目录")
		
