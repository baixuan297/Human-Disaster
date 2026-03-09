extends Node3D
## 双扇门：状态机 + 防抖（动画中锁定）+ 开关门音效；由 DoorL/DoorR 的 door_panel 转发 interact 调用。

enum State {
	CLOSED,
	OPENING,
	OPEN,
	CLOSING,
}

@export var open_distance: float = 1.5
@export var move_time: float = 0.5
## 开门后多少秒自动关门，≤0 表示不自动关
@export var auto_close_delay: float = 3.0

@onready var door_l: Node3D = $DoorL
@onready var door_r: Node3D = $DoorR
@onready var sound_open: AudioStreamPlayer3D = $SoundEffect/Door_Opening_Sound_Effect
@onready var sound_close: AudioStreamPlayer3D = $SoundEffect/Door_Closing_Sound_Effect

var _state: State = State.CLOSED
var _locked: bool = false
var _auto_close_timer: SceneTreeTimer = null


func _ready() -> void:
	_state = State.OPEN if _is_visually_open() else State.CLOSED


func interact(_player: Node = null) -> void:
	if _locked:
		return
	match _state:
		State.CLOSED:
			_start_open()
		State.OPEN:
			_start_close()
		State.OPENING, State.CLOSING:
			pass


func _is_visually_open() -> bool:
	if door_l == null or door_r == null:
		return false
	var tol := 0.01
	return abs(door_l.position.x - (-open_distance)) < tol and abs(door_r.position.x - open_distance) < tol


func _start_open() -> void:
	_locked = true
	_state = State.OPENING
	if sound_open != null and sound_open.stream != null:
		sound_open.play()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(door_l, "position:x", -open_distance, move_time)
	tween.tween_property(door_r, "position:x", open_distance, move_time)
	tween.finished.connect(_on_open_finished, CONNECT_ONE_SHOT)


func _on_open_finished() -> void:
	_state = State.OPEN
	_locked = false
	if auto_close_delay > 0.0:
		_start_auto_close_timer()


func _start_close() -> void:
	_stop_auto_close_timer()
	_locked = true
	_state = State.CLOSING
	if sound_close != null and sound_close.stream != null:
		sound_close.play()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(door_l, "position:x", 0.0, move_time)
	tween.tween_property(door_r, "position:x", 0.0, move_time)
	tween.finished.connect(_on_close_finished, CONNECT_ONE_SHOT)


func _on_close_finished() -> void:
	_state = State.CLOSED
	_locked = false


func _start_auto_close_timer() -> void:
	_stop_auto_close_timer()
	_auto_close_timer = get_tree().create_timer(auto_close_delay)
	_auto_close_timer.timeout.connect(_on_auto_close_timeout, CONNECT_ONE_SHOT)


func _stop_auto_close_timer() -> void:
	_auto_close_timer = null


func _on_auto_close_timeout() -> void:
	_auto_close_timer = null
	if _state == State.OPEN and not _locked:
		_start_close()
