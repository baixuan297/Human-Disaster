extends Node

## 场景管理器 - 用来管理和实例化场景
## 两个井号代表着文档注释，而一个井号仅仅就是注释
## Loader

## 信号
signal scene_changed(scene_name: String)
signal loading_progress(progress: float)

## 预加载过渡场景
var loading_screen = preload("res://Scene/menu/loading.tscn")
var loading_screen_instance: Node = null

## 当前场景
var current_scene: Node = null
## 要加载的场景路径
var load_scene: String = ""
## 场景历史栈用于返回上一场景
var scene_history: Array[String] = []
## 最大历史记录数
const MAX_HISTORY: int = 10
## 场景路径字典
var scenes: Dictionary = {
	"main_menu": "res://Scene/menu/main_menu3d.tscn",
	"game": "res://Scene/map/world.tscn",
	"pause": "res://Scene/menu/pausa.tscn",
}
# 这两个的区别是，一个是保存可以快速加载的场景的预设
# 一个是用来加载场景中的UI，比如背包，地图，抽卡（如果有， 等。
## UI场景路径字典
const UI_PATHS = {
	"MapUI": "",
	"InventoryUI": "res://addons/xuanBag/scene/Inventory.tscn",
	"ShopUI": "",
	"SettingsUI": "",
}


## 加载状态
var is_loading: bool = false

func _ready() -> void:
	# 获取当前场景树中的根场景
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)
	
	# 确保这个节点在暂停时仍然可以处理输入
	process_mode = Node.PROCESS_MODE_ALWAYS

## 切换场景(使用过渡场景)
func change_scene(scene_name: String, save_history: bool = true) -> void:
	if is_loading:
		push_warning("场景正在加载中，请稍候")
		return
	
	if not scenes.has(scene_name):
		push_error("场景 '%s' 未在场景字典中注册" % scene_name)
		return
	
	var scene_path = scenes[scene_name]
	_change_scene_internal(scene_path, save_history)

## 直接通过路径切换场景
func change_scene_to_file(path: String, save_history: bool = true) -> void:
	if is_loading:
		push_warning("场景正在加载中，请稍候")
		return
	
	_change_scene_internal(path, save_history)

## 实例化场景
func instance_scene(scene_name: String, parent: Node = null) -> Node:
	if not scenes.has(scene_name):
		push_error("场景 '%s' 未注册" % scene_name)
		return null
		
	
	var scene_path = scenes[scene_name]
	var packed_scene = load(scene_path)
	var instance = packed_scene.instantiate()
	
	# 如果指定了父节点，添加到父节点下
	if parent:
		parent.add_child(instance)
	
	return instance

## 返回上一个场景
func go_back() -> void:
	if scene_history.is_empty():
		push_warning("没有历史场景可以返回")
		return
	
	var prev_scene = scene_history.pop_back()
	change_scene(prev_scene, false)

## 重新加载当前场景
func reload_current_scene() -> void:
	if current_scene:
		var current_path = current_scene.scene_file_path
		change_scene_to_file(current_path, false)

## 在实例化加载场景后调用此方法开始实际加载
#func start_loading() -> void:
	#if load_scene.is_empty():
		#push_error("没有设置要加载的场景")
		#return
	#
	## 异步加载场景
	## 异步线程方式加载场景，（不会阻塞主线程，可以边加载边显示界面。）
	#ResourceLoader.load_threaded_request(load_scene)
	#
	## 等待加载完成
	#_wait_for_loading()

## 获取当前要加载的场景路径
func get_load_scene_path() -> String:
	return load_scene

## 场景加载完成后的回调
func on_scene_loaded(new_scene: Node) -> void:
	current_scene = new_scene
	is_loading = false
	
	# 获取场景名称
	var scene_name = ""
	for key in scenes:
		if scenes[key] == load_scene:
			scene_name = key
			break
	
	if scene_name.is_empty():
		scene_name = load_scene.get_file().get_basename()
	
	# 发送场景切换完成信号
	scene_changed.emit(scene_name)
	
	# 清空加载路径
	load_scene = ""

## 场景加载失败的回调
func on_scene_load_failed() -> void:
	push_error("场景加载失败: %s" % load_scene)
	is_loading = false
	load_scene = ""
	# 尝试返回上一个场景
	if not scene_history.is_empty():
		go_back()

## 添加场景到注册表
func register_scene(scene_name: String, scene_path: String) -> void:
	scenes[scene_name] = scene_path

## 获取当前场景名称
func get_current_scene_name() -> String:
	if not current_scene:
		return ""
	
	var current_path = current_scene.scene_file_path
	for key in scenes:
		if scenes[key] == current_path:
			return key
	return ""

## 清空历史记录
func clear_history() -> void:
	scene_history.clear()

## 获取场景路径(通过名称)
func get_scene_path(scene_name: String) -> String:
	if scenes.has(scene_name):
		return scenes[scene_name]
	return ""

## 通过获取内部场景来更换场景
func _change_scene_internal(path: String, save_history: bool) -> void:
	is_loading = true
	load_scene = path
	
	# 保存到历史栈
	if save_history and current_scene:
		var current_name = get_current_scene_name()
		if not current_name.is_empty():
			_add_to_history(current_name)
	# 切换到加载场景
	get_tree().change_scene_to_packed(loading_screen)

## 等待加载
func _wait_for_loading() -> void:
	var progress: Array = []

	while true:
		var status = ResourceLoader.load_threaded_get_status(load_scene, progress)
		
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			# 发送加载进度
			loading_progress.emit(progress[0])
			await get_tree().process_frame
			
		elif status == ResourceLoader.THREAD_LOAD_LOADED:
			loading_progress.emit(1.0)
			# 加载完成，切换场景
			var packed_scene = ResourceLoader.load_threaded_get(load_scene)
			await get_tree().create_timer(0.3).timeout  # 短暂延迟让进度条显示100%
			_switch_to_scene(packed_scene)
			break
			
		else:
			push_error("场景加载失败: %s" % load_scene)
			is_loading = false
			return

## 切换场景
func _switch_to_scene(packed_scene: PackedScene) -> void:
	# 实例化新场景
	current_scene = packed_scene.instantiate()
	
	# 切换场景
	get_tree().change_scene_to_packed(packed_scene)
	
	# 重置加载状态
	is_loading = false
	
	# 获取场景名称
	var scene_name = ""
	for key in scenes:
		if scenes[key] == load_scene:
			scene_name = key
			break
	
	if scene_name.is_empty():
		scene_name = load_scene.get_file().get_basename()
	
	# 发送场景切换完成信号
	scene_changed.emit(scene_name)
	
	# 清空加载路径
	load_scene = ""

## 添加到记录中
func _add_to_history(scene_name: String) -> void:
	# 避免连续重复的场景
	if not scene_history.is_empty() and scene_history.back() == scene_name:
		return
	
	scene_history.append(scene_name)
	
	# 限制历史记录数量
	if scene_history.size() > MAX_HISTORY:
		scene_history.pop_front()

## 工厂方法 方便在UIManager中进行调用
func create_ui(ui_name: String) -> Control:
	if not UI_PATHS.has(ui_name):
		return null
	
	var ui_path = UI_PATHS[ui_name]
	
	# 检查场景文件是否存在
	if not ResourceLoader.exists(ui_path):
		push_warning("UI path not found")
		return null
	
	# 加载并实例化场景
	var ui_scene = load(ui_path)
	if ui_scene:
		var ui_instance = ui_scene.instantiate()
		return ui_instance
	else:
		return null
