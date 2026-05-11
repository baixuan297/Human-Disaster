## GameDataManager.gd
## 启动时从 API 拉取所有静态配置数据，供全局查询

## 职责（单一）：
##   · 管理物品、武器、技能、基因、敌人的「定义」数据（只读，从服务器同步一次）
##   · 不处理角色运行时数据，那是各自的 Manager 负责
##   · 不直接操作 UI，通过信号通知 UI 数据就绪
##
## 使用方式：
##   var item   = GameDataManager.get_item(1003001)
##   var weapon = GameDataManager.get_weapon(4001001)
##   var skill  = GameDataManager.get_skill_by_name("钛石冲击")
##   var gene   = GameDataManager.get_gene(2003001)
##   var enemy  = GameDataManager.get_enemy(4001003)

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
## weapon_id (int) → Dictionary
var _weapons: Dictionary = {}
## weapon_name (String) → Dictionary（双索引，方便按名字查）
var _weapons_by_name: Dictionary = {}
## skill_id (int) → Dictionary
var _skills: Dictionary = {}
## skill_name (String) → Dictionary（双索引，方便按名字查）
var _skills_by_name: Dictionary = {}
## gene_id (int) → Dictionary
var _genes:  Dictionary = {}
## enemy_id (int) → Dictionary
var _enemies: Dictionary = {}

## 加载状态：0=未开始 1=加载中 2=完成 3=失败
var _state: int = 0
## 防止「先失败后磁盘兜底」与后续成功回调重复触发 _check_all_loaded / all_data_loaded
var _initial_load_complete: bool = false

# 基因加载开关：后端已支持 /game-data/genes
const _LOAD_GENES := true
const _LOAD_WEAPONS := true
const _LOAD_ENEMIES := true
# 跟踪请求完成状态
var _loaded_flags: Dictionary = {"items": false, "weapons": false, "skills": false, "genes": false, "enemies": false}

## 全量静态定义本地缓存（与角色 .lcs 分离；供离线兜底与冷启动加速）
const DEFINITIONS_DISK_CACHE_PATH: String = "user://game_data_definitions_cache.enc"
const DEFINITIONS_CACHE_SCHEMA: int = 1
const DEFINITIONS_CACHE_PASS: String = "DesahumanGDDef"

# ── 生命周期 ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	# 延迟一帧确保 APIManager 已初始化
	call_deferred("_load_all")


func _load_all() -> void:
	if _state == 1:
		return  # 已经在加载，防止重复调用
	_state = 1
	_initial_load_complete = false
	_loaded_flags = {
		"items": false,
		"weapons": not _LOAD_WEAPONS,
		"skills": false,
		"genes": not _LOAD_GENES,
		"enemies": not _LOAD_ENEMIES,
	}

	# 并行请求（APIManager 每次请求独立 HTTPRequest，支持并发）
	ApiManager.get_game_data_items(_on_items_loaded)
	if _LOAD_WEAPONS:
		ApiManager.get_game_data_weapons(_on_weapons_loaded)
	ApiManager.get_game_data_skills(_on_skills_loaded)
	if _LOAD_GENES:
		ApiManager.get_game_data_genes(_on_genes_loaded)
	if _LOAD_ENEMIES:
		ApiManager.get_game_data_enemies(_on_enemies_loaded)


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


func _on_weapons_loaded(success: bool, data) -> void:
	if not success:
		_on_load_error("武器数据加载失败")
		return
	var arr: Array = data if data is Array else data.get("weapons", [])
	for raw in arr:
		var weapon_id: int = int(raw.get("weapon_id", 0))
		if weapon_id > 0:
			_weapons[weapon_id] = raw
			_weapons_by_name[raw.get("name", "")] = raw
	_loaded_flags["weapons"] = true
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

	_register_skills_in_resource_registry()

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


func _on_enemies_loaded(success: bool, data) -> void:
	if not success:
		_on_load_error("敌人数据加载失败")
		return
	var arr: Array = data if data is Array else data.get("enemies", [])
	for raw in arr:
		var eid: int = int(raw.get("enemy_id", 0))
		if eid > 0:
			_enemies[eid] = raw
	_loaded_flags["enemies"] = true
	_check_all_loaded()


func _check_all_loaded() -> void:
	if _initial_load_complete:
		return
	var loaded: int = _loaded_flags.values().count(true)
	var required: int = _loaded_flags.size()
	data_progress.emit(loaded, required)

	if loaded >= required:
		_initial_load_complete = true
		_state = 2
		print("[GameDataManager] 静态数据加载完成  items=%d  weapons=%d  skills=%d  genes=%d  enemies=%d"
			% [_items.size(), _weapons.size(), _skills.size(), _genes.size(), _enemies.size()])
		_persist_definitions_disk_cache()
		all_data_loaded.emit()


func _on_load_error(reason: String) -> void:
	if _state == 2:
		return
	if try_restore_definitions_from_disk_cache():
		_initial_load_complete = true
		_loaded_flags = {"items": true, "weapons": true, "skills": true, "genes": true, "enemies": true}
		_state = 2
		push_warning("[GameDataManager] API 失败，已用本地静态缓存兜底: %s" % reason)
		GlobalMessage.emit_toast("已使用本地缓存配置，联网后将刷新", "warning")
		all_data_loaded.emit()
		return
	_state = 3
	push_error("[GameDataManager] " + reason)
	data_load_failed.emit(reason)
	GlobalMessage.emit_toast("无法获取最新游戏数据，请检查网络后重试", "error")


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


# ─── 武器 ──────────────────────────────────────────────────────────────────

## 按 weapon_id 获取武器定义 Dictionary
func get_weapon(weapon_id: int) -> Dictionary:
	return _weapons.get(weapon_id, {})


## 按武器名称获取
func get_weapon_by_name(weapon_name: String) -> Dictionary:
	return _weapons_by_name.get(weapon_name, {})


## 按武器类型筛选（PISTOL / SMG / RIFLE 等）
func get_weapons_by_type(weapon_type: String) -> Array:
	return _weapons.values().filter(func(r): return r.get("weapon_type", "") == weapon_type.to_upper())


## 按稀有度筛选
func get_weapons_by_rarity(rarity: String) -> Array:
	return _weapons.values().filter(func(r): return r.get("rarity", "") == rarity.to_upper())


## 获取所有武器
func get_all_weapons() -> Array:
	return _weapons.values()


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


# ─── 敌人模板（类别 / combat_tags，与 genes.json vs_targets 对齐）──────────────

## 按 enemy_id 获取敌人定义 Dictionary；含 enemy_category、combat_tags、metadata
func get_enemy(enemy_id: int) -> Dictionary:
	return _enemies.get(enemy_id, {})


## combat_tags 大写字符串数组，供 BaseEnemy 同步
func get_enemy_combat_tags(enemy_id: int) -> Array[String]:
	var raw := get_enemy(enemy_id)
	var out: Array[String] = []
	var tags: Variant = raw.get("combat_tags", [])
	if tags is Array:
		for t in tags:
			out.append(str(t).to_upper())
	return out


func get_all_enemies() -> Array:
	return _enemies.values()


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


func _persist_definitions_disk_cache() -> void:
	var bundle := {
		"schema_version": DEFINITIONS_CACHE_SCHEMA,
		"fetched_at_unix": int(Time.get_unix_time_from_system()),
		"items": _items.values(),
		"weapons": _weapons.values(),
		"skills": _skills.values(),
		"genes": _genes.values(),
		"enemies": _enemies.values(),
	}
	var f := FileAccess.open_encrypted_with_pass(DEFINITIONS_DISK_CACHE_PATH, FileAccess.WRITE, DEFINITIONS_CACHE_PASS)
	if f == null:
		push_warning("[GameDataManager] 无法写入静态定义缓存 err=%s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(bundle))
	f.close()


## 从本地加密缓存灌入内存；用于 API 全失败时的离线兜底（需此前成功联网写入过缓存）
func try_restore_definitions_from_disk_cache() -> bool:
	if not FileAccess.file_exists(DEFINITIONS_DISK_CACHE_PATH):
		return false
	var f := FileAccess.open_encrypted_with_pass(DEFINITIONS_DISK_CACHE_PATH, FileAccess.READ, DEFINITIONS_CACHE_PASS)
	if f == null:
		return false
	var raw := f.get_as_text()
	f.close()
	if raw.strip_edges().is_empty():
		return false
	var j := JSON.new()
	if j.parse(raw) != OK:
		return false
	var data: Variant = j.data
	if not data is Dictionary:
		return false
	var d: Dictionary = data
	if int(d.get("schema_version", 0)) != DEFINITIONS_CACHE_SCHEMA:
		return false
	_items.clear()
	_weapons.clear()
	_weapons_by_name.clear()
	_skills.clear()
	_skills_by_name.clear()
	_genes.clear()
	_enemies.clear()
	for raw_item in d.get("items", []):
		if raw_item is Dictionary:
			var id := int((raw_item as Dictionary).get("item_id", 0))
			if id > 0:
				_items[id] = raw_item
	for raw_weapon in d.get("weapons", []):
		if raw_weapon is Dictionary:
			var wid := int((raw_weapon as Dictionary).get("weapon_id", 0))
			if wid > 0:
				_weapons[wid] = raw_weapon
				_weapons_by_name[(raw_weapon as Dictionary).get("name", "")] = raw_weapon
	for raw_skill in d.get("skills", []):
		if raw_skill is Dictionary:
			var sid := int((raw_skill as Dictionary).get("skill_id", 0))
			if sid > 0:
				_skills[sid] = raw_skill
				_skills_by_name[(raw_skill as Dictionary).get("name", "")] = raw_skill
	for raw_gene in d.get("genes", []):
		if raw_gene is Dictionary:
			var gid := int((raw_gene as Dictionary).get("gene_id", 0))
			if gid > 0:
				_genes[gid] = raw_gene
	for raw_enemy in d.get("enemies", []):
		if raw_enemy is Dictionary:
			var eid := int((raw_enemy as Dictionary).get("enemy_id", 0))
			if eid > 0:
				_enemies[eid] = raw_enemy
	if _items.is_empty() or _skills.is_empty():
		return false
	if _LOAD_WEAPONS and _weapons.is_empty():
		return false
	if _LOAD_GENES and _genes.is_empty():
		return false
	if _LOAD_ENEMIES and _enemies.is_empty():
		return false
	_register_skills_in_resource_registry()
	return true


## 把已载入内存的静态技能表同步到 SkillResourceRegistry（联网 API 与本地加密缓存两条路径都会走到）
func _register_skills_in_resource_registry() -> void:
	if SkillResourceRegistry == null:
		return
	var rows: Array = []
	for skill_id in _skills:
		var row: Variant = _skills[skill_id]
		if row is Dictionary:
			rows.append(row)
	SkillResourceRegistry.register_from_game_data_skill_list(rows)
