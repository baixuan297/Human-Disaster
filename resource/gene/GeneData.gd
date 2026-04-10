## GeneData.gd — 基因定义模板（只读 Resource）
##
## 对标 ItemData.gd：定义模板，通过 from_dict() 工厂创建
## 来源：GeneManager 从 GameDataManager 缓存的 Dictionary 构建
## get_bonuses_at_level(level) 过滤 "level"/"description"，只保留数值加成键

extends Resource
class_name GeneData

# ══════════════════════════════════════════════════════════════════
# 基因类型与稀有度
# ══════════════════════════════════════════════════════════════════

enum GeneType {
	OFFENSIVE,
	DEFENSIVE,
	NEURAL,
	REGENERATIVE,
	ADAPTIVE,
	UTILITY,
}

enum GeneRarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
}

# ══════════════════════════════════════════════════════════════════
# 基础字段
# ══════════════════════════════════════════════════════════════════

var gene_id: int = 0
var gene_name: String = ""
var description: String = ""
var gene_type: GeneType = GeneType.UTILITY
var rarity: GeneRarity = GeneRarity.COMMON
var max_level: int = 5
var icon_path: String = ""

## 职业限制：空数组 = 全职业可用
var class_restriction: Array[String] = []
## 前置基因 ID 列表
var prerequisite_gene_ids: Array[int] = []
## 解锁所需最低角色等级（另需达到 GeneManager 基因系统开放等级）
var unlock_min_level: int = 20
## 测试用基因：不写入服务端、不参与存档
var is_test: bool = false
## 每级效果原始数据（来自 JSON）
var level_effects: Array = []
## 子基因模板（来自 JSON modules[]，GeneModuleData）
var gene_modules: Array = []
## 子基因数量上限（与后端 `game.genes.sub_gene_limits` 一致）
## 例：`{ "max_modules_total": 4, "max_modules_per_line": { "main": 2, "side": 2 } }`
var sub_gene_limits: Dictionary = {}


# ══════════════════════════════════════════════════════════════════
# 工厂方法
# ══════════════════════════════════════════════════════════════════

static func from_dict(d: Dictionary) -> GeneData:
	var g := GeneData.new()
	g.gene_id = int(d.get("gene_id", 0))
	g.gene_name = d.get("name", "")
	g.description = d.get("description", "")
	g.max_level = int(d.get("max_level", 5))
	g.icon_path = str(d.get("icon_path", ""))
	g.unlock_min_level = int(d.get("unlock_min_level", 20))
	g.is_test = bool(d.get("is_test", false))

	var type_str: String = d.get("gene_type", "UTILITY")
	match type_str.to_upper():
		"OFFENSIVE": g.gene_type = GeneType.OFFENSIVE
		"DEFENSIVE": g.gene_type = GeneType.DEFENSIVE
		"NEURAL": g.gene_type = GeneType.NEURAL
		"REGENERATIVE": g.gene_type = GeneType.REGENERATIVE
		"ADAPTIVE": g.gene_type = GeneType.ADAPTIVE
		_: g.gene_type = GeneType.UTILITY

	var rarity_str: String = d.get("rarity", "COMMON")
	match rarity_str.to_upper():
		"UNCOMMON": g.rarity = GeneRarity.UNCOMMON
		"RARE": g.rarity = GeneRarity.RARE
		"EPIC": g.rarity = GeneRarity.EPIC
		"LEGENDARY": g.rarity = GeneRarity.LEGENDARY
		_: g.rarity = GeneRarity.COMMON

	var restriction = d.get("class_restriction")
	if restriction is Array:
		for c in restriction:
			g.class_restriction.append(str(c))

	var prereqs = d.get("prerequisite_gene_ids", [])
	if prereqs is Array:
		for pid in prereqs:
			g.prerequisite_gene_ids.append(int(pid))

	var effects = d.get("level_effects", [])
	if effects is Array:
		g.level_effects = effects.duplicate(true)

	var mods = d.get("modules", [])
	if mods is Array:
		var gid := int(d.get("gene_id", 0))
		for mo in mods:
			if mo is Dictionary:
				var dict_copy := (mo as Dictionary).duplicate(true)
				if not dict_copy.has("parent_gene_id"):
					dict_copy["parent_gene_id"] = gid
				g.gene_modules.append(GeneModuleData.from_dict(dict_copy))

	var sgl = d.get("sub_gene_limits", {})
	if sgl is Dictionary:
		g.sub_gene_limits = (sgl as Dictionary).duplicate(true)

	return g


# ══════════════════════════════════════════════════════════════════
# 效果查询
# ══════════════════════════════════════════════════════════════════

func get_effect_at_level(level: int) -> Dictionary:
	for effect in level_effects:
		if int(effect.get("level", 0)) == level:
			return effect
	return {}


## 获取指定等级的属性加成（过滤 "level"/"description"，保留 vs_targets 等结构化字段）
func get_bonuses_at_level(level: int) -> Dictionary:
	var effect := get_effect_at_level(level)
	var bonuses := {}
	var skip_keys := ["level", "description"]
	for key in effect:
		if key not in skip_keys:
			bonuses[key] = effect[key]
	return bonuses


func get_description_at_level(level: int) -> String:
	var effect := get_effect_at_level(level)
	return effect.get("description", description)


# ══════════════════════════════════════════════════════════════════
# 显示辅助
# ══════════════════════════════════════════════════════════════════

func get_rarity_color() -> Color:
	match rarity:
		GeneRarity.COMMON: return Color.WHITE
		GeneRarity.UNCOMMON: return Color.GREEN
		GeneRarity.RARE: return Color(0.3, 0.6, 1.0)
		GeneRarity.EPIC: return Color(0.6, 0.2, 0.9)
		GeneRarity.LEGENDARY: return Color(1.0, 0.6, 0.1)
		_: return Color.WHITE


func get_type_name() -> String:
	match gene_type:
		GeneType.OFFENSIVE: return "攻击"
		GeneType.DEFENSIVE: return "防御"
		GeneType.NEURAL: return "神经"
		GeneType.REGENERATIVE: return "再生"
		GeneType.ADAPTIVE: return "适应"
		GeneType.UTILITY: return "功能"
		_: return "未知"


func is_available_for_class(character_class: String) -> bool:
	if class_restriction.is_empty():
		return true
	return character_class in class_restriction
