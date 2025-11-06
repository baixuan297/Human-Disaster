extends Node

@onready var inventory_ui: InventoryUI

var inventory: Node

func _ready():
	# 获取背包UI引用
	inventory_ui = get_tree().get_first_node_in_group("inventory_ui")
	inventory = InventoryManager
	
	# 连接信号
	if inventory:
		inventory.item_used.connect(_on_item_used)
	
	process_mode = Node.PROCESS_MODE_ALWAYS

func toggle_inventory():
	if inventory_ui:
		inventory_ui.toggle_visibility()
	
func _on_item_used(item: InventoryItem):
	# 处理物品使用逻辑
	match item.data.item_type:
		ItemData.ItemType.MATERIAL:
			use_material(item)
		ItemData.ItemType.WEAPON:
			equip_weapon(item)
		ItemData.ItemType.POTION:
			use_potion(item)
		ItemData.ItemType.QUEST:
			use_quest_item(item)

func use_material(item: InventoryItem):
	# 根据你的物品ID处理
	match item.data.id:
		"101":  # 门禁卡
			show_message("使用了门禁卡")
		"102":  # 星币
			show_message("星币不能直接使用")
		"103":  # 改名卡
			show_message("使用了改名卡，可以更改角色名称")
		_:
			show_message("使用了: " + item.data.name)

func equip_weapon(item: InventoryItem):
	show_message("使用了: " + item.data.name)

func use_potion(item: InventoryItem):
	show_message("穿上了: " + item.data.name)

func use_quest_item(item: InventoryItem):
	match item.data.id:
		"100":  # 实验室钥匙
			show_message("使用了实验室钥匙，实验室门打开了！")
			# 这里可以触发游戏事件
		_:
			show_message("使用了任务物品: " + item.data.name)

func show_message(text: String):
	print("游戏消息: ", text)

# 检查是否拥有特定物品的便捷方法
func has_item_by_id(item_id: int, quantity: int = 1) -> bool:
	return InventoryManager.has_item(str(item_id), quantity)

func has_item_by_string_id(item_id: String, quantity: int = 1) -> bool:
	return InventoryManager.has_item(item_id, quantity)

func _on_button_pressed() -> void:
	inventory.add_item_by_numeric_id(201, 1) # x87
	inventory.add_item_by_numeric_id(202, 1) # 手枪
	inventory.add_item_by_numeric_id(203, 1) # 冲锋枪
	inventory.add_item_by_numeric_id(251, 99) # 能量弹
	inventory.add_item_by_numeric_id(252, 999) # 30mm
	inventory.add_item_by_numeric_id(253, 99) # 9mm
	inventory.add_item_by_numeric_id(101, 3)  # 门禁卡
	inventory.add_item_by_numeric_id(102, 99999)  # 星币
	inventory.add_item_by_numeric_id(103, 1)  # 改名卡
	inventory.add_item_by_numeric_id(100, 1)  # 实验室钥匙
