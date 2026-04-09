extends Object
class_name GameItemIds

## 与 `StarshipBackend/PSQL_DH/game_data/items.json` v2.2.0 及
## `addons/xuanBag/data/items_addon.json` 对齐。
## 权威数据在后端 JSON + `python seeder.py`；addon 为 Godot 离线/增量副本。
## 交互、宝箱、测试发奖请用本类常量或 `grant_standard_test_bundle()`，禁止魔法数字。

# ── 武器 ─────────────────────────────────────────────────────────────────────
const WEAPON_M9_BERETTA: int = 1003001
const WEAPON_MP7: int = 1003009
const WEAPON_X87: int = 1003010

# ── 弹药 / 材料 ───────────────────────────────────────────────────────────────
const AMMO_9MM_BOX: int = 1001010
const AMMO_46_PDW_BOX: int = 1001011
const AMMO_X87_CELL: int = 1001012
const MATERIAL_STAR_COIN: int = 1001013

# ── 药水（与 items_addon 条目一致）──────────────────────────────────────────
const POTION_NEURO_CALM: int = 1011005
const POTION_RAD_CHELATE: int = 1011006

# ── 工具 ─────────────────────────────────────────────────────────────────────
const TOOL_LAB_KEY: int = 1000004
const TOOL_KEYCARD_B7: int = 1000005
const TOOL_RENAME_TOKEN: int = 1000006

## B-7 门禁卡：数据为 stackable=false、max_stack=1；数量>1 会各占一格（测试用）
const TEST_BUNDLE_KEYCARD_QTY: int = 3


## 宝箱 `chest` 分组、sample 测试按钮共用，与 `items_addon` 全量条目一致
static func grant_standard_test_bundle(inv: Node = null) -> void:
	var im: Variant = inv
	if im == null:
		im = InventoryManager
	if im == null or not im.has_method("add_item_by_numeric_id"):
		push_warning("[GameItemIds] grant_standard_test_bundle: 无可用背包节点")
		return
	im.add_item_by_numeric_id(WEAPON_X87, 1)
	im.add_item_by_numeric_id(WEAPON_M9_BERETTA, 1)
	im.add_item_by_numeric_id(WEAPON_MP7, 1)
	im.add_item_by_numeric_id(AMMO_X87_CELL, 99)
	im.add_item_by_numeric_id(AMMO_46_PDW_BOX, 999)
	im.add_item_by_numeric_id(AMMO_9MM_BOX, 99)
	im.add_item_by_numeric_id(TOOL_KEYCARD_B7, TEST_BUNDLE_KEYCARD_QTY)
	im.add_item_by_numeric_id(MATERIAL_STAR_COIN, 99999)
	im.add_item_by_numeric_id(TOOL_RENAME_TOKEN, 1)
	im.add_item_by_numeric_id(TOOL_LAB_KEY, 1)
	im.add_item_by_numeric_id(POTION_NEURO_CALM, 2)
	im.add_item_by_numeric_id(POTION_RAD_CHELATE, 1)
