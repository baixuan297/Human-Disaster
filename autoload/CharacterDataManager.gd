extends Node

## CharacterDataManager — 角色数据加载/保存统一入口
##
## 职责：快照/恢复（减少场景切换时的 API 调用）、存档到 API、与 LocalCharacterSave 协同本地加密快存
## 使用：Player._ready 末尾调用 restore_to_player(self)
##       场景切换前调用 snapshot_before_scene_change()
##       存档时调用 save_to_api()
##       仅需防闪退时可 save_local_checkpoint_now()
## 退出：窗口关闭 / 主菜单「退出」会 force 保存背包、技能、属性、基因、武器弹药与当前槽位（loadout）

signal character_data_loaded
signal character_data_save_completed
signal data_error(reason: String)

const PLAYER_GROUP := "Player"

## 运行时快照（场景切换前存入，新场景恢复用）
var _stats_snapshot: Dictionary = {}
var _inventory_snapshot: Array = []
var _skills_snapshot: Dictionary = {}
## 基因快照：可为 { "genes": [], "gene_modules": [] } 或旧版仅 genes 数组
var _genes_snapshot: Variant = []
var _scene_state_snapshot: Dictionary = {}  ## scene_path, position, rotation_y, collected_pickables
var _collected_pickables: Array[String] = []  ## 已拾取物唯一 ID 列表（scene_path|node_path）
var _scene_state_ready_callbacks: Array[Callable] = []
var _last_api_save_time: float = 0.0
const API_SAVE_COOLDOWN := 10.0
## 自动写入本地加密快存（秒）；防闪退，与云端冷却独立
const LOCAL_CHECKPOINT_INTERVAL_SEC := 18.0

var _local_checkpoint_timer: Timer


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not data_error.is_connected(_on_data_error_notify_user):
		data_error.connect(_on_data_error_notify_user)
	get_tree().auto_accept_quit = false
	var win := get_window()
	if win.close_requested.connect(_on_main_window_close_requested) != OK:
		push_warning("[CharacterDataManager] 无法连接 close_requested，关窗时可能不会自动存档")

	_local_checkpoint_timer = Timer.new()
	_local_checkpoint_timer.wait_time = LOCAL_CHECKPOINT_INTERVAL_SEC
	_local_checkpoint_timer.autostart = true
	_local_checkpoint_timer.timeout.connect(_on_local_checkpoint_timer)
	add_child(_local_checkpoint_timer)


## 存档 API 失败时：控制台记录 + 全局 Toast（GBMssage），避免仅 push_warning 不可见
func _on_data_error_notify_user(reason: String) -> void:
	if reason.is_empty():
		return
	push_warning("[CharacterDataManager] " + reason)
	call_deferred("_deferred_show_save_error_toast", reason)


func _deferred_show_save_error_toast(_reason: String) -> void:
	GlobalMessage.emit_toast("存档同步失败，请检查网络后重试", "error")


func _on_main_window_close_requested() -> void:
	save_on_exit_then_quit()


## 关窗 / 主菜单「退出」：先异步存档再退出引擎
func save_on_exit_then_quit() -> void:
	if UserManager.current_character_id.is_empty():
		get_tree().quit()
		return
	var p := get_player()
	if p == null:
		get_tree().quit()
		return
	save_to_api(func(_ok, _d): get_tree().quit(), true)


func _schedule_weapon_loadout_apply(player: Node, loadout: Variant) -> void:
	if typeof(loadout) != TYPE_DICTIONARY:
		return
	var d: Dictionary = loadout
	if d.is_empty():
		return
	if player.has_method("restore_weapon_loadout"):
		player.call_deferred("restore_weapon_loadout", d)


## 记录可拾取物已被拾取（WorldWeapon.pickup 时调用，respawn_on_reload=false 时）
## force=true 确保拾取后立即保存位置与武器，不受冷却限制
func record_pickable_collected(scene_path: String, node_path: String) -> void:
	var id_str := scene_path + "|" + node_path
	if id_str in _collected_pickables:
		return
	_collected_pickables.append(id_str)
	save_to_api(Callable(), true)


## 获取已拾取物 ID 列表（WorldWeapon 检查是否应隐藏）
func get_collected_pickables() -> Array:
	return _collected_pickables.duplicate()


## 是否已完成新手教程（来自最近一次拉取的 /stats 快照；未完成或中途退出均为 false）
## 无当前角色 ID 时视为「本地/访客」，不强制云端教程标记。
func has_tutorial_completed() -> bool:
	if UserManager.current_character_id.is_empty():
		return true
	if _stats_snapshot.is_empty():
		return false
	return bool(_stats_snapshot.get("tutorial_completed", false))


## 主菜单 / 模式选择：仅拉取 `/stats` 更新 `_stats_snapshot`（无 Player 时不写回节点）
func fetch_stats_snapshot_for_menu(callback: Callable = Callable()) -> void:
	var cid := UserManager.current_character_id
	if cid.is_empty():
		if callback.is_valid():
			callback.call(false)
		return
	ApiManager.load_stats(cid, func(success, resp):
		if success and resp is Dictionary:
			_stats_snapshot = resp
		if callback.is_valid():
			callback.call(success)
	)


## 场景状态就绪时执行（WorldWeapon 用于延迟检查是否已拾取）
func call_when_scene_state_ready(cb: Callable) -> void:
	_scene_state_ready_callbacks.append(cb)
	# 若已有 scene_state（快照或已加载），立即执行
	if not _scene_state_snapshot.is_empty() or not _collected_pickables.is_empty():
		_run_scene_state_ready_callbacks()


func _run_scene_state_ready_callbacks() -> void:
	if _scene_state_ready_callbacks.is_empty():
		return
	for cb in _scene_state_ready_callbacks:
		if cb.is_valid():
			cb.call()
	_scene_state_ready_callbacks.clear()


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


func _on_local_checkpoint_timer() -> void:
	if UserManager.current_character_id.is_empty():
		return
	if get_player() == null:
		return
	_take_snapshot()
	_write_local_checkpoint_from_memory()


## 场景切换前调用：快照当前状态到内存，并立即写入本地快存
func snapshot_before_scene_change() -> void:
	# 退出/预删除阶段可能已不在 SceneTree 中；此时调用 get_tree() 会触发引擎错误，直接跳过快照。
	if not is_inside_tree():
		return
	_take_snapshot()
	_write_local_checkpoint_from_memory()


## 新场景 Player._ready 末尾调用：从快照或 API 恢复数据
func restore_to_player(player: Node) -> void:
	var cid := UserManager.current_character_id
	if cid.is_empty():
		push_warning("[CharacterDataManager] character_id 未设置，跳过恢复")
		return

	SkillManager.character = player
	GeneManager.setup(UserManager.current_character_class)

	if not _stats_snapshot.is_empty():
		var stats = player.get("player_stats")
		if stats and stats.has_method("load_from_dict"):
			var w_loadout: Variant = _stats_snapshot.get("loadout", {})
			stats.load_from_dict(_stats_snapshot)
			_schedule_weapon_loadout_apply(player, w_loadout)
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

	var genes_snap_empty := true
	if _genes_snapshot is Dictionary:
		genes_snap_empty = (_genes_snapshot as Dictionary).is_empty()
	elif _genes_snapshot is Array:
		genes_snap_empty = (_genes_snapshot as Array).is_empty()
	if not genes_snap_empty:
		GeneManager.restore_from_snapshot(_genes_snapshot)
	else:
		_restore_genes_from_api()

	if not _scene_state_snapshot.is_empty():
		_apply_scene_state_to_player(player)
	else:
		_restore_scene_state_from_api(player)


func _apply_scene_state_to_player(player: Node) -> void:
	if _scene_state_snapshot.is_empty():
		return
	var pos_arr = _scene_state_snapshot.get("position", [])
	if pos_arr is Array and pos_arr.size() >= 3:
		player.global_position = Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))
	var rot_y = _scene_state_snapshot.get("rotation_y", null)
	if rot_y != null:
		player.rotation.y = float(rot_y)
	# 同步已拾取物列表，供 WorldWeapon 检查
	var collected: Array = _scene_state_snapshot.get("collected_pickables", [])
	_collected_pickables.clear()
	for s in collected:
		_collected_pickables.append(str(s))
	_run_scene_state_ready_callbacks()


func _load_player_data_from_api() -> void:
	var cid := UserManager.current_character_id
	if cid.is_empty():
		return

	var loaded := [0]
	var required := 5
	var _on_loaded := func():
		loaded[0] += 1
		if loaded[0] >= required:
			_persist_local_after_cloud_pull(cid)
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
			_genes_snapshot = resp
			GeneManager.restore_from_snapshot(resp)
			print("角色基因已从服务器加载")
		_on_loaded.call()
	)

	ApiManager.load_scene_state(cid, func(success, resp):
		if success and resp is Dictionary:
			_scene_state_snapshot = resp
			_collected_pickables.clear()
			for s in resp.get("collected_pickables", []):
				_collected_pickables.append(str(s))
			var p := get_player()
			if p:
				_apply_scene_state_to_player(p)
			else:
				_run_scene_state_ready_callbacks()
			print("场景状态已从服务器加载")
		_on_loaded.call()
	)


func _apply_stats_to_player(stats_dict: Dictionary) -> void:
	var player := get_player()
	if not player:
		return
	var stats = player.get("player_stats")
	if stats and stats.has_method("load_from_dict"):
		var w_loadout: Variant = stats_dict.get("loadout", {})
		stats.load_from_dict(stats_dict)
		_schedule_weapon_loadout_apply(player, w_loadout)


func _restore_stats_from_api(player: Node) -> void:
	var cid := UserManager.current_character_id
	ApiManager.load_stats(cid, func(success, resp):
		if success and resp is Dictionary:
			_stats_snapshot = resp
			var stats = player.get("player_stats")
			if stats and stats.has_method("load_from_dict"):
				var w_loadout: Variant = resp.get("loadout", {})
				stats.load_from_dict(resp)
				_schedule_weapon_loadout_apply(player, w_loadout)
	)


func _restore_inventory_from_api() -> void:
	var cid := UserManager.current_character_id
	ApiManager.load_inventory(cid, func(success, resp):
		if success and resp.has("slots"):
			_inventory_snapshot = resp["slots"]
			InventoryManager.load_serializable_inventory(resp["slots"])
	)


## 子基因等操作在服务端消耗材料后，拉取背包与快照对齐
func refresh_inventory_from_api(callback: Callable = Callable()) -> void:
	var cid := UserManager.current_character_id
	if cid.is_empty():
		if callback.is_valid():
			callback.call()
		return
	ApiManager.load_inventory(cid, func(success, resp):
		if success and resp.has("slots"):
			_inventory_snapshot = resp["slots"]
			InventoryManager.load_serializable_inventory(resp["slots"])
		if callback.is_valid():
			callback.call()
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
			_genes_snapshot = resp
			GeneManager.restore_from_snapshot(resp)
	)


func _restore_scene_state_from_api(player: Node) -> void:
	var cid := UserManager.current_character_id
	ApiManager.load_scene_state(cid, func(success, resp):
		if success and resp is Dictionary:
			_scene_state_snapshot = resp
			_collected_pickables.clear()
			for s in resp.get("collected_pickables", []):
				_collected_pickables.append(str(s))
			_apply_scene_state_to_player(player)
	)


func _take_snapshot() -> void:
	var player := get_player()
	if player:
		var stats = player.get("player_stats")
		if stats and stats.has_method("save_to_dict"):
			_stats_snapshot = stats.save_to_dict()
			var wm = player.get("weapon_manager")
			if wm and wm.has_method("get_serializable_loadout"):
				_stats_snapshot["loadout"] = wm.get_serializable_loadout()
			else:
				# 无武器管理器时仍写入空 loadout，确保后端会覆盖旧数据
				_stats_snapshot["loadout"] = {"version": 1, "current_slot": 0, "slots": {}}
		else:
			_stats_snapshot = {}
		## 场景状态：当前场景路径、玩家位置与朝向、已拾取物
		# 注意：在退出/预删除阶段 SceneTree 可能为 null，此处需兜底。
		var scene_root = get_tree().current_scene if is_inside_tree() and get_tree() else null
		_scene_state_snapshot = {
			"scene_path": scene_root.scene_file_path if scene_root and scene_root.scene_file_path else "",
			"position": [player.global_position.x, player.global_position.y, player.global_position.z],
			"rotation_y": player.rotation.y,
			"collected_pickables": _collected_pickables.duplicate()
		}
	else:
		# 无玩家时保留已有 scene_state，仅更新 collected_pickables
		if _scene_state_snapshot.is_empty():
			_scene_state_snapshot = {"collected_pickables": _collected_pickables.duplicate()}
		else:
			_scene_state_snapshot["collected_pickables"] = _collected_pickables.duplicate()
	_inventory_snapshot = InventoryManager.get_serializable_inventory()
	_skills_snapshot = SkillManager.save_skills_data()
	_genes_snapshot = {
		"genes": GeneManager.get_serializable_state(),
		"gene_modules": GeneManager.get_serializable_module_state(),
	}


func get_player() -> Node:
	# 在退出/预删除阶段可能不在 SceneTree 中；避免调用 get_tree() 触发引擎错误。
	if not is_inside_tree():
		return null
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(PLAYER_GROUP)


## 仅本地加密快存（不切 API）：拾取、切场景前、定时器、可绑战斗节点
func save_local_checkpoint_now() -> void:
	_take_snapshot()
	_write_local_checkpoint_from_memory()


func has_pending_cloud_sync() -> bool:
	var cid := UserManager.current_character_id
	if cid.is_empty():
		return false
	return LocalCharacterSave.has_pending_cloud_sync(cid)


func _write_local_checkpoint_from_memory() -> void:
	var cid := UserManager.current_character_id
	if cid.is_empty():
		return
	LocalCharacterSave.write_play_session_checkpoint(
		cid,
		_stats_snapshot,
		_inventory_snapshot,
		_skills_snapshot,
		_genes_snapshot,
		_scene_state_snapshot,
		_collected_pickables.duplicate(),
		_gather_client_blob()
	)


func _persist_local_after_cloud_pull(character_id: String) -> void:
	if character_id.is_empty():
		return
	LocalCharacterSave.write_cloud_authoritative(
		character_id,
		_stats_snapshot,
		_inventory_snapshot,
		_skills_snapshot,
		_genes_snapshot,
		_scene_state_snapshot,
		_collected_pickables.duplicate(),
		_gather_client_blob()
	)


## 不进云端 API 的客户端扩展：教程 UI 状态、当前场景等（见 LocalCharacterSave.client_blob）
func _gather_client_blob() -> Dictionary:
	var b: Dictionary = {}
	if is_instance_valid(TutorialManager):
		b["tutorial_in_progress"] = TutorialManager.is_in_tutorial()
		b["tutorial_step"] = int(TutorialManager.get_current_step())
		b["tutorial_awaiting_intro_ack"] = TutorialManager.is_awaiting_intro_welcome_ack()
	var tr := get_tree().current_scene if get_tree() else null
	if tr != null and tr.scene_file_path:
		b["current_scene_path"] = tr.scene_file_path
	return b


## 保存到 API，force=true 忽略冷却（登出等）
func save_to_api(callback: Callable = Callable(), force: bool = false) -> void:
	var cid := UserManager.current_character_id
	if cid.is_empty():
		if callback.is_valid():
			callback.call(false, {"message": "无角色 ID，跳过云端存档", "errors": ["missing_character_id"]})
		return

	var now := Time.get_ticks_msec() / 1000.0
	if not force and (now - _last_api_save_time) < API_SAVE_COOLDOWN:
		if callback.is_valid():
			callback.call(true, null)
		return

	_take_snapshot()
	_write_local_checkpoint_from_memory()
	_last_api_save_time = now

	# stats 与 scene_state 合并为一次请求，避免并行导致 loadout 被覆盖
	# 先计算总请求数，避免 H3/H4 计数错误（has_stats 时 4 个，否则 3 个）
	var has_stats := not _stats_snapshot.is_empty() or not _scene_state_snapshot.is_empty()
	var total_requests := 4 if has_stats else 3
	# 使用 Array 包装确保闭包内正确修改（H1：GDScript 原始类型按值捕获，Array 按引用）
	var pending := [total_requests]
	var any_failed := [false]
	var callback_invoked := [false]  # H2：防止回调被多次调用（正常完成 + 超时 或 多次 _check_done）
	var errors: Array = []

	var _check_done := func():
		pending[0] -= 1
		if pending[0] <= 0 and not callback_invoked[0]:
			callback_invoked[0] = true
			if not any_failed[0]:
				LocalCharacterSave.mark_full_api_synced(cid)
			character_data_save_completed.emit()
			if callback.is_valid():
				var payload: Variant = null
				if any_failed[0]:
					payload = {"errors": errors.duplicate(), "message": "云端存档失败"}
				callback.call(not any_failed[0], payload)

	ApiManager.save_inventory(cid, _inventory_snapshot, func(success, _resp):
		if not success:
			any_failed[0] = true
			data_error.emit("背包保存失败")
			errors.append({"kind": "inventory", "message": (_resp.get("message", "") if _resp is Dictionary else str(_resp))})
		_check_done.call()
	)

	ApiManager.save_skills(cid, _skills_snapshot, func(success, _resp):
		if not success:
			any_failed[0] = true
			data_error.emit("技能保存失败")
			errors.append({"kind": "skills", "message": (_resp.get("message", "") if _resp is Dictionary else str(_resp))})
		_check_done.call()
	)

	ApiManager.save_genes(cid, _genes_snapshot, func(success, _resp):
		if not success:
			any_failed[0] = true
			data_error.emit("基因保存失败")
			errors.append({"kind": "genes", "message": (_resp.get("message", "") if _resp is Dictionary else str(_resp))})
		_check_done.call()
	)

	if has_stats:
		var stats_payload := _stats_snapshot.duplicate()
		if not _scene_state_snapshot.is_empty():
			stats_payload["scene_state"] = _scene_state_snapshot
		var fallback := {"max_health": 100, "current_health": 100, "attack": 10, "defense": 5, "critical_rate": 0.05, "critical_damage": 1.5, "evasion": 0.05, "gene_points": GeneManager.gene_points, "experience": 0.0, "sync_breakthroughs_completed": [], "fire_resistance": 0.0, "poison_resistance": 0.0, "thorns_resistance": 0.0, "other_resistance": 0.0, "tutorial_completed": false}
		for k in fallback:
			if not stats_payload.has(k):
				stats_payload[k] = fallback[k]
		ApiManager.save_stats(cid, stats_payload, func(success, _resp):
			if not success:
				any_failed[0] = true
				data_error.emit("属性保存失败")
				errors.append({"kind": "stats", "message": (_resp.get("message", "") if _resp is Dictionary else str(_resp))})
			_check_done.call()
		)

	# H5：create_timer(30.0, true) 的 process_always=true 确保暂停时 Timer 仍触发
	if callback.is_valid():
		var cb := callback
		var t := get_tree().create_timer(30.0, true)
		t.timeout.connect(func():
			if pending[0] > 0 and not callback_invoked[0]:
				callback_invoked[0] = true
				pending[0] = 0
				character_data_save_completed.emit()
				data_error.emit("云端存档超时，请检查网络、API_BASE_URL 或后端是否运行")
				cb.call(false, {"errors": errors.duplicate(), "message": "云端存档超时"})
		, CONNECT_ONE_SHOT)
