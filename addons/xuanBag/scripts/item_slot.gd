extends Control
class_name ItemSlot

signal item_clicked(slot: ItemSlot)
signal item_right_clicked(slot: ItemSlot)
signal item_drag_started(slot: ItemSlot)
signal item_dropped(from_slot: ItemSlot, to_slot: ItemSlot)

@onready var border: ColorRect = $Border
@onready var bg: ColorRect = $Bg
@onready var icon: TextureRect = $Icon
@onready var qty: Label = $Qty
@onready var item_tooltip_ctrl: Control = $item_tooltip_ctrl

var slot_index: int = -1
var item: InventoryItem
var is_dragging: bool = false
var is_selected: bool = false
var rotation_tween: Tween
var drag_preview: Control
var old_selected_id: String = ""
var current_selected_id: String = ""

# 全局唯一化
static var current_selected_slot: ItemSlot = null

func _ready():
	# 有时可能会自动连接失效，手动连接一下防止意外
	#gui_input.connect(_on_gui_input)
	#mouse_entered.connect(_on_mouse_entered)
	#mouse_exited.connect(_on_mouse_exited)
	
	# 设置默认样式
	bg.color = Color(0.2, 0.2, 0.2, 0.8)
	border.color = Color.WHITE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	
func _process(delta):
	# 如果正在拖拽 那么创建一个预览图
	if is_dragging and drag_preview:
		drag_preview.global_position = get_global_mouse_position() - Vector2(16, 16)
		
		# 结束拖拽
		if Input.is_action_just_released("ui_accept") or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_end_drag()
	
	# 如果选择了物品，则记录物品id
	if is_selected and item:
		current_selected_id = item.data.id
		#print(current_selected_id)
	
	if current_selected_id != old_selected_id and current_selected_slot != null:
		set_selected(false)
		old_selected_id = ""
		
# 拖拽处理
	if is_dragging and drag_preview:
		drag_preview.global_position = get_global_mouse_position() - Vector2(16, 16)
		
		if Input.is_action_just_released("ui_accept") or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_end_drag()
	
	# 选择状态处理
	if is_selected and item:
		current_selected_id = item.data.id
	
	if current_selected_id != old_selected_id and current_selected_slot != null:
		set_selected(false)
		old_selected_id = ""

func setup(index: int):
	slot_index = index

# 放置物品并且更新物品UI
func set_item(new_item: InventoryItem):
	item = new_item
	update_display()

# 更新物品UI
func update_display():
	if item and item.data:
		icon.texture = item.data.icon
		icon.visible = true
		
		if item.quantity > 1:
			qty.text = str(item.quantity)
			qty.visible = true
		else:
			qty.visible = false
		
		border.color = item.data.get_rarity_color()
		border.visible = true
	else:
		icon.texture = null
		icon.visible = false
		qty.visible = false
		border.visible = false

# 操作函数
func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		
		if mouse_event.pressed:
			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				if item:
					_handle_selection()
					old_selected_id = item.data.id
					#print(old_selected_id)
				item_clicked.emit(self)
				
				if item:
					_start_drag()
			elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
				item_right_clicked.emit(self)

# 选择处理
func _handle_selection():
	if not item:
		return
		
	# 如果已选中，则取消选中
	if current_selected_slot == self:
		set_selected(false)
		current_selected_slot = null
	else:
		# 取消选中前一个物品格
		if current_selected_slot:
			current_selected_slot.set_selected(false)
		
		# 选中当前
		set_selected(true)
		current_selected_slot = self
		old_selected_id = item.data.id
		
# 设置选中
func set_selected(selected: bool):
	if is_selected == selected:
		return
	
	is_selected = selected
	
	# 停止之前的动画
	if rotation_tween:
		rotation_tween.kill()
	
	
	if selected:
		# 选中时开始旋转
		start_rotation_animation()
	else:
		# 取消选中恢复原样
		stop_rotation_animation()

# 选中动画
func start_rotation_animation():
	if not icon:
		return
	
	# 创建循环旋转动画和过渡
	rotation_tween = create_tween()
	rotation_tween.set_ease(Tween.EASE_OUT)
	rotation_tween.set_trans(Tween.TRANS_BACK)
	rotation_tween.set_loops()
	
	# 360度旋转，持续1秒
	rotation_tween.tween_method(
		func(angle): icon.rotation = angle,
		0.0,
		TAU,  # TAU = 360度 也等于2π pi = 180度 = 1π
		1.0
	)

# 停止动画
func stop_rotation_animation():
	if not icon:
		return
	
	# 停止旋转动画
	if rotation_tween:
		rotation_tween.kill()
	
	# 平滑回到原始角度（步骤式创建属性
	rotation_tween = create_tween()
	rotation_tween.set_ease(Tween.EASE_OUT)
	rotation_tween.set_trans(Tween.TRANS_QUART)
	
	# 将图标恢复原始位置
	rotation_tween.tween_property(icon, "rotation", 0.0, 0.3)

# 开始拖拽
func _start_drag():
	if not item:
		return
	
	is_dragging = true
	item_drag_started.emit(self)
	
	# 创建拖拽预览
	drag_preview = Control.new()
	var preview_icon = TextureRect.new()
	preview_icon.texture = item.data.icon
	preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_icon.custom_minimum_size = Vector2(128, 128)
	drag_preview.add_child(preview_icon)
	get_tree().current_scene.add_child(drag_preview)

# 停止拖拽
func _end_drag():
	if not is_dragging:
		return
	
	is_dragging = false
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null
	
	# 检测拖拽目标
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = get_global_mouse_position()
	
	# 找到鼠标下的ItemSlot
	var target_slot = _find_slot_at_position(get_global_mouse_position())
	if target_slot and target_slot != self:
		item_dropped.emit(self, target_slot)
		set_selected(false) # **

# 找到物品格的位置
func _find_slot_at_position(pos: Vector2) -> ItemSlot:
	# 这里需要根据你的UI布局来实现
	# 简单实现：遍历所有ItemSlot找到匹配的
	var inventory_ui = get_tree().get_first_node_in_group("inventory_ui")
	if inventory_ui:
		for slot in inventory_ui.item_slots:
			if slot.get_global_rect().has_point(pos):
				return slot
	return null

# 鼠标进入检测
func _on_mouse_entered():
	if item and item.data:
		# 加载物品提示场景
		#var tooltip = get_tree().get_first_node_in_group("item_tooltip")
		#print(tooltip)
		var tooltip = preload("res://addons/xuanBag/scene/item_tooltip.tscn").instantiate()
		item_tooltip_ctrl.add_child(tooltip)
		if tooltip:
			tooltip.show_tooltip(item, global_position + Vector2(size.x + 200, 128))
			#print("正确的坐标", global_position + Vector2(size.x + 200, 128))
			#print("错误的坐标", global_position + Vector2(size.x, 0))

func _on_mouse_exited():
	for tooltip in item_tooltip_ctrl.get_children():
		tooltip.queue_free()
