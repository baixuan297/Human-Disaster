extends Node

## SaveManager — 客户端「游戏设置」本地存档（加密单文件）
##
## 职责：监听 SettingSignal，将设置字典写入 `user://SettingsData`（加密）。
## 与 CharacterDataManager 区分：角色背包/技能/属性等走 API，见 CharacterDataManager.md。
##
## 错误处理：读写失败时 `push_error` / `push_warning`，不抛异常；避免覆盖损坏存档时静默失败。

const SETTINGS_SAVE_PATH: String = "user://SettingsData"
## 与 `open_encrypted_with_pass` 一致；修改会导致旧存档无法读取
const SETTINGS_ENCRYPTION_KEY: String = "Desahuman"

var settings_data_dict: Dictionary = {}


func _ready() -> void:
	SettingSignal.set_setting_dictionary.connect(on_settings_save)
	load_settings_data()


func on_settings_save(data: Dictionary) -> void:
	var f := FileAccess.open_encrypted_with_pass(SETTINGS_SAVE_PATH, FileAccess.WRITE, SETTINGS_ENCRYPTION_KEY)
	if f == null:
		push_error("SaveManager: 无法写入设置文件 err=%s" % FileAccess.get_open_error())
		return
	f.store_line(JSON.stringify(data))
	f.close()


func load_settings_data() -> void:
	if not FileAccess.file_exists(SETTINGS_SAVE_PATH):
		return

	var f := FileAccess.open_encrypted_with_pass(SETTINGS_SAVE_PATH, FileAccess.READ, SETTINGS_ENCRYPTION_KEY)
	if f == null:
		push_error("SaveManager: 无法读取设置文件 err=%s" % FileAccess.get_open_error())
		return

	var json_string := f.get_as_text()
	f.close()

	if json_string.strip_edges().is_empty():
		return

	var json := JSON.new()
	if json.parse(json_string) != OK:
		push_warning("SaveManager: 设置文件 JSON 解析失败，将使用默认设置")
		return

	var data: Variant = json.data
	if data is Dictionary:
		SettingSignal.emit_load_setting_data(data)
	else:
		push_warning("SaveManager: 设置文件根类型非 Dictionary，已忽略")
