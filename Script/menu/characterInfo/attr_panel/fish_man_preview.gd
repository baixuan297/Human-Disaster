extends Control

## 角色预览：支持鼠标拖拽旋转模型，以及 Idle 1/2 自动切换
## 使用 AnimationPlayer 即可，无需 AnimationTree（仅需在两个 idle 间轮流播放）

const ROTATION_SENSITIVITY: float = 0.005
const IDLE_SWITCH_INTERVAL: float = 4.0  # 无操作时每隔多少秒切换一次 idle

@onready var fish_man: Node3D = $SubViewport/FishMan
@onready var anim_player: AnimationPlayer = $SubViewport/FishMan/AnimationPlayer

var _rotation_y: float = 0.0
var _is_dragging: bool = false
var _last_mouse_pos: Vector2
var _idle_timer: float = 0.0
var _current_idle: int = 0  # 0 = Idle 1, 1 = Idle 2
var _idle_names: Array[StringName] = [&"Idle 1", &"Idle 2"]


func _ready() -> void:
	# 让 TextureRect 透传输入，以便本 Control 接收拖拽
	if has_node("TextureRect"):
		$TextureRect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_rotation_y = fish_man.rotation.y
	_play_idle(_current_idle)
	_idle_timer = IDLE_SWITCH_INTERVAL


func _input(event: InputEvent) -> void:
	# 在控制区域外释放鼠标时也能结束拖拽
	if _is_dragging and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_is_dragging = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging = mb.pressed
			if _is_dragging:
				_last_mouse_pos = mb.position
				_idle_timer = 0.0  # 拖拽时重置切换计时
	
	elif event is InputEventMouseMotion and _is_dragging:
		var mm := event as InputEventMouseMotion
		_rotation_y -= mm.relative.x * ROTATION_SENSITIVITY
		fish_man.rotation.y = _rotation_y
		_last_mouse_pos = mm.position
		_idle_timer = 0.0


func _process(delta: float) -> void:
	if _is_dragging:
		return
	_idle_timer += delta
	if _idle_timer >= IDLE_SWITCH_INTERVAL:
		_idle_timer = 0.0
		_current_idle = 1 - _current_idle
		_play_idle(_current_idle)


func _play_idle(index: int) -> void:
	if index < 0 or index >= _idle_names.size():
		return
	var _name := _idle_names[index]
	if anim_player.has_animation(_name):
		anim_player.play(_name)
