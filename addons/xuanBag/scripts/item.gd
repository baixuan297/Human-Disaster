extends Resource
class_name InventoryItem

@export var data: ItemData
@export var quantity: int = 1

func _init(item_data: ItemData = null, qty: int = 1):
	data = item_data
	quantity = qty

func can_stack_with(other_item: InventoryItem) -> bool:
	if not other_item or not data or not other_item.data:
		return false
	return data.id == other_item.data.id and quantity + other_item.quantity <= data.max_stack

func stack_with(other: InventoryItem) -> int:
	if not can_stack_with(other):
		return other.quantity
	
	var available_space = data.max_stack - quantity
	var amount_to_add = min(available_space, other.quantity)
	
	quantity += amount_to_add
	return other.quantity - amount_to_add

func split(amount: int) -> InventoryItem:
	if amount >= quantity:
		return null
	
	quantity -= amount
	return InventoryItem.new(data, amount)
