extends Node

## 全局暂停管理器

## 暂停状态枚举
enum PauseState {
	NONE,           # 正常游戏状态
	PAUSED,         # 暂停菜单
	INVENTORY,      # 背包界面
	DIALOGUE,       # 对话场景
	CUTSCENE,       # 过场动画
	CHARACTERINFO,  # 角色信息菜单
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
	
	UiManager.ui_closed.connect(_close_ui_from_ui_manager)


## 输入处理
func _input(event: InputEvent) -> void:
	if TutorialManager and TutorialManager.is_awaiting_intro_welcome_ack():
		return
	if event.is_action_pressed("ui_cancel"):
		_handle_escape_press()
		get_viewport().set_input_as_handled()


func _handle_escape_press() -> void:
	match get_current_state():
		PauseState.NONE:
			open_pause_menu()
		PauseState.PAUSED:
			# 暂停菜单上叠了设置等子界面时，先逐层关闭，再关暂停
			if pause_menu_instance and is_instance_valid(pause_menu_instance):
				if pause_menu_instance.has_method(&"try_close_top_overlay"):
					if pause_menu_instance.try_close_top_overlay():
						return
			close_pause_menu()
		_:
			pass


func _close_ui_from_ui_manager(ui: String) -> void:
	print_debug("[PauseManager] UIManager 关闭: ", ui)
	match ui:
		"InventoryUI":
			close_inventory()
		"CharacterInfoUI":
			close_characterInfo()
		_:
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
	# 每次状态变更都通知订阅者（用于隐藏 HUD 等）
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
	CharacterDataManager.save_to_api()


## 退出到主菜单（先完整保存再切场景）
func exit_to_main_menu() -> void:
	if UserManager.current_character_id.is_empty():
		_do_exit_to_main_menu()
		return
	CharacterDataManager.save_to_api(func(_success, _resp):
		_do_exit_to_main_menu()
	, true)


func _do_exit_to_main_menu() -> void:
	if pause_menu_instance:
		pause_menu_instance.queue_free()
		pause_menu_instance = null
	get_tree().paused = false
	pop_state(PauseState.PAUSED)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
		
		
## 角色信息界面控制
func open_characterInfo() -> void:
	push_state(PauseState.CHARACTERINFO)
	
func close_characterInfo() -> void:
	pop_state(PauseState.CHARACTERINFO)
