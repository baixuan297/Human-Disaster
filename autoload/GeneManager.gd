## GeneManager.gd — Autoload 基因系统核心管理器
##
## 职责：基因定义缓存、角色基因状态、槽位/前置检查、属性加成汇总
## 与 CharacterDataManager 对接：restore_from_snapshot / get_serializable_state
## 与 Stats 对接：genes_changed → recalculate_stats；get_bonuses() 提供加成

extends Node

# ══════════════════════════════════════════════════════════════════
# 信号
# ══════════════════════════════════════════════════════════════════

## 任何基因状态变化 — Stats.recalculate_stats 监听
signal genes_changed
signal gene_unlocked(gene_id: int)
signal gene_upgraded(gene_id: int, new_level: int)
signal gene_toggled(gene_id: int, is_active: bool)
signal operation_failed(reason: String)
signal gene_points_changed(new_total: int)

# ══════════════════════════════════════════════════════════════════
# 槽位与消耗
# ══════════════════════════════════════════════════════════════════

const CLASS_SLOT_LIMITS: Dictionary = {
	"Void Walker": 4, "Bio Shaper": 4, "Regeneration Guardian": 4,
	"Predator Striker": 3, "Berserk Mutant": 3, "Quantum Sniper": 3,
	"Hacker Phantom": 3, "Titan Vanguard": 3, "Drone Commander": 3,
	"Spore Alchemist": 3, "Singularity Knight": 3,
}
const DEFAULT_SLOT_LIMIT: int = 3

const UPGRADE_COST_PER_LEVEL: Dictionary = {
	"COMMON": 1, "UNCOMMON": 2, "RARE": 3, "EPIC": 5, "LEGENDARY": 8,
}
const UNLOCK_COST: Dictionary = {
	"COMMON": 2, "UNCOMMON": 4, "RARE": 8, "EPIC": 15, "LEGENDARY": 25,
}

# ══════════════════════════════════════════════════════════════════
# 内部数据
# ══════════════════════════════════════════════════════════════════

var _gene_defs: Dictionary = {}
var _states: Dictionary = {}
var character_class: String = ""
var gene_points: int = 0
var is_loaded: bool = false

# ══════════════════════════════════════════════════════════════════
# 生命周期
# ══════════════════════════════════════════════════════════════════

func _ready() -> void:
	_build_gene_defs.call_deferred()


func _build_gene_defs() -> void:
	if GameDataManager.is_loaded():
		_load_defs_from_game_data()
	else:
		GameDataManager.all_data_loaded.connect(_load_defs_from_game_data, CONNECT_ONE_SHOT)


func _load_defs_from_game_data() -> void:
	_gene_defs.clear()
	for raw in GameDataManager.get_all_genes():
		var def := GeneData.from_dict(raw)
		_gene_defs[def.gene_id] = def
	print("[GeneManager] 基因定义缓存完成，共 %d 种" % _gene_defs.size())

# ══════════════════════════════════════════════════════════════════
# 初始化
# ══════════════════════════════════════════════════════════════════

func setup(char_class: String, initial_points: int = 0) -> void:
	character_class = char_class
	gene_points = initial_points


func restore_from_snapshot(data: Array) -> void:
	_states.clear()
	for entry in data:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var state := CharacterGeneState.from_dict(entry)
		if state.gene_id > 0:
			_states[state.gene_id] = state
	is_loaded = true
	genes_changed.emit()
	print("[GeneManager] 从快照恢复 %d 个基因" % _states.size())

# ══════════════════════════════════════════════════════════════════
# 核心操作
# ══════════════════════════════════════════════════════════════════

func unlock_gene(gene_id: int) -> bool:
	if not _gene_defs.has(gene_id):
		return _fail("基因定义不存在: %d" % gene_id)
	if _states.has(gene_id):
		return _fail("基因已解锁: %s" % _get_name(gene_id))
	var def: GeneData = _gene_defs[gene_id]
	if not def.is_available_for_class(character_class):
		return _fail("职业限制：%s 无法解锁 %s" % [character_class, def.gene_name])
	var missing := _check_prerequisites(def)
	if not missing.is_empty():
		return _fail("缺少前置基因：%s" % missing)
	var cost := _unlock_cost(def)
	if gene_points < cost:
		return _fail("基因点数不足（需要 %d，当前 %d）" % [cost, gene_points])
	_deduct_points(cost)
	_states[gene_id] = CharacterGeneState.new(gene_id, 1, false, cost)
	gene_unlocked.emit(gene_id)
	genes_changed.emit()
	return true


func upgrade_gene(gene_id: int) -> bool:
	var state := _require_state(gene_id)
	if state == null:
		return false
	var def: GeneData = _gene_defs[gene_id]
	if state.current_level >= def.max_level:
		return _fail("%s 已达最大等级 %d" % [def.gene_name, def.max_level])
	var cost := _upgrade_cost(def)
	if gene_points < cost:
		return _fail("基因点数不足（需要 %d，当前 %d）" % [cost, gene_points])
	_deduct_points(cost)
	var new_level := state.level_up(cost)
	gene_upgraded.emit(gene_id, new_level)
	genes_changed.emit()
	return true


func activate_gene(gene_id: int) -> bool:
	var state := _require_state(gene_id)
	if state == null:
		return false
	if state.is_active:
		return true
	if get_active_count() >= get_slot_limit():
		return _fail("槽位已满（上限 %d），请先停用一个基因" % get_slot_limit())
	state.activate()
	gene_toggled.emit(gene_id, true)
	genes_changed.emit()
	return true


func deactivate_gene(gene_id: int) -> bool:
	var state := _require_state(gene_id)
	if state == null:
		return false
	if not state.is_active:
		return true
	state.deactivate()
	gene_toggled.emit(gene_id, false)
	genes_changed.emit()
	return true


func toggle_gene(gene_id: int) -> bool:
	var state := _states.get(gene_id) as CharacterGeneState
	if state == null:
		return _fail("基因未解锁: %s" % _get_name(gene_id))
	return activate_gene(gene_id) if not state.is_active else deactivate_gene(gene_id)

# ══════════════════════════════════════════════════════════════════
# 属性加成（Stats.recalculate_stats 调用）
# ══════════════════════════════════════════════════════════════════

## 返回所有激活基因的属性加成总计
## 兼容 genes.json 的 crit_rate 与 crit_rate_bonus
func get_bonuses() -> Dictionary:
	var totals := {
		"attack_bonus": 0.0, "defense_bonus": 0.0, "max_health_bonus": 0.0,
		"crit_rate_bonus": 0.0, "crit_damage_bonus": 0.0, "evasion_bonus": 0.0,
		"health_regen_per_sec": 0.0, "cooldown_reduction": 0.0,
	}
	for gene_id in _states:
		var state: CharacterGeneState = _states[gene_id]
		if not state.is_active:
			continue
		var def: GeneData = _gene_defs.get(gene_id)
		if def == null:
			continue
		var bonus := state.get_bonuses(def)
		for key in totals:
			if bonus.has(key):
				totals[key] += float(bonus[key])
		## genes.json 部分基因用 crit_rate 而非 crit_rate_bonus
		if bonus.has("crit_rate"):
			totals["crit_rate_bonus"] += float(bonus["crit_rate"])
	return totals

# ══════════════════════════════════════════════════════════════════
# 查询
# ══════════════════════════════════════════════════════════════════

func has_gene(gene_id: int) -> bool:
	return _states.has(gene_id)

func get_gene_level(gene_id: int) -> int:
	return _states[gene_id].current_level if _states.has(gene_id) else 0

func get_active_count() -> int:
	var n := 0
	for s in _states.values():
		if (s as CharacterGeneState).is_active:
			n += 1
	return n

func get_slot_limit() -> int:
	return CLASS_SLOT_LIMITS.get(character_class, DEFAULT_SLOT_LIMIT)

func get_all_unlocked_ids() -> Array[int]:
	var r: Array[int] = []
	for gid in _states:
		r.append(gid)
	return r

func get_active_ids() -> Array[int]:
	var r: Array[int] = []
	for gid in _states:
		if (_states[gid] as CharacterGeneState).is_active:
			r.append(gid)
	return r

func get_gene_def(gene_id: int) -> GeneData:
	return _gene_defs.get(gene_id)

func get_gene_state(gene_id: int) -> CharacterGeneState:
	return _states.get(gene_id)

func get_available_defs_for_class() -> Array[GeneData]:
	var r: Array[GeneData] = []
	for def in _gene_defs.values():
		if (def as GeneData).is_available_for_class(character_class):
			r.append(def)
	return r

func can_unlock(gene_id: int) -> String:
	if not _gene_defs.has(gene_id): return "基因不存在"
	if _states.has(gene_id): return "已解锁"
	var def: GeneData = _gene_defs[gene_id]
	if not def.is_available_for_class(character_class): return "职业限制"
	var m := _check_prerequisites(def)
	if not m.is_empty(): return "缺少前置：" + m
	if gene_points < _unlock_cost(def): return "点数不足（需 %d）" % _unlock_cost(def)
	return ""

func can_upgrade(gene_id: int) -> String:
	if not _states.has(gene_id): return "未解锁"
	var state: CharacterGeneState = _states[gene_id]
	var def: GeneData = _gene_defs[gene_id]
	if state.current_level >= def.max_level: return "已满级"
	if gene_points < _upgrade_cost(def): return "点数不足（需 %d）" % _upgrade_cost(def)
	return ""

# ══════════════════════════════════════════════════════════════════
# 序列化
# ══════════════════════════════════════════════════════════════════

func get_serializable_state() -> Array:
	var r := []
	for state in _states.values():
		r.append((state as CharacterGeneState).to_dict())
	return r

# ══════════════════════════════════════════════════════════════════
# 基因点数
# ══════════════════════════════════════════════════════════════════

func add_gene_points(amount: int) -> void:
	gene_points += amount
	gene_points_changed.emit(gene_points)

func set_gene_points(amount: int) -> void:
	gene_points = amount
	gene_points_changed.emit(gene_points)

# ══════════════════════════════════════════════════════════════════
# 内部工具
# ══════════════════════════════════════════════════════════════════

func _check_prerequisites(def: GeneData) -> String:
	if def.prerequisite_gene_ids.is_empty():
		return ""
	var missing: Array[String] = []
	for req_id in def.prerequisite_gene_ids:
		if not _states.has(req_id):
			var req_def: GeneData = _gene_defs.get(req_id)
			missing.append(req_def.gene_name if req_def else "ID:%d" % req_id)
	return ", ".join(missing)

func _unlock_cost(def: GeneData) -> int:
	return UNLOCK_COST.get(GeneData.GeneRarity.keys()[def.rarity], 4)

func _upgrade_cost(def: GeneData) -> int:
	return UPGRADE_COST_PER_LEVEL.get(GeneData.GeneRarity.keys()[def.rarity], 2)

func _deduct_points(cost: int) -> void:
	gene_points = maxi(gene_points - cost, 0)
	gene_points_changed.emit(gene_points)

func _require_state(gene_id: int) -> CharacterGeneState:
	if not _states.has(gene_id):
		_fail("基因未解锁: %s" % _get_name(gene_id))
		return null
	return _states[gene_id]

func _get_name(gene_id: int) -> String:
	var def: GeneData = _gene_defs.get(gene_id)
	return def.gene_name if def else "ID:%d" % gene_id

func _fail(reason: String) -> bool:
	push_warning("[GeneManager] " + reason)
	operation_failed.emit(reason)
	return false
