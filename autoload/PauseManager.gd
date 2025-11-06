#extends Node
#
### 全局场景暂停管理器
#
### 暂停状态枚举
#enum PauseState {
	#NONE,           # 正常游戏状态
	#PAUSED,         # 暂停菜单
	#INVENTORY,      # 背包界面
	#DIALOGUE,       # 对话场景
	#CUTSCENE        # 过场动画
#}
#
### 当前暂停状态
#var current_state: PauseState = PauseState.NONE
#
### 暂停场景
#var pause_menu_scene: PackedScene = preload("res://Scene/menu/pausa.tscn")
#var pause_menu_instance: Node = null
#
### 对话组名称
#const DIALOGUE_GROUP = "dialogue"
#
### 信号
#signal state_changed(new_state: PauseState)
#signal game_paused
#signal game_resumed
#
#
#func _ready() -> void:
	## 确保暂停时也能处理输入
	#process_mode = Node.PROCESS_MODE_ALWAYS  
	#
	## 连接场景树变化信号
	#get_tree().node_added.connect(_on_node_added)
	#get_tree().node_removed.connect(_on_node_removed)
#
#
#func _input(event: InputEvent) -> void:
	## ESC键
	#if event.is_action_pressed("ui_cancel"):  
		#handle_escape_press()
		#get_viewport().set_input_as_handled()
#
#
### 处理ESC键按下
#func handle_escape_press() -> void:
	#match current_state:
		#PauseState.NONE:
			## 正常游戏状态，打开暂停菜单
			#open_pause_menu()
			#
		#PauseState.INVENTORY:
			## 在背包中，退出背包
			#close_inventory()
			#
		#PauseState.PAUSED:
			## 已经在暂停菜单，关闭暂停菜单
			#close_pause_menu()
			#
		#PauseState.DIALOGUE, PauseState.CUTSCENE:
			## 对话和过场动画中不响应 ESC
			#pass
#
#
### 打开暂停菜单
#func open_pause_menu() -> void:
	#if current_state != PauseState.NONE:
		#return
	#
	#set_pause_state(PauseState.PAUSED)
	#get_tree().paused = true
	#
	## 实例化暂停菜单
	#if pause_menu_scene:
		#pause_menu_instance = pause_menu_scene.instantiate()
		#pause_menu_instance.process_mode = Node.PROCESS_MODE_ALWAYS
		#get_tree().root.add_child(pause_menu_instance)
		#
		## 连接暂停菜单的关闭信号（如果有）
		#if pause_menu_instance.has_signal("menu_closed"):
			#pause_menu_instance.menu_closed.connect(close_pause_menu)
	#
	## 显示鼠标并解锁
	#Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	#
	#emit_signal("game_paused")
#
#
### 关闭暂停菜单
#func close_pause_menu() -> void:
	#if current_state != PauseState.PAUSED:
		#return
	#
	## 移除暂停菜单实例
	#if pause_menu_instance:
		#pause_menu_instance.queue_free()
		#pause_menu_instance = null
	#
	#get_tree().paused = false
	#set_pause_state(PauseState.NONE)
	#
	## 隐藏鼠标并锁定（适用于第一人称/第三人称游戏）
	#Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	#
	#emit_signal("game_resumed")
#
#
### 打开背包
#func open_inventory() -> void:
	#if current_state != PauseState.NONE:
		#return
	#
	#set_pause_state(PauseState.INVENTORY)
	#get_tree().paused = true
	#
	## 显示鼠标
	#Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	#
	#emit_signal("game_paused")
#
#
### 关闭背包
#func close_inventory() -> void:
	#if current_state != PauseState.INVENTORY:
		#return
	#
	#get_tree().paused = false
	#set_pause_state(PauseState.NONE)
	#
	## 锁定鼠标
	#Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	#
	#emit_signal("game_resumed")
#
#
### 进入对话场景
#func enter_dialogue() -> void:
	#if current_state == PauseState.DIALOGUE:
		#return
	#
	#set_pause_state(PauseState.DIALOGUE)
	#get_tree().paused = true
	#
	## 显示鼠标
	#Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	#
	#emit_signal("game_paused")
#
#
### 退出对话场景
#func exit_dialogue() -> void:
	#if current_state != PauseState.DIALOGUE:
		#return
	#
	#get_tree().paused = false
	#set_pause_state(PauseState.NONE)
	#
	## 锁定鼠标
	#Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	#
	#emit_signal("game_resumed")
#
#
### 进入过场动画
#func enter_cutscene() -> void:
	#if current_state == PauseState.CUTSCENE:
		#return
	#
	#set_pause_state(PauseState.CUTSCENE)
	#get_tree().paused = true
	#
	## 显示鼠标
	#Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	#
	#emit_signal("game_paused")
#
#
### 退出过场动画
#func exit_cutscene() -> void:
	#if current_state != PauseState.CUTSCENE:
		#return
	#
	#get_tree().paused = false
	#set_pause_state(PauseState.NONE)
	#
	## 锁定鼠标
	#Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	#
	#emit_signal("game_resumed")
#
#
### 设置暂停状态
#func set_pause_state(new_state: PauseState) -> void:
	#if current_state != new_state:
		#current_state = new_state
		#emit_signal("state_changed", new_state)
#
#
### 获取当前状态
#func get_current_state() -> PauseState:
	#return current_state
#
#
### 检查是否处于暂停状态
#func is_paused() -> bool:
	#return current_state != PauseState.NONE
#
#
### 节点添加到场景树时的回调
#func _on_node_added(node: Node) -> void:
	## 自动检测对话组场景
	#if node.is_in_group(DIALOGUE_GROUP):
		#enter_dialogue()
#
#
### 节点从场景树移除时的回调
#func _on_node_removed(node: Node) -> void:
	## 自动退出对话状态
	#if node.is_in_group(DIALOGUE_GROUP) and current_state == PauseState.DIALOGUE:
		#exit_dialogue()
		
extends Node

## 全局暂停管理器

## 暂停状态枚举
enum PauseState {
	NONE,           # 正常游戏状态
	PAUSED,         # 暂停菜单
	INVENTORY,      # 背包界面
	DIALOGUE,       # 对话场景
	CUTSCENE        # 过场动画
}

## 当前暂停状态堆栈
var _state_stack: Array[PauseState] = []

## 暂停菜单
var pause_menu_scene: PackedScene = preload("res://Scene/menu/pausa.tscn")
var pause_menu_instance: Node = null

## 对话组
const DIALOGUE_GROUP = "dialogue"

## 信号
signal state_changed(new_state: PauseState)
signal game_paused
signal game_resumed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)


## 输入处理
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_handle_escape_press()
		get_viewport().set_input_as_handled()


func _handle_escape_press() -> void:
	match get_current_state():
		PauseState.NONE:
			open_pause_menu()
		PauseState.INVENTORY:
			close_inventory()
		PauseState.PAUSED:
			close_pause_menu()
		_: # 对话或过场中不处理
			pass

## 状态堆栈管理
func push_state(state: PauseState) -> void:
	if state not in _state_stack:
		_state_stack.append(state)
		_update_state()


func pop_state(state: PauseState) -> void:
	if state in _state_stack:
		_state_stack.erase(state)
		_update_state()


func _update_state() -> void:
	if _state_stack.is_empty():
		_set_pause_state(PauseState.NONE)
		get_tree().paused = false
		_set_mouse_visible(false)
		emit_signal("game_resumed")
	else:
		get_tree().paused = true
		_set_pause_state(_state_stack.back())
		_set_mouse_visible(true)
		emit_signal("game_paused")


func _set_pause_state(new_state: PauseState) -> void:
	var old_state := get_current_state()
	if old_state != new_state:
		emit_signal("state_changed", new_state)


func get_current_state() -> PauseState:
	return _state_stack.back() if not _state_stack.is_empty() else PauseState.NONE


func is_paused() -> bool:
	return not _state_stack.is_empty()


## 鼠标控制
func _set_mouse_visible(visible: bool) -> void:
	Input.mouse_mode = (
		Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED
	)


## 暂停菜单控制
func open_pause_menu() -> void:
	if pause_menu_instance and is_instance_valid(pause_menu_instance):
		return  # 已经存在

	push_state(PauseState.PAUSED)

	pause_menu_instance = pause_menu_scene.instantiate()
	pause_menu_instance.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(pause_menu_instance)

	if pause_menu_instance.has_signal("menu_closed"):
		pause_menu_instance.menu_closed.connect(close_pause_menu)


func close_pause_menu() -> void:
	if not pause_menu_instance:
		return

	if is_instance_valid(pause_menu_instance):
		pause_menu_instance.queue_free()
	pause_menu_instance = null

	pop_state(PauseState.PAUSED)

## 退出到主菜单
func exit_to_main_menu() -> void:
	# 移除暂停菜单
	if pause_menu_instance:
		pause_menu_instance.queue_free()
		pause_menu_instance = null
	
	# 恢复游戏状态
	get_tree().paused = false
	# 把停止的状态取出，不然会卡住
	pop_state(PauseState.PAUSED)
	
	# 显示鼠标
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# 切换到主菜单场景
	SceneManager.change_scene("main_menu")

## 背包控制
func open_inventory() -> void:
	push_state(PauseState.INVENTORY)

func close_inventory() -> void:
	pop_state(PauseState.INVENTORY)

## 对话控制
func enter_dialogue() -> void:
	push_state(PauseState.DIALOGUE)

func exit_dialogue() -> void:
	pop_state(PauseState.DIALOGUE)

## 过场动画控制
func enter_cutscene() -> void:
	push_state(PauseState.CUTSCENE)

func exit_cutscene() -> void:
	pop_state(PauseState.CUTSCENE)


## 自动检测对话节点
func _on_node_added(node: Node) -> void:
	if node.is_in_group(DIALOGUE_GROUP):
		enter_dialogue()

func _on_node_removed(node: Node) -> void:
	if node.is_in_group(DIALOGUE_GROUP):
		exit_dialogue()
