## GameDataManager.gd
## 启动时从 API 拉取所有静态配置数据，供全局查询

## 职责（单一）：
##   · 管理物品、技能、基因的「定义」数据（只读，从服务器同步一次）
##   · 不处理角色运行时数据，那是各自的 Manager 负责
##   · 不直接操作 UI，通过信号通知 UI 数据就绪
##
## 使用方式：
##   var item = GameDataManager.get_item(1001)
##   var skill = GameDataManager.get_skill_by_name("钛石冲击")
##   var gene  = GameDataManager.get_gene(3001)

extends Node

# ── 信号 ──────────────────────────────────────────────────────────────────────
## 所有静态数据加载完成（可以开始初始化 UI / 角色）
signal all_data_loaded
## 单项加载完成（用于进度条）
signal data_progress(loaded: int, total: int)
## 加载出错
signal data_load_failed(reason: String)

# ── 内部存储（Dictionary 保证 O(1) 查找）────────────────────────────────────
## item_id (int) → Dictionary
var _items:  Dictionary = {}
## skill_id (int) → Dictionary
var _skills: Dictionary = {}
## skill_name (String) → Dictionary（双索引，方便按名字查）
var _skills_by_name: Dictionary = {}
## gene_id (int) → Dictionary
var _genes:  Dictionary = {}

## 加载状态：0=未开始 1=加载中 2=完成 3=失败
var _state: int = 0

# 基因加载开关：后端已支持 /game-data/genes
const _LOAD_GENES := true
# 跟踪请求完成状态
var _loaded_flags: Dictionary = {"items": false, "skills": false, "genes": false}

# ── 生命周期 ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	# 延迟一帧确保 APIManager 已初始化
	call_deferred("_load_all")


func _load_all() -> void:
	if _state == 1:
		return  # 已经在加载，防止重复调用
	_state = 1
	_loaded_flags = {"items": false, "skills": false, "genes": false}

	# 并行请求（APIManager 每次请求独立 HTTPRequest，支持并发）
	ApiManager.get_game_data_items(_on_items_loaded)
	ApiManager.get_game_data_skills(_on_skills_loaded)
	if _LOAD_GENES:
		ApiManager.get_game_data_genes(_on_genes_loaded)


# ── 数据加载回调 ──────────────────────────────────────────────────────────────

func _on_items_loaded(success: bool, data) -> void:
	if not success:
		_on_load_error("物品数据加载失败")
		return

	# 后端返回 List[ItemDefResponse] 即 JSON 数组，兼容 {"items": [...]} 包装
	var arr: Array = data if data is Array else data.get("items", [])
	for raw in arr:
		var item_id: int = int(raw.get("item_id", 0))
		if item_id > 0:
			_items[item_id] = raw

	_loaded_flags["items"] = true
	_check_all_loaded()


func _on_skills_loaded(success: bool, data) -> void:
	if not success:
		_on_load_error("技能数据加载失败")
		return

	# 后端返回 List[SkillDefResponse] 即 JSON 数组，兼容 {"skills": [...]} 包装
	var arr: Array = data if data is Array else data.get("skills", [])
	for raw in arr:
		var skill_id: int = int(raw.get("skill_id", 0))
		if skill_id > 0:
			_skills[skill_id]                 = raw
			_skills_by_name[raw.get("name")] = raw

	_loaded_flags["skills"] = true
	_check_all_loaded()

func _on_genes_loaded(success: bool, data) -> void:
	if not success:
		_on_load_error("基因数据加载失败")
		return

	var arr: Array = data if data is Array else data.get("genes", [])
	for raw in arr:
		var gene_id: int = int(raw.get("gene_id", 0))
		if gene_id > 0:
			_genes[gene_id] = raw

	_loaded_flags["genes"] = true
	_check_all_loaded()


func _check_all_loaded() -> void:
	var loaded: int = _loaded_flags.values().count(true)
	var required: int = 3 if _LOAD_GENES else 2
	data_progress.emit(loaded, required)

	if loaded >= required:
		_state = 2
		print("[GameDataManager] 静态数据加载完成  items=%d  skills=%d  genes=%d"
			% [_items.size(), _skills.size(), _genes.size()])
		all_data_loaded.emit()


func _on_load_error(reason: String) -> void:
	_state = 3
	push_error("[GameDataManager] " + reason)
	data_load_failed.emit(reason)


# ── 公共查询 API ──────────────────────────────────────────────────────────────

## 是否已加载完毕
func is_loaded() -> bool:
	return _state == 2


# ─── 物品 ──────────────────────────────────────────────────────────────────

## 按 item_id 获取物品定义 Dictionary，不存在返回 {}
func get_item(item_id: int) -> Dictionary:
	return _items.get(item_id, {})


## 按 item_id 获取 ItemData Resource（兼容 InventoryManager）
## 会从 Dictionary 构建 ItemData，并写入 ItemDatabase（本地缓存）
func get_item_data(item_id: int) -> ItemData:
	var raw := get_item(item_id)
	if raw.is_empty():
		return null
	# 先查本地 ItemDatabase 缓存
	var db: ItemDatabase = InventoryManager.item_database
	if db and db.has_item_by_id(item_id):
		return db.get_item_data_by_id(item_id)
	# 没有则构建并注册
	var item_data := _build_item_data(raw)
	if db:
		db.items_data[str(item_id)] = item_data
	return item_data


## 获取所有物品 Dictionary 列表
func get_all_items() -> Array:
	return _items.values()


## 按 item_type 筛选（如 "WEAPON" / "POTION"）
func get_items_by_type(item_type: String) -> Array:
	return _items.values().filter(func(r): return r.get("item_type", "") == item_type.to_upper())


## 按 rarity 筛选
func get_items_by_rarity(rarity: String) -> Array:
	return _items.values().filter(func(r): return r.get("rarity", "") == rarity.to_upper())


# ─── 技能 ──────────────────────────────────────────────────────────────────

## 按 skill_id 获取技能定义 Dictionary
func get_skill(skill_id: int) -> Dictionary:
	return _skills.get(skill_id, {})


## 按技能名称获取
func get_skill_by_name(skill_name: String) -> Dictionary:
	return _skills_by_name.get(skill_name, {})


## 按职业筛选（metadata.class_affinity）
func get_skills_by_class(_class_name: String) -> Array:
	return _skills.values().filter(func(r):
		return r.get("metadata", {}).get("class_affinity", "") == _class_name
	)


## 获取所有技能
func get_all_skills() -> Array:
	return _skills.values()


# ─── 基因 ──────────────────────────────────────────────────────────────────

## 按 gene_id 获取基因定义 Dictionary
func get_gene(gene_id: int) -> Dictionary:
	return _genes.get(gene_id, {})


## 按基因类型筛选（OFFENSIVE / DEFENSIVE / NEURAL / REGENERATIVE / ADAPTIVE / UTILITY）
func get_genes_by_type(gene_type: String) -> Array:
	return _genes.values().filter(func(r): return r.get("gene_type", "") == gene_type.to_upper())


## 按职业筛选（class_restriction 为 null 表示全职业可用）
func get_genes_available_for_class(_class_name: String) -> Array:
	return _genes.values().filter(func(r):
		var restriction = r.get("class_restriction")
		return restriction == null or _class_name in restriction
	)


## 获取所有基因
func get_all_genes() -> Array:
	return _genes.values()


## 获取某个基因在指定等级的效果 Dictionary
func get_gene_level_effect(gene_id: int, level: int) -> Dictionary:
	var gene := get_gene(gene_id)
	if gene.is_empty():
		return {}
	var effects: Array = gene.get("level_effects", [])
	for effect in effects:
		if int(effect.get("level", 0)) == level:
			return effect
	return {}


# ── 私有：构建 ItemData Resource ──────────────────────────────────────────────

func _build_item_data(raw: Dictionary) -> ItemData:
	var item   := ItemData.new()
	item.id    = str(int(raw.get("item_id", 0)))
	item.name  = raw.get("name", "")
	item.description = raw.get("description", "")
	item.max_stack   = int(raw.get("max_stack", 1))
	item.sell_price  = 0
	item.buy_price   = 0

	# 物品类型
	var type_str: String = raw.get("item_type", "MATERIAL")
	match type_str.to_upper():
		"FOOD":     item.item_type = ItemData.ItemType.FOOD
		"WEAPON":   item.item_type = ItemData.ItemType.WEAPON
		"POTION":   item.item_type = ItemData.ItemType.POTION
		"TOOL":     item.item_type = ItemData.ItemType.TOOL
		"MATERIAL": item.item_type = ItemData.ItemType.MATERIAL
		"QUEST":    item.item_type = ItemData.ItemType.QUEST
		_:          item.item_type = ItemData.ItemType.MATERIAL

	# 稀有度
	var rarity_str: String = raw.get("rarity", "COMMON")
	match rarity_str.to_upper():
		"COMMON":    item.rarity = ItemData.ItemRarity.COMMON
		"UNCOMMON":  item.rarity = ItemData.ItemRarity.UNCOMMON
		"RARE":      item.rarity = ItemData.ItemRarity.RARE
		"EPIC":      item.rarity = ItemData.ItemRarity.EPIC
		"LEGENDARY": item.rarity = ItemData.ItemRarity.LEGENDARY
		_:           item.rarity = ItemData.ItemRarity.COMMON

	# 图标（优先用 icon_path，兼容旧字段 item_icon）
	var icon_path: String = raw.get("icon_path", raw.get("item_icon", ""))
	if icon_path != "":
		if ResourceLoader.exists(icon_path):
			item.icon = load(icon_path)

	return item
