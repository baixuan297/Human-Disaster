extends ReferenceRect
## 虚拟键盘单个按键：显示名称、尺寸，并在教程中按“本阶段高亮”规则变色。
## 仅当前阶段需要教的键会高亮；进入下一阶段后，前一阶段的键恢复默认色。

# ----------------------------------------
# 按键类型（与 key_line / JSON 的 type 对应）
# ----------------------------------------
enum KeyType {
	## 普通按键 (Q, E)
	NORMAL,
	## 特殊按键 (Tab, Ctrl)
	SPECIAL,
	## 特许按键较长(Shift, Enter)
	SPECIAL_LONG,
	## 长按键 (Space)
	LONG,
	## 自定义长度
	CUSTOM
}

# ----------------------------------------
# 教程高亮颜色（科技感配色）
# ----------------------------------------
## 默认色：非本阶段高亮的键、非教程时全部键
const DEFAULT_COLOR := Color(0.176, 0.224, 0.289, 0.746)       # #2d3a4a 深 slate
## 本阶段高亮且尚未按过：待按下
const COLOR_ALLOWED_NOT_PRESSED := Color(0.221, 0.741, 0.973, 0.762)  # #38bdf8 天空蓝
## 本阶段高亮且已按过：按过后在本阶段内一直保持此色
const COLOR_PRESSED := Color(0.203, 0.827, 0.6, 0.724)          # #34d399 翠绿

# ----------------------------------------
# 键盘显示名 -> Input action 映射（与 project 输入及 TutorialManager 步骤一致）
# ----------------------------------------
const KEY_NAME_TO_ACTION: Dictionary = {
	"W": &"move_forward",
	"A": &"move_left",
	"S": &"move_back",
	"D": &"move_right",
	"Space": &"jump",
	"Shift_L": &"Run",
	"Shift_R": &"Run",
	"Ctrl_L": &"crouch",
	"Ctrl_R": &"crouch",
	"R": &"reload",
	"F": &"interactable",
	"Q": &"Skill1",
	"E": &"Skill2",
	"X": &"Skill3",
	"0": &"change_hand",
	"1": &"change_weapon1",
	"2": &"change_weapon2",
}

# ----------------------------------------
# 导出变量
# ----------------------------------------
## 按键名称（由 key_line 从 JSON 绑定，如 "W"、"Space"）
@export var key_name: String = "Q"
## 按键类型，决定宽度
@export var key_type: KeyType = KeyType.NORMAL
## 自定义按键长度（CUSTOM 时使用）
@export var custom_width: float = 120.0

# ----------------------------------------
# 场景节点引用
# ----------------------------------------
@onready var label: Label = $Label
@onready var color_rect: ColorRect = $ColorRect

## 本阶段内是否已按过；按过后保持“已按”颜色，直到进入下一阶段后重置为默认
var _pressed_in_this_step: bool = false


func _ready() -> void:
	update_visual()
	if not Engine.is_editor_hint() and TutorialManager:
		TutorialManager.step_changed.connect(_on_tutorial_step_changed)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_tutorial_highlight()


## 步骤切换时：重置“已按”状态并先恢复默认色；下一帧按新阶段只高亮本阶段键
func _on_tutorial_step_changed(_new_step: TutorialManager.Step) -> void:
	_pressed_in_this_step = false
	if color_rect:
		color_rect.color = DEFAULT_COLOR


## 根据教程步骤更新 ColorRect 颜色：仅本阶段高亮的键参与高亮，前阶段键为默认
func _update_tutorial_highlight() -> void:
	if not is_instance_valid(color_rect):
		return
	# 非教程：全部默认
	if not TutorialManager or not TutorialManager.is_in_tutorial():
		color_rect.color = DEFAULT_COLOR
		return
	var action: StringName = _get_action_for_key_name(key_name)
	if action.is_empty():
		color_rect.color = DEFAULT_COLOR
		return
	# 仅当本步骤“需要高亮”的键才变色；前一阶段的键（如 WASD 在蹲跳阶段）保持默认
	if TutorialManager.is_action_highlighted_this_step(action):
		if Input.is_action_just_pressed(action):
			_pressed_in_this_step = true
		color_rect.color = COLOR_PRESSED if _pressed_in_this_step else COLOR_ALLOWED_NOT_PRESSED
	else:
		color_rect.color = DEFAULT_COLOR


## 根据键盘显示名取对应的 Input action，无映射则返回空
func _get_action_for_key_name(k: String) -> StringName:
	var key: String = k.strip_edges()
	if key.is_empty():
		return &""
	return KEY_NAME_TO_ACTION.get(key, &"")


## 更新 Label 文本与按键宽度
func update_visual():
	label.text = key_name

	match key_type:
		KeyType.NORMAL:
			custom_minimum_size.x = 80
		KeyType.SPECIAL:
			custom_minimum_size.x = 120
		KeyType.SPECIAL_LONG:
			custom_minimum_size.x = 160
		KeyType.LONG:
			custom_minimum_size.x = 500
		KeyType.CUSTOM:
			custom_minimum_size.x = custom_width
