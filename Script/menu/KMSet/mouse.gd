extends Control
## 教程用虚拟鼠标：根据 TutorialManager 当前步骤，高亮需要点击的鼠标操作。
## 支持 shoot / next_weapon / prev_weapon 三种交互。

const COLOR_ALLOWED := Color(0.221, 0.741, 0.973, 0.762)  # 待点击时高亮色
const COLOR_PRESSED := Color(0.203, 0.827, 0.6, 0.724)    # 点击后高亮色

@onready var mouse_tex: TextureRect = $Mouse
# 映射为 shoot
@onready var left_button: TextureRect = $LeftButton
# 映射为 Rightclick
@onready var right_button: TextureRect = $RightButton
# 映射为 prev_weapon
@onready var top_wheel: TextureRect = $TopWheel
# 映射为 next_weapon
@onready var bottom_wheel: TextureRect = $BottomWheel


var _pressed: Dictionary = {}


func _ready() -> void:
	# 默认只显示整体鼠标图标，四个子按钮隐藏
	left_button.visible = false
	right_button.visible = false
	top_wheel.visible = false
	bottom_wheel.visible = false
	_pressed.clear()
	if not Engine.is_editor_hint() and TutorialManager:
		TutorialManager.step_changed.connect(_on_tutorial_step_changed)


func _on_tutorial_step_changed(_new_step: TutorialManager.Step) -> void:
	# 切换到新的教学阶段时，重置所有高亮与按下状态
	_pressed.clear()
	left_button.visible = false
	right_button.visible = false
	top_wheel.visible = false
	bottom_wheel.visible = false
	left_button.modulate = Color(1, 1, 1, 1)
	right_button.modulate = Color(1, 1, 1, 1)
	top_wheel.modulate = Color(1, 1, 1, 1)
	bottom_wheel.modulate = Color(1, 1, 1, 1)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_mouse_highlight()


func _update_mouse_highlight() -> void:
	if not TutorialManager or not TutorialManager.is_in_tutorial():
		# 非教程：只显示整体鼠标，其余隐藏
		left_button.visible = false
		right_button.visible = false
		top_wheel.visible = false
		bottom_wheel.visible = false
		return
	
	# 关心的三个动作：左键射击 / 滚轮下一把武器 / 右键上一把武器
	# TODO: 加入开镜
	var actions := {
		&"shoot": left_button,
		&"next_weapon": bottom_wheel,
		&"prev_weapon": top_wheel,
		&"rightclick": right_button
	}
	
	for action: StringName in actions.keys():
		var node: TextureRect = actions[action]
		if node == null:
			continue
		# 仅在当前步骤需要高亮且允许的情况下显示
		var should_show := TutorialManager.is_action_highlighted_this_step(action) \
			and TutorialManager.is_action_allowed(action)
		node.visible = should_show
		if not should_show:
			continue
		
		# 首次点击后记为已按过
		if Input.is_action_just_pressed(action):
			_pressed[action] = true
		
		var is_pressed = _pressed.get(action, false)
		node.modulate = COLOR_PRESSED if is_pressed else COLOR_ALLOWED
