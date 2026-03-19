extends Node

## CharacterDataManager — 角色数据加载/保存统一入口
##
## 职责：快照/恢复（减少场景切换时的 API 调用）、存档到 API
## 使用：Player._ready 末尾调用 restore_to_player(self)
##       场景切换前调用 snapshot_before_scene_change()
##       存档时调用 save_to_api()

signal character_data_loaded
signal character_data_save_completed
signal data_error(reason: String)

const PLAYER_GROUP := "Player"

## 运行时快照（场景切换前存入，新场景恢复用）
var _stats_snapshot: Dictionary = {}
var _inventory_snapshot: Array = []
var _skills_snapshot: Dictionary = {}
var _genes_snapshot: Array = []
var _last_api_save_time: float = 0.0
const API_SAVE_COOLDOWN := 10.0


## 从 API 加载并应用到 Player（首次进入 / 无快照时）
## 场景 _ready 中可调用，或由 restore_to_player 内部触发
func load_and_apply() -> void:
	if UserManager.current_character_id.is_empty():
		return
	if GameDataManager.is_loaded():
		_load_player_data_from_api()
	else:
		if not GameDataManager.all_data_loaded.is_connected(_on_game_data_loaded):
			GameDataManager.all_data_loaded.connect(_on_game_data_loaded, CONNECT_ONE_SHOT)


func _on_game_data_loaded() -> void:
	_load_player_data_from_api()


## 场景切换前调用：快照当前状态到内存
func snapshot_before_scene_change() -> void:
	_take_snapshot()


## 新场景 Player._ready 末尾调用：从快照或 API 恢复数据
func restore_to_player(player: Node) -> void:
	var cid := UserManager.current_character_id
	if cid.is_empty():
		push_warning("[CharacterDataManager] character_id 未设置，跳过恢复")
		return

	SkillManager.character = player

	if not _stats_snapshot.is_empty():
		var stats = player.get("playerStats")
		if stats and stats.has_method("load_from_dict"):
			stats.load_from_dict(_stats_snapshot)
	else:
		_restore_stats_from_api(player)

	if not _inventory_snapshot.is_empty():
		InventoryManager.load_serializable_inventory(_inventory_snapshot)
	else:
		_restore_inventory_from_api()

	if not _skills_snapshot.is_empty():
		SkillManager.load_skills_data(_skills_snapshot)
	else:
		_restore_skills_from_api()

	if not _genes_snapshot.is_empty():
		GeneManager.restore_from_snapshot(_genes_snapshot)
	else:
		_restore_genes_from_api()


func _load_player_data_from_api() -> void:
	var cid := UserManager.current_character_id
	if cid.is_empty():
		return

	var loaded := [0]
	var required := 4
	var _on_loaded := func():
		loaded[0] += 1
		if loaded[0] >= required:
			character_data_loaded.emit()

	ApiManager.load_inventory(cid, func(success, resp):
		if success and resp.has("slots"):
			InventoryManager.load_serializable_inventory(resp["slots"])
			_inventory_snapshot = resp["slots"]
		_on_loaded.call()
	)

	ApiManager.load_skills(cid, func(success, resp):
		if success and resp.has("skills"):
			var raw = resp["skills"]
			var skills_dict := {}
			for k in raw:
				var v = raw[k]
				skills_dict[k] = {"level": int(v.get("level", 1)), "cooldown_remaining": 0.0}
			SkillManager.load_skills_data(skills_dict)
			_skills_snapshot = skills_dict
		_on_loaded.call()
	)

	ApiManager.load_stats(cid, func(success, resp):
		if success and resp is Dictionary:
			_stats_snapshot = resp
			_apply_stats_to_player(resp)
			print("角色属性已从服务器加载")
		_on_loaded.call()
	)

	ApiManager.load_genes(cid, func(success, resp):
		if success and resp is Dictionary:
			var genes_arr: Array = resp.get("genes", [])
			_genes_snapshot = genes_arr
			GeneManager.restore_from_snapshot(genes_arr)
			print("角色基因已从服务器加载")
		_on_loaded.call()
	)


func _apply_stats_to_player(stats_dict: Dictionary) -> void:
	var player := get_player()
	if not player:
		return
	var stats = player.get("playerStats")
	if stats and stats.has_method("load_from_dict"):
		stats.load_from_dict(stats_dict)


func _restore_stats_from_api(player: Node) -> void:
	var cid := UserManager.current_character_id
	ApiManager.load_stats(cid, func(success, resp):
		if success and resp is Dictionary:
			_stats_snapshot = resp
			var stats = player.get("playerStats")
			if stats and stats.has_method("load_from_dict"):
				stats.load_from_dict(resp)
	)


func _restore_inventory_from_api() -> void:
	var cid := UserManager.current_character_id
	ApiManager.load_inventory(cid, func(success, resp):
		if success and resp.has("slots"):
			_inventory_snapshot = resp["slots"]
			InventoryManager.load_serializable_inventory(resp["slots"])
	)


func _restore_skills_from_api() -> void:
	var cid := UserManager.current_character_id
	ApiManager.load_skills(cid, func(success, resp):
		if success and resp.has("skills"):
			var raw = resp["skills"]
			var skills_dict := {}
			for k in raw:
				var v = raw[k]
				skills_dict[k] = {"level": int(v.get("level", 1)), "cooldown_remaining": 0.0}
			_skills_snapshot = skills_dict
			SkillManager.load_skills_data(skills_dict)
	)


func _restore_genes_from_api() -> void:
	var cid := UserManager.current_character_id
	ApiManager.load_genes(cid, func(success, resp):
		if success and resp is Dictionary:
			var genes_arr: Array = resp.get("genes", [])
			_genes_snapshot = genes_arr
			GeneManager.restore_from_snapshot(genes_arr)
	)


func _take_snapshot() -> void:
	var player := get_player()
	if player:
		var stats = player.get("playerStats")
		if stats and stats.has_method("save_to_dict"):
			_stats_snapshot = stats.save_to_dict()
	_inventory_snapshot = InventoryManager.get_serializable_inventory()
	_skills_snapshot = SkillManager.save_skills_data()
	_genes_snapshot = GeneManager.get_serializable_state()


func get_player() -> Node:
	return get_tree().get_first_node_in_group(PLAYER_GROUP) if get_tree() else null


## 保存到 API，force=true 忽略冷却（登出等）
func save_to_api(callback: Callable = Callable(), force: bool = false) -> void:
	var cid := UserManager.current_character_id
	if cid.is_empty():
		if callback.is_valid():
			callback.call(false, null)
		return

	var now := Time.get_ticks_msec() / 1000.0
	if not force and (now - _last_api_save_time) < API_SAVE_COOLDOWN:
		if callback.is_valid():
			callback.call(true, null)
		return

	_take_snapshot()
	_last_api_save_time = now

	var pending := [4 if not _stats_snapshot.is_empty() else 3]
	var any_failed := [false]

	var _check_done := func():
		pending[0] -= 1
		if pending[0] <= 0:
			character_data_save_completed.emit()
			if callback.is_valid():
				callback.call(not any_failed[0], null)

	ApiManager.save_inventory(cid, _inventory_snapshot, func(success, _resp):
		if not success:
			any_failed[0] = true
			data_error.emit("背包保存失败")
		_check_done.call()
	)

	ApiManager.save_skills(cid, _skills_snapshot, func(success, _resp):
		if not success:
			any_failed[0] = true
			data_error.emit("技能保存失败")
		_check_done.call()
	)

	ApiManager.save_genes(cid, _genes_snapshot, func(success, _resp):
		if not success:
			any_failed[0] = true
			data_error.emit("基因保存失败")
		_check_done.call()
	)

	if not _stats_snapshot.is_empty():
		ApiManager.save_stats(cid, _stats_snapshot, func(success, _resp):
			if not success:
				any_failed[0] = true
				data_error.emit("属性保存失败")
			_check_done.call()
		)
