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
signal gene_module_unlocked(module_id: int)
signal gene_module_upgraded(module_id: int, new_level: int)
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
## 与 FastAPI `GENE_ACTIVE_SLOT_HARD_MAX` 一致：激活槽位全局硬顶
const GENE_ACTIVE_SLOT_HARD_MAX: int = 4
## 角色达到该等级后基因加成与解锁逻辑才生效（之前视为「未开放」）
const GENE_SYSTEM_OPEN_LEVEL: int = 20

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
## module_id -> GeneModuleData
var _module_defs: Dictionary = {}
## module_id -> CharacterGeneModuleState
var _module_states: Dictionary = {}
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
	_module_defs.clear()
	for raw in GameDataManager.get_all_genes():
		var def := GeneData.from_dict(raw)
		_gene_defs[def.gene_id] = def
		for m in def.gene_modules:
			var md: GeneModuleData = m as GeneModuleData
			if md and md.module_id > 0:
				_module_defs[md.module_id] = md
	print("[GeneManager] 基因定义缓存完成，共 %d 种，子基因 %d 条" % [_gene_defs.size(), _module_defs.size()])

# ══════════════════════════════════════════════════════════════════
# 初始化
# ══════════════════════════════════════════════════════════════════

## initial_points < 0 时不覆盖当前基因点（由 Stats.load_from_dict / set_gene_points 注入）
func setup(char_class: String, initial_points: int = -1) -> void:
	character_class = char_class
	if initial_points >= 0:
		set_gene_points(initial_points)


func restore_from_snapshot(data: Variant) -> void:
	_states.clear()
	_module_states.clear()
	var genes_arr: Array = []
	if data is Dictionary:
		genes_arr = data.get("genes", [])
		for entry in data.get("gene_modules", []):
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var ms := CharacterGeneModuleState.from_dict(entry)
			if ms.module_id <= 0:
				continue
			if not _module_defs.has(ms.module_id):
				continue
			_module_states[ms.module_id] = ms
	elif data is Array:
		genes_arr = data
	for entry in genes_arr:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var state := CharacterGeneState.from_dict(entry)
		if state.gene_id <= 0:
			continue
		var def: GeneData = _gene_defs.get(state.gene_id)
		if def and def.is_test:
			continue
		_states[state.gene_id] = state
	is_loaded = true
	genes_changed.emit()
	print("[GeneManager] 从快照恢复 %d 个基因，%d 个子基因" % [_states.size(), _module_states.size()])

# ══════════════════════════════════════════════════════════════════
# 核心操作
# ══════════════════════════════════════════════════════════════════

func unlock_gene(gene_id: int) -> bool:
	if not _gene_defs.has(gene_id):
		return _fail("基因定义不存在: %d" % gene_id)
	var def: GeneData = _gene_defs[gene_id]
	if def.is_test:
		return _fail("测试基因不可解锁")
	if _states.has(gene_id):
		return _fail("基因已解锁: %s" % _get_name(gene_id))
	var plv := _get_character_level()
	if plv < GENE_SYSTEM_OPEN_LEVEL:
		return _fail("需达到 %d 级解锁基因系统" % GENE_SYSTEM_OPEN_LEVEL)
	if plv < def.unlock_min_level:
		return _fail("需达到 %d 级以解锁该基因" % def.unlock_min_level)
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
	if _get_character_level() < GENE_SYSTEM_OPEN_LEVEL:
		return _fail("需达到 %d 级后升级基因" % GENE_SYSTEM_OPEN_LEVEL)
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

func _merge_bonus_into_totals(totals: Dictionary, bonus: Dictionary) -> void:
	if bonus.has("crit_rate"):
		totals["crit_rate_bonus"] += float(bonus["crit_rate"])
	if bonus.has("vs_targets") and bonus["vs_targets"] is Array:
		for row in bonus["vs_targets"]:
			if row is Dictionary:
				(totals["vs_targets"] as Array).append(row)
	if bonus.get("low_hp_immune_control", false):
		totals["low_hp_immune_control"] = true
	var oh: Variant = bonus.get("on_hit_regen_pct_of_damage", 0.0)
	if float(oh) > float(totals["on_hit_regen_pct_of_damage"]):
		totals["on_hit_regen_pct_of_damage"] = float(oh)
	var q: Variant = bonus.get("quantum_shared_stat_ratio", 0.0)
	if float(q) > float(totals["quantum_shared_stat_ratio"]):
		totals["quantum_shared_stat_ratio"] = float(q)
	var th: Variant = bonus.get("low_hp_threshold", 0.0)
	if float(th) > 0.0 and (float(totals["low_hp_threshold"]) <= 0.0 or float(th) < float(totals["low_hp_threshold"])):
		totals["low_hp_threshold"] = float(th)
	for key in totals:
		if key in ["vs_targets", "low_hp_immune_control", "on_hit_regen_pct_of_damage", "quantum_shared_stat_ratio", "low_hp_threshold"]:
			continue
		if not bonus.has(key):
			continue
		var v: Variant = bonus[key]
		if v is bool or v is Array or v is Dictionary:
			continue
		totals[key] = float(totals[key]) + float(v)


## 返回所有激活基因的属性加成总计（等级 < GENE_SYSTEM_OPEN_LEVEL 时无加成）
## 兼容 genes.json 的 crit_rate 与 crit_rate_bonus；合并 vs_targets、低血系数等；叠加已解锁子基因
func get_bonuses() -> Dictionary:
	if _get_character_level() < GENE_SYSTEM_OPEN_LEVEL:
		return _empty_gene_bonus_totals()
	var totals := _empty_gene_bonus_totals()
	for gene_id in _states:
		var state: CharacterGeneState = _states[gene_id]
		if not state.is_active:
			continue
		var def: GeneData = _gene_defs.get(gene_id)
		if def == null:
			continue
		var bonus := state.get_bonuses(def)
		_merge_bonus_into_totals(totals, bonus)
		for m in def.gene_modules:
			var md: GeneModuleData = m as GeneModuleData
			if md == null:
				continue
			var ms: CharacterGeneModuleState = _module_states.get(md.module_id) as CharacterGeneModuleState
			if ms == null or ms.current_level < 1:
				continue
			var mb := md.get_bonuses_at_level(ms.current_level)
			_merge_bonus_into_totals(totals, mb)
	totals["cooldown_reduction"] = clampf(float(totals["cooldown_reduction"]), 0.0, 0.85)
	return totals


func _empty_gene_bonus_totals() -> Dictionary:
	return {
		"attack_bonus": 0.0, "defense_bonus": 0.0, "max_health_bonus": 0.0,
		"crit_rate_bonus": 0.0, "crit_damage_bonus": 0.0, "evasion_bonus": 0.0,
		"health_regen_per_sec": 0.0, "cooldown_reduction": 0.0,
		"fire_resistance_bonus": 0.0, "poison_resistance_bonus": 0.0,
		"thorns_resistance_bonus": 0.0, "other_resistance_bonus": 0.0,
		"low_hp_attack_bonus_per_decile": 0.0, "low_hp_defense_penalty_per_decile": 0.0,
		"low_hp_defense_bonus": 0.0, "low_hp_all_stats_mult": 0.0,
		"low_hp_bonus_per_missing_hp_pct": 0.0, "low_hp_threshold": 0.0,
		"low_hp_immune_control": false,
		"damage_reduction_flat": 0.0, "experience_gain_bonus": 0.0, "gene_point_gain_bonus": 0.0,
		"crit_bonus_vs_current_hp_pct": 0.0, "on_hit_regen_pct_of_damage": 0.0,
		"quantum_shared_stat_ratio": 0.0,
		"vs_targets": [],
	}


func _get_character_level() -> int:
	var p := CharacterDataManager.get_player() if CharacterDataManager else null
	if p == null:
		return 1
	var st = p.get("player_stats")
	if st != null and st is Stats:
		return (st as Stats).level
	return 1


## 玩家 outgoing 伤害：按目标 combat_tags 应用 vs_targets（倍率相乘，flat 相加）
func apply_outgoing_damage_vs_tags(base_damage: float, target_tags: Array) -> float:
	var d := base_damage
	var gb := get_bonuses()
	var rows: Array = gb.get("vs_targets", [])
	if rows.is_empty():
		return d
	var tag_set := {}
	for t in target_tags:
		tag_set[str(t).to_upper()] = true
	for row in rows:
		if not row is Dictionary:
			continue
		var tags: Array = row.get("tags", [])
		if tags.is_empty():
			continue
		var match_any := false
		for tg in tags:
			if tag_set.has(str(tg).to_upper()):
				match_any = true
				break
		if not match_any:
			continue
		var mult := float(row.get("damage_multiplier", 1.0))
		var flat := float(row.get("flat_damage", 0.0))
		d = d * mult + flat
	return maxf(d, 0.0)


## 暴击时对目标当前生命值百分比附加伤害（由武器/技能在暴击分支调用）
func get_crit_bonus_damage_from_target_current_hp(target_current_hp: float) -> float:
	var pct := float(get_bonuses().get("crit_bonus_vs_current_hp_pct", 0.0))
	if pct <= 0.0:
		return 0.0
	return maxf(target_current_hp * pct, 0.0)

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
	var n: int = int(CLASS_SLOT_LIMITS.get(character_class, DEFAULT_SLOT_LIMIT))
	return mini(n, GENE_ACTIVE_SLOT_HARD_MAX)


func _normalize_module_line_id(s: Variant) -> String:
	var t := str(s if s != null else "main").strip_edges()
	return t if not t.is_empty() else "main"


func _count_unlocked_modules_under_parent(parent_gene_id: int) -> int:
	var n := 0
	for mid in _module_states:
		var st: CharacterGeneModuleState = _module_states[mid] as CharacterGeneModuleState
		if st == null or st.current_level < 1:
			continue
		var md: GeneModuleData = _module_defs.get(mid) as GeneModuleData
		if md and md.parent_gene_id == parent_gene_id:
			n += 1
	return n


func _count_unlocked_modules_on_parent_line(parent_gene_id: int, line_id: String) -> int:
	var lid := _normalize_module_line_id(line_id)
	var n := 0
	for mid in _module_states:
		var st: CharacterGeneModuleState = _module_states[mid] as CharacterGeneModuleState
		if st == null or st.current_level < 1:
			continue
		var md: GeneModuleData = _module_defs.get(mid) as GeneModuleData
		if md and md.parent_gene_id == parent_gene_id and _normalize_module_line_id(md.line_id) == lid:
			n += 1
	return n


func _unlock_materials_satisfied(mats: Array) -> bool:
	if mats.is_empty():
		return true
	for entry in mats:
		if not entry is Dictionary:
			continue
		var d: Dictionary = entry
		var iid := int(d.get("item_id", 0))
		var q := int(d.get("quantity", 0))
		if iid <= 0 or q <= 0:
			continue
		if InventoryManager and not InventoryManager.has_item(str(iid), q):
			return false
	return true


## 与后端 `_assert_sub_gene_unlock_allowed` 对齐的本地预检；"" 表示可请求 API
func can_unlock_gene_module(module_id: int) -> String:
	if not _module_defs.has(module_id):
		return "未知子基因"
	var md: GeneModuleData = _module_defs[module_id] as GeneModuleData
	if md == null:
		return "未知子基因"
	var existing: CharacterGeneModuleState = _module_states.get(module_id) as CharacterGeneModuleState
	if existing != null and existing.current_level >= 1:
		return "已解锁"
	if _get_character_level() < GENE_SYSTEM_OPEN_LEVEL:
		return "基因系统未开放"
	if not _states.has(md.parent_gene_id):
		return "需先解锁宿主主基因"
	var pdef: GeneData = _gene_defs.get(md.parent_gene_id) as GeneData
	if pdef == null:
		return "主基因定义缺失"
	for pre in md.prerequisite_module_ids:
		var pst: CharacterGeneModuleState = _module_states.get(pre) as CharacterGeneModuleState
		if pst == null or pst.current_level < 1:
			return "缺少前置子基因"
	var lims: Dictionary = pdef.sub_gene_limits
	if not lims.is_empty():
		if lims.has("max_modules_total"):
			var cap_t := int(lims.get("max_modules_total", 0))
			if cap_t > 0 and _count_unlocked_modules_under_parent(md.parent_gene_id) >= cap_t:
				return "该主基因子基因数量已达上限（%d）" % cap_t
		var line_caps: Variant = lims.get("max_modules_per_line", {})
		if line_caps is Dictionary:
			var lc: Dictionary = line_caps
			var line := _normalize_module_line_id(md.line_id)
			if lc.has(line):
				var cap_l := int(lc[line])
				if cap_l > 0 and _count_unlocked_modules_on_parent_line(md.parent_gene_id, line) >= cap_l:
					return "线路「%s」子基因已达上限（%d）" % [line, cap_l]
	if gene_points < md.unlock_gene_points:
		return "基因点不足（需 %d）" % md.unlock_gene_points
	if not _unlock_materials_satisfied(md.unlock_materials):
		return "背包材料不足"
	return ""

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
	var def: GeneData = _gene_defs[gene_id]
	if def.is_test: return "测试基因"
	if _states.has(gene_id): return "已解锁"
	var plv := _get_character_level()
	if plv < GENE_SYSTEM_OPEN_LEVEL:
		return "需达到%d级解锁基因系统" % GENE_SYSTEM_OPEN_LEVEL
	if plv < def.unlock_min_level:
		return "需达到%d级" % def.unlock_min_level
	if not def.is_available_for_class(character_class): return "职业限制"
	var m := _check_prerequisites(def)
	if not m.is_empty(): return "缺少前置：" + m
	if gene_points < _unlock_cost(def): return "点数不足（需 %d）" % _unlock_cost(def)
	return ""

func can_upgrade(gene_id: int) -> String:
	if _get_character_level() < GENE_SYSTEM_OPEN_LEVEL:
		return "基因系统未开放"
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
		var st := state as CharacterGeneState
		var def: GeneData = _gene_defs.get(st.gene_id)
		if def and def.is_test:
			continue
		r.append(st.to_dict())
	return r


func get_serializable_module_state() -> Array:
	var r := []
	for st in _module_states.values():
		var x := st as CharacterGeneModuleState
		if x == null or not _module_defs.has(x.module_id):
			continue
		r.append(x.to_dict())
	return r


func get_module_state(module_id: int) -> CharacterGeneModuleState:
	return _module_states.get(module_id) as CharacterGeneModuleState


func get_module_def(module_id: int) -> GeneModuleData:
	return _module_defs.get(module_id) as GeneModuleData


## 与后端 POST .../genes/unlock 对齐，成功后刷新本地状态与 gene_points
func unlock_gene_via_api(gene_id: int, callback: Callable = Callable()) -> void:
	var cid: String = UserManager.current_character_id if UserManager else ""
	if cid.is_empty():
		operation_failed.emit("无角色 ID")
		if callback.is_valid():
			callback.call(false, {"message": "无角色 ID"})
		return
	ApiManager.unlock_gene(cid, gene_id, func(ok: bool, resp: Variant):
		if not ok:
			var msg := str(resp.get("message", "失败")) if resp is Dictionary else "失败"
			operation_failed.emit(msg)
			if callback.is_valid():
				callback.call(false, resp)
			return
		if resp is Dictionary:
			_apply_main_gene_server_state(resp as Dictionary)
		if callback.is_valid():
			callback.call(true, resp)
	)


## 与后端 POST .../genes/upgrade 对齐
func upgrade_gene_via_api(gene_id: int, callback: Callable = Callable()) -> void:
	var cid: String = UserManager.current_character_id if UserManager else ""
	if cid.is_empty():
		operation_failed.emit("无角色 ID")
		if callback.is_valid():
			callback.call(false, {"message": "无角色 ID"})
		return
	ApiManager.upgrade_gene(cid, gene_id, func(ok: bool, resp: Variant):
		if not ok:
			var msg := str(resp.get("message", "失败")) if resp is Dictionary else "失败"
			operation_failed.emit(msg)
			if callback.is_valid():
				callback.call(false, resp)
			return
		if resp is Dictionary:
			_apply_main_gene_server_state(resp as Dictionary)
		if callback.is_valid():
			callback.call(true, resp)
	)


func _apply_main_gene_server_state(resp: Dictionary) -> void:
	var gid := int(resp.get("gene_id", 0))
	if gid <= 0:
		return
	_states[gid] = CharacterGeneState.from_dict(resp)
	if resp.has("gene_points"):
		set_gene_points(maxi(int(resp.get("gene_points", 0)), 0))
	genes_changed.emit()


## 子基因解锁（服务端扣点 + 扣背包材料）；成功后用响应刷新本地
func unlock_gene_module_via_api(module_id: int, callback: Callable = Callable()) -> void:
	var cid: String = UserManager.current_character_id if UserManager else ""
	if cid.is_empty():
		operation_failed.emit("无角色 ID")
		if callback.is_valid():
			callback.call(false, {"message": "无角色 ID"})
		return
	if not _module_defs.has(module_id):
		operation_failed.emit("未知子基因")
		if callback.is_valid():
			callback.call(false, {"message": "未知子基因"})
		return
	var pre_err := can_unlock_gene_module(module_id)
	if not pre_err.is_empty():
		operation_failed.emit(pre_err)
		if callback.is_valid():
			callback.call(false, {"message": pre_err})
		return
	ApiManager.unlock_gene_module(cid, module_id, func(ok: bool, resp: Variant):
		if not ok:
			var msg := str(resp.get("message", "失败")) if resp is Dictionary else "失败"
			operation_failed.emit(msg)
			if callback.is_valid():
				callback.call(false, resp)
			return
		if resp is Dictionary:
			_apply_module_op_result(resp as Dictionary, true)
		if callback.is_valid():
			callback.call(true, resp)
	)


func upgrade_gene_module_via_api(module_id: int, callback: Callable = Callable()) -> void:
	var cid: String = UserManager.current_character_id if UserManager else ""
	if cid.is_empty():
		operation_failed.emit("无角色 ID")
		if callback.is_valid():
			callback.call(false, {"message": "无角色 ID"})
		return
	ApiManager.upgrade_gene_module(cid, module_id, func(ok: bool, resp: Variant):
		if not ok:
			var msg := str(resp.get("message", "失败")) if resp is Dictionary else "失败"
			operation_failed.emit(msg)
			if callback.is_valid():
				callback.call(false, resp)
			return
		if resp is Dictionary:
			_apply_module_op_result(resp as Dictionary, false)
		if callback.is_valid():
			callback.call(true, resp)
	)


func _apply_module_op_result(resp: Dictionary, is_unlock: bool) -> void:
	var mid := int(resp.get("module_id", 0))
	if mid <= 0:
		return
	_module_states[mid] = CharacterGeneModuleState.new(
		mid, int(resp.get("current_level", 1)), int(resp.get("points_spent", 0))
	)
	if resp.has("gene_points"):
		set_gene_points(maxi(int(resp.get("gene_points", 0)), 0))
	if is_unlock:
		gene_module_unlocked.emit(mid)
	else:
		gene_module_upgraded.emit(mid, int(resp.get("current_level", 1)))
	genes_changed.emit()
	# 服务端已扣材料，同步背包
	if CharacterDataManager and CharacterDataManager.has_method("refresh_inventory_from_api"):
		CharacterDataManager.refresh_inventory_from_api()

# ══════════════════════════════════════════════════════════════════
# 基因点数
# ══════════════════════════════════════════════════════════════════

func add_gene_points(amount: int) -> void:
	if amount <= 0:
		return
	var mult := 1.0 + float(get_bonuses().get("gene_point_gain_bonus", 0.0))
	gene_points += int(round(float(amount) * mult))
	gene_points_changed.emit(gene_points)


## 发放基因点（任务等）：不受等级门控影响加成倍率
func add_gene_points_raw(amount: int) -> void:
	if amount <= 0:
		return
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
