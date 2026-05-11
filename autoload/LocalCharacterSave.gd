extends Node

## 本地角色快存（加密文件 + 版本号）
##
## 与 SaveManager（仅设置）区分；与 CharacterDataManager 配合：
## - 游玩中：周期性 / 切场景前写入，**local_revision** 单调递增，**pending_cloud_sync = local_revision > cloud_ack_revision**
## - 云端拉取成功（登录后进游戏）：**write_cloud_authoritative** 覆盖本地并以云端为准重置版本基线
## - 全量 API 保存成功：**mark_full_api_synced** 将 cloud_ack_revision 对齐到当前文件中的 local_revision
##
## 冲突与回滚：当前以「登录云端覆盖本地」为主策略；详细见 docs/LOCAL_AND_CLOUD_SAVE.md

const SCHEMA_VERSION: int = 1
## client_blob 子字典版本（与根 schema 独立，便于迁移）
const CLIENT_BLOB_SCHEMA: int = 1
const SAVE_SUBDIR: String = "local_character_save"
## 与 SaveManager 分离的口令；修改会导致旧本地快存无法读取
const ENCRYPTION_PASS: String = "DesahumanLocalCH"

signal local_checkpoint_written(character_id: String, local_revision: int)
signal local_save_read_failed(character_id: String, reason: String)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_ensure_save_dir()


func _ensure_save_dir() -> void:
	var d := DirAccess.open("user://")
	if d == null:
		return
	if not d.dir_exists(SAVE_SUBDIR):
		d.make_dir_recursive(SAVE_SUBDIR)


func _path_for(character_id: String) -> String:
	if character_id.is_empty():
		return ""
	var safe := character_id
	for ch in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		safe = safe.replace(ch, "_")
	return "user://%s/%s.lcs" % [SAVE_SUBDIR, safe]


func read_save_dict(character_id: String) -> Dictionary:
	var path := _path_for(character_id)
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open_encrypted_with_pass(path, FileAccess.READ, ENCRYPTION_PASS)
	if f == null:
		local_save_read_failed.emit(character_id, "open_read err=%s" % FileAccess.get_open_error())
		return {}
	var raw := f.get_as_text()
	f.close()
	if raw.strip_edges().is_empty():
		return {}
	var j := JSON.new()
	if j.parse(raw) != OK:
		local_save_read_failed.emit(character_id, "json_parse")
		return {}
	var data: Variant = j.data
	if not data is Dictionary:
		return {}
	return _migrate_save_dict(data as Dictionary)


## 读取后迁移：补全缺失根字段，使旧/手改文件仍可与版本号逻辑协同
func _migrate_save_dict(data: Dictionary) -> Dictionary:
	var ver := int(data.get("schema_version", 0))
	if ver < SCHEMA_VERSION:
		if not data.has("local_revision"):
			data["local_revision"] = 1
		if not data.has("cloud_ack_revision"):
			data["cloud_ack_revision"] = int(data["local_revision"])
		if not data.has("pending_cloud_sync"):
			data["pending_cloud_sync"] = int(data["local_revision"]) > int(data["cloud_ack_revision"])
		data["schema_version"] = SCHEMA_VERSION
	var cb: Variant = data.get("client_blob", {})
	data["client_blob"] = cb if cb is Dictionary else {}
	return data


func _write_file(character_id: String, data: Dictionary) -> bool:
	_ensure_save_dir()
	var path := _path_for(character_id)
	if path.is_empty():
		return false
	data["schema_version"] = SCHEMA_VERSION
	data["character_id"] = character_id
	data["saved_at_unix"] = int(Time.get_unix_time_from_system())
	var f := FileAccess.open_encrypted_with_pass(path, FileAccess.WRITE, ENCRYPTION_PASS)
	if f == null:
		push_error("[LocalCharacterSave] 无法写入 %s err=%s" % [path, FileAccess.get_open_error()])
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	return true


## 登录后从云端拉取并应用到内存快照之后调用：以云端为权威覆盖本地文件
func write_cloud_authoritative(
	character_id: String,
	stats_snapshot: Dictionary,
	inventory_snapshot: Variant,
	skills_snapshot: Variant,
	genes_snapshot: Variant,
	scene_state_snapshot: Dictionary,
	collected_pickables: Array,
	client_blob: Dictionary = {}
) -> void:
	if character_id.is_empty():
		return
	var d := _pack_payload(
		stats_snapshot,
		inventory_snapshot,
		skills_snapshot,
		genes_snapshot,
		scene_state_snapshot,
		collected_pickables,
		client_blob
	)
	d["local_revision"] = 1
	d["cloud_ack_revision"] = 1
	d["pending_cloud_sync"] = false
	if _write_file(character_id, d):
		local_checkpoint_written.emit(character_id, 1)


## 游玩中快存：在内存快照已更新后调用（local_revision++，pending 视与 cloud_ack 差）
func write_play_session_checkpoint(
	character_id: String,
	stats_snapshot: Dictionary,
	inventory_snapshot: Variant,
	skills_snapshot: Variant,
	genes_snapshot: Variant,
	scene_state_snapshot: Dictionary,
	collected_pickables: Array,
	client_blob: Dictionary = {}
) -> void:
	if character_id.is_empty():
		return
	var prev := read_save_dict(character_id)
	var next_rev := int(prev.get("local_revision", 0)) + 1
	var cloud_ack := int(prev.get("cloud_ack_revision", 0))
	if prev.is_empty():
		cloud_ack = 0
		next_rev = maxi(next_rev, 1)
	var d := _pack_payload(
		stats_snapshot,
		inventory_snapshot,
		skills_snapshot,
		genes_snapshot,
		scene_state_snapshot,
		collected_pickables,
		client_blob
	)
	d["local_revision"] = next_rev
	d["cloud_ack_revision"] = cloud_ack
	d["pending_cloud_sync"] = next_rev > cloud_ack
	if _write_file(character_id, d):
		local_checkpoint_written.emit(character_id, next_rev)


## 全量 API 保存（背包/技能/基因/stats）全部成功后调用
func mark_full_api_synced(character_id: String) -> void:
	if character_id.is_empty():
		return
	var prev := read_save_dict(character_id)
	if prev.is_empty():
		return
	var lr := int(prev.get("local_revision", 0))
	prev["cloud_ack_revision"] = lr
	prev["pending_cloud_sync"] = false
	_write_file(character_id, prev)


func has_pending_cloud_sync(character_id: String) -> bool:
	var d := read_save_dict(character_id)
	if d.is_empty():
		return false
	return bool(d.get("pending_cloud_sync", false))


func get_local_revision(character_id: String) -> int:
	return int(read_save_dict(character_id).get("local_revision", 0))


## 与云端无关的客户端扩展字段（教程步骤、当前场景路径等）
func read_client_blob(character_id: String) -> Dictionary:
	var d := read_save_dict(character_id)
	var b: Variant = d.get("client_blob", {})
	return b if b is Dictionary else {}


func _pack_payload(
	stats_snapshot: Dictionary,
	inventory_snapshot: Variant,
	skills_snapshot: Variant,
	genes_snapshot: Variant,
	scene_state_snapshot: Dictionary,
	collected_pickables: Array,
	client_blob: Dictionary
) -> Dictionary:
	var inv_dup: Variant = inventory_snapshot
	if inventory_snapshot is Array:
		inv_dup = (inventory_snapshot as Array).duplicate(true)
	var genes_dup: Variant = genes_snapshot
	if genes_snapshot is Dictionary:
		genes_dup = (genes_snapshot as Dictionary).duplicate(true)
	elif genes_snapshot is Array:
		genes_dup = (genes_snapshot as Array).duplicate(true)
	var skills_dup: Variant = skills_snapshot
	if skills_snapshot is Dictionary:
		skills_dup = (skills_snapshot as Dictionary).duplicate(true)
	var cb := client_blob.duplicate(true) if not client_blob.is_empty() else {}
	cb["client_blob_schema"] = CLIENT_BLOB_SCHEMA
	return {
		"stats_snapshot": stats_snapshot.duplicate(true),
		"inventory_snapshot": inv_dup,
		"skills_snapshot": skills_dup,
		"genes_snapshot": genes_dup,
		"scene_state_snapshot": scene_state_snapshot.duplicate(true),
		"collected_pickables": collected_pickables.duplicate(),
		"client_blob": cb,
	}
