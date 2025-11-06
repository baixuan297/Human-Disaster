extends Node

# 设置数值默认值
@onready var DEFAULT_SETTING : DefaultSettingResource = preload("res://resource/settings/DefaultSetting.tres")
@onready var KEYBIND_RESOURCE : KeyBindResource = preload("res://resource/settings/KeyBindDefault.tres")

var window_mode_index = 0
var resolution_mode_index = 0
var master_volume : float = 0.0
var music_volume : float = 0.0
var sfx_volume : float = 0.0
var subtitle_set = false

var loaded_data : Dictionary = {}

func _ready():
	handled_signals()
	create_storage_dictionary()

func create_storage_dictionary() -> Dictionary:
	var settings_container_dict : Dictionary = {
		"window_mode_index" : window_mode_index,
		"resolution_mode_index" : resolution_mode_index,
		"master_volume" : master_volume,
		"music_volume" : music_volume,
		"sfx_volume" : sfx_volume,
		"subtitle_set" : subtitle_set,
		# Hot key 热键绑定
		"keybinds" : create_keybidns_dictionary()
	}
	
	return settings_container_dict
	
func create_keybidns_dictionary():
	var keybinds_container_dict = {
		KEYBIND_RESOURCE.MOVE_LEFT: KEYBIND_RESOURCE.move_left_key,
		KEYBIND_RESOURCE.MOVE_RIGHT: KEYBIND_RESOURCE.move_right_key,
		KEYBIND_RESOURCE.MOVE_FORWARD: KEYBIND_RESOURCE.move_forward_key,
		KEYBIND_RESOURCE.MOVE_BACKWARD: KEYBIND_RESOURCE.move_backward_key,
		KEYBIND_RESOURCE.RUN: KEYBIND_RESOURCE.run_key,
		KEYBIND_RESOURCE.CROUCH: KEYBIND_RESOURCE.crouch_key,
		KEYBIND_RESOURCE.JUMP: KEYBIND_RESOURCE.jump_key,
		KEYBIND_RESOURCE.FREELOOK: KEYBIND_RESOURCE.freelook_key,
		KEYBIND_RESOURCE.CHANGEPERSON: KEYBIND_RESOURCE.change_person_key,
		KEYBIND_RESOURCE.CHANGEWEAPON1: KEYBIND_RESOURCE.change_weapon1_key,
		KEYBIND_RESOURCE.CHANGEWEAPON2: KEYBIND_RESOURCE.change_weapon2_key,
	}
	return keybinds_container_dict

# 如果字典为空，那么返回默认索引。
func get_window_mode_index():
	if loaded_data == {}:
		return DEFAULT_SETTING.DEFAULT_WINDOW_MODE_INDEX
	return window_mode_index
	
func get_resolution_mode_index():
	if loaded_data == {}:
		return DEFAULT_SETTING.DEFAULT_RESOLCION_MODE_INDEX
	return resolution_mode_index
	
func get_subtitles_set():
	if loaded_data == {}:
		return DEFAULT_SETTING.DEFAULT_SUBTITLES_SET
	return subtitle_set
	
func get_master_volume():
	if loaded_data == {}:
		return DEFAULT_SETTING.DEFAULT_MASTER_VOLUM
	return master_volume
	
func get_music_volume():
	if loaded_data == {}:
		return DEFAULT_SETTING.DEFAULT_MUSIC_VOLUM
	return music_volume

func get_sfx_volume():
	if loaded_data == {}:
		return DEFAULT_SETTING.DEFAULT_SFX_VOLUM
	return sfx_volume
	
func get_keybind(action : String):
	if !loaded_data.has("keybinds"):
		match action:
			KEYBIND_RESOURCE.MOVE_LEFT:
				return KEYBIND_RESOURCE.DEFAULT_MOVE_LEFT_KEY
			KEYBIND_RESOURCE.MOVE_RIGHT:
				return KEYBIND_RESOURCE.DEFAULT_MOVE_RIGHT_KEY
			KEYBIND_RESOURCE.MOVE_FORWARD:
				return KEYBIND_RESOURCE.DEFAULT_MOVE_FORWARD_KEY
			KEYBIND_RESOURCE.MOVE_BACKWARD:
				return KEYBIND_RESOURCE.DEFAULT_MOVE_BACKWARD_KEY
			KEYBIND_RESOURCE.RUN:
				return KEYBIND_RESOURCE.DEFAULT_RUN_KEY
			KEYBIND_RESOURCE.CROUCH:
				return KEYBIND_RESOURCE.DEFAULT_CROUCH_KEY
			KEYBIND_RESOURCE.JUMP:
				return KEYBIND_RESOURCE.DEFAULT_JUMP_KEY
			KEYBIND_RESOURCE.FREELOOK:
				return KEYBIND_RESOURCE.DEFAULT_FREELOOK_KEY
			KEYBIND_RESOURCE.CHANGEPERSON:
				return KEYBIND_RESOURCE.DEFAULT_CHANGEPERSON_KEY
			KEYBIND_RESOURCE.CHANGEWEAPON1:
				return KEYBIND_RESOURCE.DEFAULT_CHANGEWEAPON1_KEY
			KEYBIND_RESOURCE.CHANGEWEAPON2:
				return KEYBIND_RESOURCE.DEFAULT_CHANGEWEAPON2_KEY
	else:
		match action:
			KEYBIND_RESOURCE.MOVE_LEFT:
				return KEYBIND_RESOURCE.move_left_key
			KEYBIND_RESOURCE.MOVE_RIGHT:
				return KEYBIND_RESOURCE.move_right_key
			KEYBIND_RESOURCE.MOVE_FORWARD:
				return KEYBIND_RESOURCE.move_forward_key
			KEYBIND_RESOURCE.MOVE_BACKWARD:
				return KEYBIND_RESOURCE.move_backward_key
			KEYBIND_RESOURCE.RUN:
				return KEYBIND_RESOURCE.run_key
			KEYBIND_RESOURCE.CROUCH:
				return KEYBIND_RESOURCE.crouch_key
			KEYBIND_RESOURCE.JUMP:
				return KEYBIND_RESOURCE.jump_key
			KEYBIND_RESOURCE.FREELOOK:
				return KEYBIND_RESOURCE.freelook_key
			KEYBIND_RESOURCE.CHANGEPERSON:
				return KEYBIND_RESOURCE.change_person_key
			KEYBIND_RESOURCE.CHANGEWEAPON1:
				return KEYBIND_RESOURCE.change_weapon1_key
			KEYBIND_RESOURCE.CHANGEWEAPON2:
				return KEYBIND_RESOURCE.change_weapon2_key


	
# 定义所有改变的数值
func on_window_mode_selected(index : int):
	window_mode_index = index
	
func on_resolution_mode_selected(index : int):
	resolution_mode_index = index
	
func on_subtitle_set(toggled : bool):
	subtitle_set = toggled

func on_master_set(value : float):
	master_volume = value

func on_music_set(value : float):
	music_volume = value

func on_sfx_set(value : float):
	sfx_volume = value

func set_keybind(action : String, event):
	match action:
		KEYBIND_RESOURCE.MOVE_LEFT:
			KEYBIND_RESOURCE.move_left_key = event
		KEYBIND_RESOURCE.MOVE_RIGHT:
			KEYBIND_RESOURCE.move_right_key = event
		KEYBIND_RESOURCE.MOVE_FORWARD:
			KEYBIND_RESOURCE.move_forward_key = event
		KEYBIND_RESOURCE.MOVE_BACKWARD:
			KEYBIND_RESOURCE.move_backward_key = event
		KEYBIND_RESOURCE.RUN:
			KEYBIND_RESOURCE.run_key = event
		KEYBIND_RESOURCE.CROUCH:
			KEYBIND_RESOURCE.crouch_key = event
		KEYBIND_RESOURCE.JUMP:
			KEYBIND_RESOURCE.jump_key = event
		KEYBIND_RESOURCE.FREELOOK:
			KEYBIND_RESOURCE.freelook_key = event
		KEYBIND_RESOURCE.CHANGEPERSON:
			KEYBIND_RESOURCE.change_person_key = event
		KEYBIND_RESOURCE.CHANGEWEAPON1:
			KEYBIND_RESOURCE.change_weapon1_key = event
		KEYBIND_RESOURCE.CHANGEWEAPON2:
			KEYBIND_RESOURCE.change_weapon2_key = event


# 加载游戏按键绑定数据，将按键信息转换为输入事件对象，并将这些事件对象赋给游戏中的全局变量和资源。
func on_keybind_loaded(data : Dictionary):
	var loaded_move_left = InputEventKey.new()
	var loaded_move_right = InputEventKey.new()
	var loaded_move_forward = InputEventKey.new()
	var loaded_move_backward = InputEventKey.new()
	var loaded_run = InputEventKey.new()
	var loaded_crouch = InputEventKey.new()
	var loaded_jump = InputEventKey.new()
	var loaded_freelook = InputEventKey.new()
	var loaded_change_person = InputEventKey.new()
	var loaded_change_weapon1 = InputEventKey.new()
	var loaded_change_weapon2 = InputEventKey.new()
	
	# 映射的是KEYbind的const
	loaded_move_left.set_physical_keycode(int(data.move_left))
	loaded_move_right.set_physical_keycode(int(data.move_right))
	loaded_move_forward.set_physical_keycode(int(data.move_forward))
	loaded_move_backward.set_physical_keycode(int(data.move_back))
	loaded_run.set_physical_keycode(int(data.Run))
	loaded_crouch.set_physical_keycode(int(data.crouch))
	loaded_jump.set_physical_keycode(int(data.jump))
	loaded_freelook.set_physical_keycode(int(data.free_look))
	loaded_change_person.set_physical_keycode(int(data.change_person))
	loaded_change_weapon1.set_physical_keycode(int(data.change_weapon1))
	loaded_change_weapon2.set_physical_keycode(int(data.change_weapon2))
	
	KEYBIND_RESOURCE.move_left_key = loaded_move_left
	KEYBIND_RESOURCE.move_right_key = loaded_move_right
	KEYBIND_RESOURCE.move_forward_key = loaded_move_forward
	KEYBIND_RESOURCE.move_backward_key = loaded_move_backward
	KEYBIND_RESOURCE.run_key = loaded_run
	KEYBIND_RESOURCE.crouch_key = loaded_crouch
	KEYBIND_RESOURCE.jump_key = loaded_jump
	KEYBIND_RESOURCE.freelook_key = loaded_freelook
	KEYBIND_RESOURCE.change_person_key = loaded_change_person
	KEYBIND_RESOURCE.change_weapon1_key = loaded_change_weapon1
	KEYBIND_RESOURCE.change_weapon2_key = loaded_change_weapon2

# 加载数据并且传递加载的数据
func on_setting_loaded(data : Dictionary):
	loaded_data = data
	on_window_mode_selected(loaded_data.window_mode_index)
	on_resolution_mode_selected(loaded_data.resolution_mode_index)
	on_subtitle_set(loaded_data.subtitle_set)
	on_master_set(loaded_data.master_volume)
	on_music_set((loaded_data.music_volume))
	on_sfx_set(loaded_data.sfx_volume)
	on_keybind_loaded(loaded_data.keybinds)
	
func handled_signals():
	SettingSignal.on_window_mode_selected.connect(on_window_mode_selected)
	SettingSignal.on_resolution_mode_selected.connect(on_resolution_mode_selected)
	SettingSignal.on_subtitles_toggled.connect(on_subtitle_set)
	SettingSignal.on_master_sound_set.connect(on_master_set)
	SettingSignal.on_music_sound_set.connect(on_music_set)
	SettingSignal.on_sfx_sound_set.connect(on_sfx_set)
	SettingSignal.load_setting_data.connect(on_setting_loaded)
