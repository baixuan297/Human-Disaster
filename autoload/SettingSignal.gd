extends Node

## SettingSignal — 设置相关的全局信号与 emit 封装
## UI 与 SaveManager 之间的桥梁：`set_setting_dictionary` 触发存档，`load_setting_data` 分发读盘结果。

signal on_subtitles_toggled(value: bool)

signal on_window_mode_selected(index : int)
signal on_resolution_mode_selected(index : int)

signal on_master_sound_set(value : float)
signal on_music_sound_set(value : float)
signal on_sfx_sound_set(value : float)

signal set_setting_dictionary(setting_dict : Dictionary)

signal load_setting_data(setting_dict : Dictionary)


func emit_load_setting_data(setting_dict : Dictionary):
	load_setting_data.emit(setting_dict)

func emit_set_setting_dictionary(setting_dict : Dictionary):
	set_setting_dictionary.emit(setting_dict)

func emit_on_subtitles_toggled(value : bool):
	on_subtitles_toggled.emit(value)
	
func emit_on_window_mode_selected(index : int):
	on_window_mode_selected.emit(index)

func emit_on_resolution_mode_selected(index : int):
	on_resolution_mode_selected.emit(index)

func emit_on_master_sound_set(value : float):
	on_master_sound_set.emit(value)
	
func emit_on_music_sound_set(value : float):
	on_music_sound_set.emit(value)

func emit_on_sfx_sound_set(value : float):
	on_sfx_sound_set.emit(value)
