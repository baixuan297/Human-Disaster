extends Control
class_name ItemTooltip

@onready var item_name: Label = $MarginContainer/Item_Info/Basic_Info/item_name
@onready var item_type: Label = $MarginContainer/Item_Info/Basic_Info/item_type
@onready var item_desc: Label = $MarginContainer/Vbox/item_desc
@onready var qty: Label = $MarginContainer/Item_Info/Addition_Info/Qty


var current_item: InventoryItem

func _ready():
	add_to_group("item_tooltip")
	visible = false
	z_index = 100

func show_tooltip(item: InventoryItem, pos: Vector2):
	if not item or not item.data:
		return
	
	current_item = item

	update_tooltip_content()
	
	global_position = pos
	visible = true
	
	# 确保提示框不会超出屏幕
	#var screen_size = get_viewport().size
	#if global_position.x + size.x > screen_size.x:
		#global_position.x = screen_size.x - size.x
	#if global_position.y + size.y > screen_size.y:
		#global_position.y = screen_size.y - size.y


func update_tooltip_content():
	if not current_item or not current_item.data:
		return
	
	var data = current_item.data
	
	item_name.text = data.name
	item_name.modulate = data.get_rarity_color()
	item_type.text = ItemData.ItemType.keys()[data.item_type]
	item_desc.text = data.description	
	qty.text = "Qty: " + str(current_item.quantity)
	
	#if data.sell_price > 0:
		#var price_label = Label.new()
		#price_label.text = "售价: " + str(data.sell_price) + " 金币"
		#stats_container.add_child(price_label)
