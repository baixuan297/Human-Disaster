extends Node
#class_name UIManager

## UI管理器 - 栈式管理，同时只能打开一个UI

## 信号
signal ui_opened(ui_name: String)
signal ui_closed(ui_name: String)

## UI栈，只保存当前打开的UI
var ui_stack: Array = [] 
## 当前UI 
var current_ui: Control = null
## UI容器
var ui_container: CanvasLayer
## 用来保存输入的映射表
var action_to_ui = {
	# 按键映射 ： SceneManager中的UI名称映射
	"Inventory": "InventoryUI",
	"characterInfo": "CharacterInfoUI"
	#"map": "MapUI"
}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 创建UI容器
	ui_container = CanvasLayer.new()
	ui_container.name = "UIContainer"

	#add_child(ui_container)
	#get_tree().root.add_child(ui_container)

		
func _input(event: InputEvent) -> void:
	if TutorialManager and TutorialManager.is_awaiting_intro_welcome_ack():
		return
	if _is_ui_allowed():
		return
	
	if event is InputEventKey and event.pressed and not event.echo:
		if Input.is_action_just_pressed("ui_cancel") and current_ui:
			close_current_ui()
			get_viewport().set_input_as_handled()
			return

		for action in action_to_ui.keys():
			if Input.is_action_just_pressed(action):
				#open_ui(action_to_ui[action])
				#get_viewport().set_input_as_handled()
				#return
				toggle_ui(action_to_ui[action])
				get_viewport().set_input_as_handled()
				return


# 打开UI
func open_ui(ui_name: String):
	# 如果当前已经是这个UI，则不做处理
	if current_ui and ui_stack.size() > 0 and ui_stack[-1] == ui_name:
		#print_debug("UI已经打开: ", ui_name)
		return
	
	# 关闭当前UI
	if current_ui:
		_close_ui_instance(current_ui)
		current_ui = null
	
	# 通过SceneManager工厂方法创建新UI实例
	var ui_instance = SceneManager.create_ui(ui_name)
	
	if ui_instance:
		current_ui = ui_instance
		ui_stack.append(ui_name)
		#ui_container.add_child(ui_instance)
		get_tree().root.add_child(ui_instance)
		ui_opened.emit(ui_name)
		#print_debug("UI已打开: ", ui_name, " - 栈深度: ", ui_stack.size())
	else:
		push_error("创建UI失败: ", ui_name)
		GlobalMessage.emit_toast("界面暂时无法打开，请稍后再试", "error")


# 关闭当前UI
func close_current_ui():
	if not current_ui:
		push_warning("没有打开的UI")
		return
	
	var ui_name = ui_stack.pop_back() if ui_stack.size() > 0 else "Unknown"
	_close_ui_instance(current_ui)
	current_ui = null
	ui_closed.emit(ui_name)
	print_debug("UI已关闭: ", ui_name, " | 栈深度: ", ui_stack.size())

# 内部方法：销毁UI实例
func _close_ui_instance(ui_instance: Control):
	if ui_instance:
		ui_instance.queue_free()

# 切换UI（关闭当前，打开新的）
func toggle_ui(ui_name: String):
	if current_ui and ui_stack.size() > 0 and ui_stack[-1] == ui_name:
		# 如果当前就是这个UI，则关闭它
		close_current_ui()
	else:
		# 否则打开新UI
		open_ui(ui_name)


# 检查是否有UI打开
func has_ui_open() -> bool:
	return current_ui != null


# 获取当前UI名称
func get_current_ui_name() -> String:
	if ui_stack.size() > 0:
		return ui_stack[-1]
	return ""

# 获取当前UI实例
func get_current_ui() -> Control:
	return current_ui

# 关闭所有UI（清空栈）
func close_all_uis():
	while current_ui:
		close_current_ui()
	ui_stack.clear()
	print_debug("所有UI已关闭")

func _is_ui_allowed() -> bool:
	var root = get_tree().current_scene
	if root and root.is_in_group("UserLogin"):
		return true
	return false
