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
	
func _on_item_used(item: InventoryItem) -> void:
	if not item or not item.data:
		return
	match item.data.item_type:
		ItemData.ItemType.MATERIAL:
			use_material(item)
		ItemData.ItemType.WEAPON:
			equip_weapon(item)
		ItemData.ItemType.POTION:
			use_potion(item)
		ItemData.ItemType.QUEST:
			use_quest_item(item)
		ItemData.ItemType.TOOL:
			use_tool(item)

func use_material(item: InventoryItem) -> void:
	if not item or not item.data:
		return
	var id := item.data.id
	if id == str(GameItemIds.MATERIAL_STAR_COIN):
		show_message("星币需在商店/终端消费，不能直接使用")
	else:
		show_message("使用了: " + item.data.name)


func use_tool(item: InventoryItem) -> void:
	if not item or not item.data:
		return
	var id := item.data.id
	if id == str(GameItemIds.TOOL_LAB_KEY):
		show_message("实验室合金钥匙：关卡脚本可接 metadata.unlock_hint: lab_biochem_wing")
	elif id == str(GameItemIds.TOOL_KEYCARD_B7):
		show_message("已验证 B-7 区门禁权限（关卡可接 unlock_hint: sector_b7_doors）")
	elif id == str(GameItemIds.TOOL_RENAME_TOKEN):
		show_message("身份重编码券：接改名流程，成功后由逻辑扣减 1 张")
	else:
		show_message("使用工具: " + item.data.name)

func equip_weapon(item: InventoryItem):
	show_message("使用了: " + item.data.name)

func use_potion(item: InventoryItem) -> void:
	if not item or not item.data:
		return
	var id := item.data.id
	if id == str(GameItemIds.POTION_NEURO_CALM):
		show_message("使用神经镇静合剂（生命/防御 buff 见 items.json metadata）")
	elif id == str(GameItemIds.POTION_RAD_CHELATE):
		show_message("使用螯合抗辐碘剂（辐射耐受 buff 见 items.json metadata）")
	else:
		show_message("使用药水: " + item.data.name)

func use_quest_item(item: InventoryItem):
	show_message("使用了任务物品: " + item.data.name)

func show_message(text: String):
	print("游戏消息: ", text)

# 检查是否拥有特定物品的便捷方法
func has_item_by_id(item_id: int, quantity: int = 1) -> bool:
	return InventoryManager.has_item(str(item_id), quantity)

func has_item_by_string_id(item_id: String, quantity: int = 1) -> bool:
	return InventoryManager.has_item(item_id, quantity)

func _on_button_pressed() -> void:
	GameItemIds.grant_standard_test_bundle(inventory)
