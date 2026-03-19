extends Node

## SaveManager — 设置存档（仅设置，不含游戏存档）
##
## 职责：监听 SettingSignal，将设置字典加密写入 user://SettingsData
## 注意：游戏存档（背包/技能/属性）由 CharacterDataManager 负责，通过 API 云端保存
## 详见 docs/CharacterDataManager.md

const SETTINGS_SAVE_PATH : String = "user://SettingsData"
var settings_data_dict : Dictionary = {}

func _ready():
	SettingSignal.set_setting_dictionary.connect(on_settings_save)
	load_settings_data()
	
func on_settings_save(data : Dictionary):
	# 最后一段密码
	# 安全保存游戏设置
	var save_setting_data_file = FileAccess.open_encrypted_with_pass(SETTINGS_SAVE_PATH, FileAccess.WRITE, "Desahuman")
	
	var json_data = JSON.stringify(data)
	
	save_setting_data_file.store_line(json_data)

func load_settings_data():
	if not FileAccess.file_exists(SETTINGS_SAVE_PATH):
		return
	
	var save_settings_data_file = FileAccess.open_encrypted_with_pass(SETTINGS_SAVE_PATH, FileAccess.READ, "Desahuman")
	var loaded_data : Dictionary = {}
	
	while save_settings_data_file.get_position() < save_settings_data_file.get_length():
		var json_string = save_settings_data_file.get_line()
		var json = JSON.new()
		# _ 代表私有化
		var _parsed_result = json.parse(json_string)
		
		loaded_data = json.get_data()
		
	SettingSignal.emit_load_setting_data(loaded_data)
	loaded_data = {}
