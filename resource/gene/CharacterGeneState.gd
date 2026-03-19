## CharacterGeneState.gd — 角色已解锁基因的运行时状态
##
## 对标 InventoryItem.gd：实例状态
## 脏标记缓存：_cache_dirty，get_bonuses() 懒加载，避免每帧查表

extends Resource
class_name CharacterGeneState

# ══════════════════════════════════════════════════════════════════
# 核心状态
# ══════════════════════════════════════════════════════════════════

var gene_id: int = 0
var current_level: int = 1
var is_active: bool = true
var points_spent: int = 0

var _cached_bonuses: Dictionary = {}
var _cache_dirty: bool = true


# ══════════════════════════════════════════════════════════════════
# 构造
# ══════════════════════════════════════════════════════════════════

func _init(
	p_gene_id: int = 0,
	p_level: int = 1,
	p_active: bool = true,
	p_points_spent: int = 0
) -> void:
	gene_id = p_gene_id
	current_level = p_level
	is_active = p_active
	points_spent = p_points_spent
	_cache_dirty = true


# ══════════════════════════════════════════════════════════════════
# 等级与激活
# ══════════════════════════════════════════════════════════════════

func level_up(cost: int = 0) -> int:
	current_level += 1
	points_spent += cost
	_cache_dirty = true
	return current_level


func set_level(level: int) -> void:
	current_level = level
	_cache_dirty = true


func activate() -> void:
	is_active = true
	_cache_dirty = true


func deactivate() -> void:
	is_active = false
	_cache_dirty = true


# ══════════════════════════════════════════════════════════════════
# 加成缓存（懒加载）
# ══════════════════════════════════════════════════════════════════

func get_bonuses(gene_data: GeneData) -> Dictionary:
	if not is_active:
		return {}
	if _cache_dirty:
		_cached_bonuses = gene_data.get_bonuses_at_level(current_level)
		_cache_dirty = false
	return _cached_bonuses


func invalidate_cache() -> void:
	_cache_dirty = true


# ══════════════════════════════════════════════════════════════════
# 序列化
# ══════════════════════════════════════════════════════════════════

func to_dict() -> Dictionary:
	return {
		"gene_id": gene_id,
		"current_level": current_level,
		"is_active": is_active,
		"points_spent": points_spent,
	}


static func from_dict(d: Dictionary) -> CharacterGeneState:
	return CharacterGeneState.new(
		int(d.get("gene_id", 0)),
		int(d.get("current_level", 1)),
		bool(d.get("is_active", true)),
		int(d.get("points_spent", 0))
	)
