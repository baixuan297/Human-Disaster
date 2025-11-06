extends Node
class_name ItemDatabase

var items_data: Dictionary = {}
var icons_cache: Dictionary = {}


func _ready():
	load_json_from_folder()

func load_items_from_json(file_path: String):
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
				items_data[str(item.id)] = item
				# 预加载图标
				if item.icon:
					icons_cache[str(item.id)] = item.icon
	elif typeof(data) == TYPE_DICTIONARY and data.has("items"):
		for item_data in data.items:
			var item = create_item_data_from_dict(item_data)
			if item:
				items_data[str(item.id)] = item
				# 预加载图标
				if item.icon:
					icons_cache[str(item.id)] = item.icon
	else:
		print("JSON文件格式错误：不支持的数据格式")
		return
	
	#print("成功加载 ", items_data.size(), " 个物品数据")

func create_item_data_from_dict(data_dict: Dictionary) -> ItemData:
	var item = ItemData.new()
	
	# 转换
	item.id = str(int(data_dict.get("item_id", 0)))
	item.name = data_dict.get("item_name", "")
	item.description = data_dict.get("item_desc", "")
	item.max_stack = int(data_dict.get("max_stack", 1))
	item.sell_price = 0
	item.buy_price = 0
	
	# 处理类型
	var type_string = data_dict.get("item_type", "FOOD")
	match type_string.to_upper():
		"FOOD":
			item.item_type = ItemData.ItemType.FOOD
		"WEAPON":
			item.item_type = ItemData.ItemType.WEAPON
		"ARMOR":
			item.item_type = ItemData.ItemType.POTION
		"TOOL":
			item.item_type = ItemData.ItemType.TOOL
		"MATERIAL":
			item.item_type = ItemData.ItemType.MATERIAL
		"QUEST":
			item.item_type = ItemData.ItemType.QUEST
		_:
			item.item_type = ItemData.ItemType.MATERIAL
			print("未知物品类型: ", type_string)
	
	# 处理稀有度
	var rarity_string = data_dict.get("rarity", "COMMON")
	match rarity_string.to_upper():
		"COMMON":
			item.rarity = ItemData.ItemRarity.COMMON
		"UNCOMMON":
			item.rarity = ItemData.ItemRarity.UNCOMMON
		"RARE":
			item.rarity = ItemData.ItemRarity.RARE
		"EPIC":
			item.rarity = ItemData.ItemRarity.EPIC
		"LEGENDARY":
			item.rarity = ItemData.ItemRarity.LEGENDARY
		_:
			item.rarity = ItemData.ItemRarity.COMMON
			print("未知稀有度: ", rarity_string)
	
	# 加载图标
	var icon_path = data_dict.get("item_icon", "")
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
			print("图标文件不存在: ", icon_path, " (已尝试多种格式)")
	
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
		
