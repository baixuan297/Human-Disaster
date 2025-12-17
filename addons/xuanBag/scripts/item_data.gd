extends Resource
class_name ItemData

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var max_stack: int = 1
@export var item_type: ItemType = ItemType.MATERIAL
@export var rarity: ItemRarity = ItemRarity.COMMON
@export var sell_price: int = 0
@export var buy_price: int = 0

enum ItemType {
	FOOD,
	WEAPON,
	POTION,
	TOOL,
	MATERIAL,
	QUEST,
}

enum ItemRarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
}

func get_rarity_color() -> Color:
	match rarity:
		ItemRarity.COMMON:
			return Color.WHITE
		ItemRarity.UNCOMMON:
			return Color.GREEN
		ItemRarity.RARE:
			return Color.BLUE
		ItemRarity.EPIC:
			return Color.PURPLE
		ItemRarity.LEGENDARY:
			return Color.ORANGE
		_:
			return Color.WHITE
